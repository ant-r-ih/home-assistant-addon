# Changelog

## 0.1.5
- Fix the SINDAN Wi-Fi exporter dropping all its metrics when a hidden SSID is in range: iw prints its bytes as `\xNN`, and the backslash was not escaped in the label, so node_exporter rejected the whole textfile (`node_textfile_scrape_error 1`).

## 0.1.4
- Run perfSONAR's own `node_exporter` (host metrics at `https://<host>/node_exporter/metrics`); upstream installs it but never starts it. The systemd collector options are dropped (no systemd/dbus in the container).
- Add the SINDAN Wi-Fi exporter (non-aggressive neighbour scan only), served through node_exporter's textfile collector. Options `wifi_exporter` (default off), `wifi_interface`, `wifi_interval`.

## 0.1.3
- Fix local syslog: use modern `module(load="imuxsock" SysSock.Name=...)` syntax (the `$SystemLogSocketName` directive is rejected by rsyslog 8.x). Verified working in-container.

## 0.1.2
- Fix crash loop: don't `rm /dev/log` (read-only on HA). Point rsyslog's input socket at the journal path instead, best-effort.

## 0.1.1
- Fix `/dev/log` so local/pscheduler logs reach rsyslog and the syslog forwarder.
- Docs: use RFC 5737 example IPs.

## 0.1.0
- Initial release: perfSONAR testpoint add-on with `psconfig_host` and optional `syslog_target` options.
