# Changelog

## 0.1.2
- Fix crash loop: don't `rm /dev/log` (read-only on HA). Point rsyslog's input socket at the journal path instead, best-effort.

## 0.1.1
- Fix `/dev/log` so local/pscheduler logs reach rsyslog and the syslog forwarder.
- Docs: use RFC 5737 example IPs.

## 0.1.0
- Initial release: perfSONAR testpoint add-on with `psconfig_host` and optional `syslog_target` options.
