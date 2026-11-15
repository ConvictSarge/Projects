# Homelab and Automation Projects

Write-ups of systems I have designed, built and run. Everything here is redacted: no IP addresses, hostnames, account IDs, credentials, client names or personal data. The patterns and lessons are real.

| Project | What it shows |
|---|---|
| [Homelab architecture](homelab-architecture/README.md) | Network diagram: edge, VLANs, Proxmox cluster, DNS and reverse proxy, monitoring, backups, remote access |
| [Incident write-ups](incidents/README.md) | Postmortems: network dropouts, a silent backup failure, a VPN DNS leak, hypervisor swap pressure |
| [Monitoring as code](monitoring-as-code/README.md) | Prometheus, Proxmox, blackbox and SNMP exporters, Loki with Vector, provisioned Grafana; validated with promtool |
| [Sysadmin scripts](sysadmin-scripts/README.md) | Bash tools with real exit codes: backup age, certificate expiry, DNS leak check, Proxmox health |
| [Infrastructure as code for a Proxmox lab](infrastructure-as-code/README.md) | OpenTofu, Ansible, cloud-init, least-privilege API tokens, CI with secret scanning |
| [Monitoring and centralized logging](monitoring-and-logging/README.md) | rsyslog, Uptime Kuma, change-only alerting, watchdogs |
| [Small-business back office on n8n](small-business-automation/README.md) | Workflow design, PostgreSQL, payments sandbox, e-signature, test-first change control |
| [Email triage with local LLMs](email-triage-local-llm/README.md) | Self-hosted AI, failure handling, retry queues, human review |
| [Self-hosted voice and chat assistant](self-hosted-assistant/README.md) | Least-privilege tool design, secret masking, Home Assistant, CalDAV |

## Environment

- Two-node Proxmox VE cluster (VMs and LXC containers) with an Unraid NAS for storage and backups
- Docker for most services; Cloudflare Tunnels for anything public
- PostgreSQL with per-role access and row-level security
- n8n for automation; small Python services where n8n is the wrong tool
- Prometheus, Grafana, Loki and Uptime Kuma for monitoring; Discord and phone push for alerts

## How I work

- Test in a sandbox copy first, keep a rollback version, make the smallest change, verify on the live system.
- Write down what changed, why, and how to undo it.
- Alerts should be rare and mean something.
