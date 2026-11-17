# Homelab and Automation Projects

Write-ups of systems I have designed, built and run. Everything here is redacted: no IP addresses, hostnames, account IDs, credentials, client names or personal data. The patterns and lessons are real.

| Project | What it shows |
|---|---|
| [Homelab architecture](homelab-architecture/README.md) | Network diagram: edge, VLANs, Proxmox cluster, DNS and reverse proxy, monitoring, backups, remote access |
| [Incident write-ups](incidents/README.md) | Postmortems: a building's camera network restored over a borrowed fiber trunk (VLAN missing one hop upstream), network dropouts, a silent backup failure, a VPN DNS leak, hypervisor swap pressure, an n8n update that stalled the nightly workflow backup, a reverse-proxy host header that broke a phone login |
| [Windows Server and Active Directory lab](windows-ad-lab/README.md) | Unattended Windows Server 2025 install, DC promotion, OUs, GPOs, fine-grained password policy, onboarding/offboarding PowerShell tested on the live domain |
| [Automated backup restore test](restore-test/README.md) | Weekly restore of the newest backup into an isolated throwaway copy, boot and service check, then cleanup |
| [Proxmox tools packaged as n8n workflows](proxmox-tools/README.md) | Nightly restore drill with no-network copies and safety gates, a monthly PDF written by hand in JavaScript, least-privilege tokens, leak-checked packaging and buyer-style import testing |
| [Monitoring as code](monitoring-as-code/README.md) | Prometheus, Proxmox, blackbox and SNMP exporters, Loki with Vector, provisioned Grafana; validated with promtool |
| [Sysadmin scripts](sysadmin-scripts/README.md) | Bash tools with real exit codes: backup age, certificate expiry, DNS leak check, Proxmox health |
| [Infrastructure as code for a Proxmox lab](infrastructure-as-code/README.md) | OpenTofu, Ansible, cloud-init, least-privilege API tokens, CI with secret scanning |
| [Monitoring and centralized logging](monitoring-and-logging/README.md) | rsyslog, Uptime Kuma, change-only alerting, watchdogs |
| [Small-business back office on n8n](small-business-automation/README.md) | Workflow design, PostgreSQL, payments sandbox, e-signature, test-first change control |
| [Weekly email list on my own stack](weekly-email-list/README.md) | Double opt-in, logic in PostgreSQL functions behind a least-privilege role, claim-before-send so reruns never double-mail, bot-safe confirm and approve links |
| [Per-business website concept images](outreach-concept-builder/README.md) | Python, headless Chromium and a local LLM: parked-domain and bot-wall detection, grounded copy only, brand logo and colours, seeded design variety, watermarked renders for cold email |
| [Store sales webhook](store-sales-webhook/README.md) | n8n webhook with HMAC over the raw body, claim-before-work deduplication, API read-back, opt-in-only newsletter adds |
| [Rules-based market scanner with paper trading](market-signals/README.md) | Python service behind n8n, Discord bot, enforced API budget, size-only-shrinks risk rule, simulated trades with exposure caps; no advice, no real money |
| [Mission Control dashboard](mission-control/README.md) | A live business and automation dashboard served entirely by n8n webhooks: health by owner, approvals, money and usage gauges, 24-hour replay, test data kept out of live numbers |
| [Usage and budget watches](usage-watches/README.md) | Hourly and daily n8n checks on pay-as-you-go services: spend from balance drops, pace and runaway alerts, one alert per problem via INSERT ... ON CONFLICT |
| [Spoken morning recap](morning-voice-recap/README.md) | Local text-to-speech (Home Assistant + Piper) in two voices, overnight alerts from one log, one Discord DM with a text fallback |
| [Email triage with local LLMs](email-triage-local-llm/README.md) | Self-hosted AI, failure handling, retry queues, human review |
| [Self-hosted voice and chat assistant](self-hosted-assistant/README.md) | Least-privilege tool design, secret masking, Home Assistant, CalDAV |

## Environment

- Two-node Proxmox VE cluster (VMs and LXC containers) with an Unraid NAS for storage and backups
- Linux and Windows Server guests; a lab Active Directory domain
- Docker for most services; Cloudflare Tunnels for anything public
- PostgreSQL with per-role access and row-level security
- n8n for automation; small Python services where n8n is the wrong tool
- Prometheus, Grafana, Loki and Uptime Kuma for monitoring; Discord and phone push for alerts

## How I work

- Test in a sandbox copy first, keep a rollback version, make the smallest change, verify on the live system.
- Write down what changed, why, and how to undo it.
- Alerts should be rare and mean something.
