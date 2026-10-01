#!/usr/bin/env bash
# SINDAN Wi-Fi exporter (supervisord program "sindan-exporter"). Runs SINDAN's
# sindan_exporter.sh -- the non-aggressive Wi-Fi neighbour scan only -- every
# WIFI_INTERVAL seconds. It writes sindan_wifi.prom into node_exporter's
# textfile directory, so the metrics are served with the host metrics on
# https://<host>/node_exporter/metrics. Settings come from
# /etc/default/sindan-exporter, written by run.sh from the add-on options.
TEXTFILE_DIR=/var/lib/prometheus/node-exporter
. /etc/default/sindan-exporter

if [ "${WIFI_EXPORTER:-false}" != "true" ]; then
  echo "[sindan-exporter] disabled (wifi_exporter: false)"
  rm -f "${TEXTFILE_DIR}/sindan_wifi.prom"
  exit 0
fi

export WLAN_IF TEXTFILE_DIR
echo "[sindan-exporter] interface ${WLAN_IF}, every ${WIFI_INTERVAL}s -> ${TEXTFILE_DIR}"
# The interval is also the upper bound on how often a real scan is triggered.
while true
do
  /opt/sindan/sindan_exporter.sh
  sleep "${WIFI_INTERVAL}"
done
