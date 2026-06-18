#!/usr/bin/env bash
# Home Assistant add-on wrapper for the perfSONAR testpoint container.
#
# This is the ONLY behavioural change vs. upstream perfsonar-testpoint-docker:
# it reads the two HA add-on options from /data/options.json, injects them into
# the upstream config files, then hands off to the unmodified supervisord setup.
#
#   psconfig_host   -> compose/psconfig/pscheduler-agent.json  "remotes" entry
#                      URL template: https://<host>/psconfig/psconfig.json
#   syslog_target   -> /etc/rsyslog.conf forwarding rule (host[:port], UDP,
#                      default port 514). Empty => no forwarding.
set -euo pipefail

OPTIONS_FILE="/data/options.json"
PSCONFIG_AGENT="/etc/perfsonar/psconfig/pscheduler-agent.json"
RSYSLOG_CONF="/etc/rsyslog.conf"

log() { echo "[perfsonar-testpoint] $*"; }

get_opt() {
  # $1 = jq path, $2 = default
  if [ -f "${OPTIONS_FILE}" ]; then
    local val
    val="$(jq -r "${1} // empty" "${OPTIONS_FILE}" 2>/dev/null || true)"
    [ -n "${val}" ] && echo "${val}" || echo "${2}"
  else
    echo "${2}"
  fi
}

PSCONFIG_HOST="$(get_opt '.psconfig_host' '')"
SYSLOG_TARGET="$(get_opt '.syslog_target' '')"

log "starting; psconfig_host='${PSCONFIG_HOST:-<unset>}' syslog_target='${SYSLOG_TARGET:-<unset>}'"

# --- psconfig remote -------------------------------------------------------
# Generate the pscheduler-agent.json remote from the host. If no host is
# provided, leave the upstream file as-is (empty remotes => agent idles).
if [ -n "${PSCONFIG_HOST}" ]; then
  PSCONFIG_URL="https://${PSCONFIG_HOST}/psconfig/psconfig.json"
  mkdir -p "$(dirname "${PSCONFIG_AGENT}")"
  jq -n --arg url "${PSCONFIG_URL}" \
    '{remotes: [{url: $url, "configure-archives": true}]}' \
    > "${PSCONFIG_AGENT}"
  log "psconfig remote set -> ${PSCONFIG_URL}"
else
  log "no psconfig_host set; leaving ${PSCONFIG_AGENT} unchanged"
fi

# --- syslog forwarding -----------------------------------------------------
# Append a single UDP forwarding rule when a target is configured. Accept
# host or host:port; default port 514. Idempotent (strip our previous block
# first) so restarts don't stack duplicate rules.
HA_MARK_BEGIN="# >>> HA add-on syslog forwarding >>>"
HA_MARK_END="# <<< HA add-on syslog forwarding <<<"

if [ -f "${RSYSLOG_CONF}" ]; then
  # Remove any previously injected block.
  sed -i "/${HA_MARK_BEGIN}/,/${HA_MARK_END}/d" "${RSYSLOG_CONF}" || true

  if [ -n "${SYSLOG_TARGET}" ]; then
    case "${SYSLOG_TARGET}" in
      *:*) SL_HOST="${SYSLOG_TARGET%:*}"; SL_PORT="${SYSLOG_TARGET##*:}" ;;
      *)   SL_HOST="${SYSLOG_TARGET}";    SL_PORT="514" ;;
    esac
    {
      echo "${HA_MARK_BEGIN}"
      echo "*.* @${SL_HOST}:${SL_PORT}"
      echo "${HA_MARK_END}"
    } >> "${RSYSLOG_CONF}"
    log "syslog forwarding -> ${SL_HOST}:${SL_PORT} (UDP)"
  else
    log "no syslog_target set; forwarding disabled"
  fi
fi

# --- hand off to upstream supervisord (unchanged) --------------------------
log "exec supervisord"
exec /usr/bin/supervisord -c /etc/supervisord.conf
