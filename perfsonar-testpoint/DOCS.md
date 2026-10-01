# perfSONAR Testpoint — Documentation

This add-on packages the upstream
[perfsonar/perfsonar-testpoint-docker](https://github.com/perfsonar/perfsonar-testpoint-docker)
(supervisord variant) and adds a wrapper script that injects the Home
Assistant options into the configuration before starting the perfSONAR
services. It also starts perfSONAR's host-metrics `node_exporter` and,
optionally, the SINDAN Wi-Fi exporter (see below).

## How it works

The Dockerfile is the upstream one (builds from `ubuntu:22.04`, installs
`perfsonar-testpoint` from the perfSONAR apt repo, runs everything under
`supervisord`). The main addition is `rootfs/run.sh`, set as the container
`CMD`. On start it:

1. Reads `/data/options.json` (the add-on options).
2. If `psconfig_host` is set, writes
   `/etc/perfsonar/psconfig/pscheduler-agent.json` with a single remote:
   ```json
   {"remotes": [{"url": "https://<psconfig_host>/psconfig/psconfig.json", "configure-archives": true}]}
   ```
3. If `syslog_target` is set, appends a UDP forwarding rule to
   `/etc/rsyslog.conf`. The rule is wrapped in markers and regenerated on each
   start, so restarts never stack duplicates.
4. Writes the `wifi_*` options to `/etc/default/sindan-exporter`.
5. Execs `/usr/bin/supervisord -c /etc/supervisord.conf`.

Because perfSONAR measurement traffic must reach the host directly, the add-on
runs with `host_network: true` and the `NET_ADMIN` / `NET_RAW` capabilities.

## Host metrics and the SINDAN Wi-Fi exporter

perfSONAR publishes host metrics through Apache, and the archive's psconfig
`hostmetrics` agent pulls them from each address:

- `https://<host>/node_exporter/metrics` — `node_exporter` on
  `localhost:9100`, with perfSONAR's options from `/etc/default/node_exporter`
- `https://<host>/perfsonar_host_exporter/` — pScheduler / psconfig metrics

Upstream installs `node_exporter` but never starts it (it relies on systemd).
This add-on runs it under supervisord (`rootfs/node-exporter.sh`) with the same
options, except that the systemd collector options are dropped (there is no
systemd/dbus in the container), and with node_exporter's textfile collector
reading `/var/lib/prometheus/node-exporter`.

With `wifi_exporter: true`, the supervisord program `sindan-exporter` runs
SINDAN's `sindan_exporter.sh` (from
[sindan-client](https://github.com/ikob/sindan-client), pinned by the
`SINDAN_REF` build argument) every `wifi_interval` seconds. It writes
`sindan_wifi.prom` into the textfile directory, so the `sindan_wifi_*` metrics
come out of the same `/node_exporter/metrics` endpoint as the host metrics; the
archive needs no extra target. Only SINDAN's non-aggressive measurement is
included: it reads the kernel's BSS cache (`iw dev <if> scan dump`) and
triggers a real scan only if the cache is empty, so the interval also caps
how often a real scan is triggered.

| Metric | Description |
| --- | --- |
| `sindan_wifi_neighbor_rssi_dbm{ifname,bssid,ssid,mode,band,channel,bandwidth,security}` | RSSI of each neighbour AP |
| `sindan_wifi_neighbors{ifname}` | number of neighbour APs |
| `sindan_wifi_scan_success{ifname}` | 1 if the latest collection returned APs |
| `sindan_wifi_scan_triggered{ifname}` | 1 if a real scan had to be triggered |
| `sindan_wifi_scan_timestamp_seconds{ifname}` | time of the last successful collection |

Note that the neighbour SSIDs/BSSIDs become visible to whoever can read
`/node_exporter/metrics`.

## Options

### `psconfig_host`

Host part (FQDN or IP) of the psconfig remote. The add-on builds the URL as
`https://<psconfig_host>/psconfig/psconfig.json`. Example: `192.0.2.1`.

If left blank, the upstream `pscheduler-agent.json` is left untouched (empty
`remotes`), so the agent runs but pulls no remote configuration.

### `syslog_target`

Optional rsyslog forwarding target. Accepts:

- `host` → forwards to `host` on UDP **514** (default)
- `host:port` → forwards to the given port on UDP

Example: `loghost.example.org` or `192.0.2.10:5514`. Forwarding uses UDP
(`*.* @host:port`). Leave blank to disable.

### `wifi_exporter`

Run the SINDAN Wi-Fi exporter (default `false`).

### `wifi_interface`

Wi-Fi interface to scan (default `wlan0`). It does not need to be associated.

### `wifi_interval`

Seconds between collections (default `600`, minimum `60`).

## Ports

With `host_network: true` the container uses the host's ports directly. The
key perfSONAR ports (see upstream for the full range) are:

| Port | Protocol | Purpose |
| --- | --- | --- |
| 443 | TCP | pScheduler / web (HTTPS) |
| 861 | TCP | OWAMP control |
| 862 | TCP | TWAMP control |
| 5201 | TCP | iperf3 throughput |
| 8760–9960 | TCP/UDP | OWAMP test ports |
| 18760–19960 | TCP/UDP | TWAMP test ports |

Ensure the host firewall allows these from the nodes that will test against
this host.

## Architecture note (aarch64)

The image installs perfSONAR from the apt repository at build time rather than
pulling a prebuilt `perfsonar/testpoint` image, so it can build natively for
arm64. If the build fails fetching packages, confirm the perfSONAR apt
repository serves arm64 for the Ubuntu release used in the Dockerfile.

## Testing

From another perfSONAR host:

```bash
owping <this-host>
pscheduler task throughput --dest <this-host>
```

## Troubleshooting

- **psconfig not applying** — Check the add-on log for the
  `psconfig remote set -> ...` line and verify the URL is reachable
  (`https://<psconfig_host>/psconfig/psconfig.json`).
- **No logs at the remote collector** — Confirm `syslog_target` is set, the
  collector listens on UDP, and the host firewall permits the traffic.
- **Build fails on ARM** — See the Architecture note above.
- **`node_exporter` keeps restarting with `address already in use`** —
  something else on the host already listens on port 9100, for example the
  SINDAN-client add-on's own exporter. Turn that off (`exporter: false` in
  SINDAN-client); with this add-on the Wi-Fi metrics come from here.
- **`sindan_wifi_scan_success` is 0** — check `wifi_interface` and that the
  interface is up (`iw dev`).

## Credits

Based on perfsonar/perfsonar-testpoint-docker (Apache-2.0). See the bundled
`LICENSE`.

Maintainer: Katsushi Kobayashi &lt;ikob@riken.org&gt;
