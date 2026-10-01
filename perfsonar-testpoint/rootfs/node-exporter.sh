#!/usr/bin/env bash
# node_exporter for the perfSONAR host metrics (supervisord program
# "node_exporter"). perfsonar-host-metrics installs node_exporter and its
# options in /etc/default/node_exporter (localhost:9100, proxied by Apache as
# https://<host>/node_exporter/metrics) but leaves starting it to systemd, so
# upstream perfsonar-testpoint-docker never runs it. Same options, plus:
#   - the --collector.systemd* options are dropped: there is no systemd/dbus
#     here, so the collector would fail on every scrape
#   - --collector.textfile.directory for add-on metrics (SINDAN Wi-Fi exporter)
# Started as root because /etc/default/node_exporter is mode 0600 (as with
# systemd's EnvironmentFile); node_exporter itself runs as prometheus.
. /etc/default/node_exporter
# Word-split NODE_EXPORTER_OPTS like systemd does, without globbing its regex.
set -f
opts=()
for o in ${NODE_EXPORTER_OPTS}; do
  case "${o}" in
    --collector.systemd*) ;;
    *) opts+=("${o}") ;;
  esac
done
exec setpriv --reuid=prometheus --regid=prometheus --init-groups \
  /usr/bin/node_exporter "${opts[@]}" \
  --collector.textfile.directory=/var/lib/prometheus/node-exporter
