# Monitoring as code

The Docker Compose stack I run for metrics, probes and logs on my Proxmox lab, published with addresses replaced by placeholders (`node-a.lab`, `switch.lab` and so on). Every file here is the real configuration, apart from those names and the list of probe targets.

| Component | Job |
|---|---|
| Prometheus 3.5 | Scrapes everything every 30 s and keeps 60 days |
| prometheus-pve-exporter | Proxmox nodes, VMs, containers and storage through a **read-only API token** |
| node_exporter (on the hosts) | CPU, memory and disk on both Proxmox nodes and the NAS |
| Blackbox exporter | Is each service answering? Strict `http_2xx`, lenient `http_any` (a login page or a 401 still counts as up), and plain `tcp` |
| SNMP exporter | Managed PoE switch: uptime (a drop to 0 means it rebooted) and PoE draw against its budget |
| Vector into Loki | Receives the switch's raw syslog over UDP and keeps 60 days |
| Grafana 12 | Dashboards and data sources provisioned from files, so a rebuild gets the same Grafana |

## Layout

```text
docker-compose.yml          # all services, pinned image versions, LAN-only port bindings
.env.example                # copy to .env; secrets never committed
prometheus/prometheus.yml   # scrape jobs
blackbox/blackbox.yml       # probe modules
snmp/snmp.yml               # hand-written snmp_exporter module for standard MIBs only
loki/config.yml             # single-binary Loki, filesystem storage, 60-day retention
vector/vector.yaml          # UDP syslog in, Loki out
grafana/provisioning/       # data sources + dashboard provider
grafana/dashboards/         # switch-health.json (custom)
```

The dashboards folder on the server also holds three community dashboards downloaded from grafana.com: 1860 (Node Exporter Full), 10347 (Proxmox via Prometheus) and 7587 (Blackbox Exporter). They are not copied here; download them by those IDs.

## Design choices

- **Bind to one LAN address.** Published ports use `${BIND_ADDR}`, never `0.0.0.0`, so nothing listens on interfaces it shouldn't.
- **Pinned versions.** Every image except the PVE exporter is pinned, and upgrades are a deliberate tag bump.
- **Least privilege.** The Proxmox exporter uses an API token with the auditor role, not a user password.
- **Two probe strictness levels.** Admin UIs that redirect to a login page are "up" for `http_any`. Health endpoints must return 2xx.
- **Raw syslog, not parsed.** This switch puts the wrong year in its timestamps. Vector keeps the raw line and Loki uses the receive time. Grafana Alloy was tried first and silently dropped these lines.
- **A second vantage point.** This stack runs on one node, so it is blind when that node is down. Uptime Kuma on the other node pings the router and the internet every 30 seconds and pushes alerts to my phone. See the [network dropouts write-up](../incidents/2026-11-network-dropouts.md) for why that mattered.

## Switch health dashboard

`grafana/dashboards/switch-health.json` was built during the network dropout investigation. It shows:

- PoE watts used against the budget, plus a gauge of the current load
- switch uptime in hours, where a sudden drop to 0 is a reboot
- a count of reboots in the selected time range (`resets(switch_uptime_ticks[$__range])`)
- the switch's syslog from Loki, with noisy client-roaming messages filtered out

## Validation

`docker compose config --quiet` and `promtool check config` both pass on these files.

## Run it

```bash
cp .env.example .env    # set BIND_ADDR, the Grafana admin password and the Proxmox token
docker compose up -d
# Point the switch's remote syslog at BIND_ADDR:514 and enable SNMP v3 read access.
```
