# perfSONAR Testpoint

Run a [perfSONAR](https://www.perfsonar.net/) 5.x testpoint as a Home Assistant
add-on. This add-on is based on the upstream
[perfsonar/perfsonar-testpoint-docker](https://github.com/perfsonar/perfsonar-testpoint-docker)
build, with a thin wrapper that takes two settings from the add-on
configuration:

- the **psconfig remote host** (used to build the psconfig URL), and
- an optional **syslog forwarding target**.

It also starts perfSONAR's host-metrics `node_exporter` (installed but not
started upstream) and can run the SINDAN Wi-Fi exporter, whose metrics are
served with the host metrics at `https://<host>/node_exporter/metrics`.

Everything else (pScheduler, OWAMP, TWAMP, iperf3, the supervisord service
layout) is unchanged from upstream.

Maintained by the Advanced Networking Technology unit, RIKEN.

## Architecture

Targets **aarch64** (ARM64). The image is built from `ubuntu:22.04` and installs
perfSONAR from the official apt repository, so it builds natively per
architecture — provided the perfSONAR apt repo serves arm64 packages for the
selected release.

## Installation

1. Add this repository to Home Assistant (**Settings → Add-ons → Add-on store →
   ⋮ → Repositories**): `https://github.com/ant-r-ih/home-assistant-addon`
2. Install **perfSONAR Testpoint**.
3. Set the options below, then start the add-on.

## Configuration

```yaml
psconfig_host: "192.0.2.1"
syslog_target: "loghost.example.org:514"
wifi_exporter: false
wifi_interface: wlan0
wifi_interval: 600
```

| Option | Required | Description |
| --- | --- | --- |
| `psconfig_host` | recommended | Host part of the psconfig remote. The add-on registers `https://<psconfig_host>/psconfig/psconfig.json`. Leave blank to start with no remote. |
| `syslog_target` | optional | rsyslog forwarding target, `host` or `host:port` (UDP, default port 514). Leave blank to disable forwarding. |
| `wifi_exporter` | optional | Run the SINDAN Wi-Fi neighbour exporter (default `false`). |
| `wifi_interface` | optional | Wi-Fi interface to scan (default `wlan0`). |
| `wifi_interval` | optional | Seconds between collections (default `600`, minimum `60`). |

See [DOCS.md](DOCS.md) for details and troubleshooting.
