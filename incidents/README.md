# Incident write-ups

Short postmortems from the homelab and small-business systems I run. Each one follows the same blameless format: what happened, impact, how it was found, root cause, fix, and what changed so it does not happen again.

Everything is redacted: no IP addresses, hostnames, account IDs or credentials. The timelines, causes and fixes are real.

| Incident | Area | Lesson |
|---|---|---|
| [Network dropouts: a NIC hang and a leaking switch](2026-11-network-dropouts.md) | Networking, hardware, monitoring | One symptom had two unrelated causes; a second vantage point found both |
| [Nightly backups stopped silently after a reboot](2026-11-silent-backup-failure.md) | Backups, storage, alerting | A backup job with no failure alert is a guess |
| [DNS leak on a VPN-only container](2026-11-vpn-container-dns-leak.md) | VPN, DNS, firewalling | A working tunnel and kill switch do not cover DNS |
| [Hypervisor at 98% swap with almost no load](2026-11-hypervisor-swap-pressure.md) | Virtualization, memory | Guest page cache looks like used memory to the host |

## Format

Every write-up has the same sections, so they can be skimmed:

- **Summary**: two or three sentences
- **Impact**: what was affected and for how long
- **Timeline**: times in Eastern
- **Detection**: how it was noticed
- **Root cause**
- **Fix**
- **Prevention**: what changed afterwards
- **Lessons**
