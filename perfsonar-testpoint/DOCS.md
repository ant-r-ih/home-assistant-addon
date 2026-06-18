# perfSONAR Testpoint — Documentation

This add-on packages the upstream
[perfsonar/perfsonar-testpoint-docker](https://github.com/perfsonar/perfsonar-testpoint-docker)
(supervisord variant) and adds a single wrapper script that injects two
Home Assistant options into the configuration before starting the perfSONAR
services.

## How it works

The Dockerfile is the upstream one (builds from `ubuntu:22.04`, installs
`perfsonar-testpoint` from the perfSONAR apt repo, runs everything under
`supervisord`). The only addition is `rootfs/run.sh`, set as the container
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
4. Execs `/usr/bin/supervisord -c /etc/supervisord.conf` — identical to
   upstream.

Because perfSONAR measurement traffic must reach the host directly, the add-on
runs with `host_network: true` and the `NET_ADMIN` / `NET_RAW` capabilities.

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

## Credits

Based on perfsonar/perfsonar-testpoint-docker (Apache-2.0). See the bundled
`LICENSE`.

Maintainer: Katsushi Kobayashi &lt;ikob@riken.org&gt;
