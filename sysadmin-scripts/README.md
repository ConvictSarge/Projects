# Sysadmin scripts

Small Bash tools I use on my Proxmox lab. Each one came out of a real problem (see the [incident write-ups](../incidents/README.md)), does one job, prints a readable table, and returns a meaningful exit code. That makes them easy to run by hand, from cron, or from a monitoring check.

| Script | What it checks | Came from |
|---|---|---|
| [`check-backup-age.sh`](check-backup-age.sh) | Every guest has a recent, non-empty vzdump archive. Catches a stale or unmounted backup share. | [Nightly backups stopped silently](../incidents/2026-11-silent-backup-failure.md) |
| [`cert-expiry.sh`](cert-expiry.sh) | TLS certificate expiry for a list of hosts, with SNI | Wildcard certificates on a LAN reverse proxy |
| [`dns-leak-check.sh`](dns-leak-check.sh) | A VPN-only host or user cannot resolve through the LAN, and egresses through the VPN | [DNS leak on a VPN-only container](../incidents/2026-11-vpn-container-dns-leak.md) |
| [`pve-health.sh`](pve-health.sh) | Memory, swap, load per CPU, root disk, quorum, and the largest VMs with their balloon settings | [Hypervisor at 98% swap](../incidents/2026-11-hypervisor-swap-pressure.md) |

## Conventions

- `set -euo pipefail` where the script should stop on the first error; scripts that report several checks keep going and summarize instead.
- Exit code `0` means healthy, `1` means something needs attention, `2` means a usage or environment error. A cron job or monitor can alert on non-zero.
- `-h` prints the usage block from the top of each script.
- No secrets, no hard-coded hosts. Everything is passed as options.

## Examples

These are from test runs.

```text
$ ./check-backup-age.sh -d /mnt/pve/backups/dump -a 26 -i "101 110 999"
GUEST    STATUS   AGE(h)     NEWEST ARCHIVE
101      OK       1          vzdump-lxc-101-2026_11_14-20_45_20.tar.zst (2 MB)
110      STALE    50         vzdump-qemu-110-2026_11_12-19_45_20.vma.zst (2 MB)
999      MISSING  -          -
$ echo $?
1
```

```text
$ ./cert-expiry.sh -w 30 github.com example.com nonexistent.invalid
HOST                                     STATUS    DAYS   EXPIRES (UTC)
github.com                               OK        73     2027-01-27 23:59
example.com                              OK        40     2026-12-25 22:56
nonexistent.invalid                      NO-CERT   -      unreachable or no TLS
```

```text
$ ./pve-health.sh
OK     memory used            56% of 10 GiB (limit 90%)
WARN   swap used              64% of 3 GiB (limit 50%)
OK     load (1 min) per CPU   0.48 on 6 CPUs (limit 1.5)
OK     root filesystem        23% used (limit 85%)
SKIP   cluster quorum         not a Proxmox node
```

```text
# Run as the user that must stay inside the VPN:
$ sudo -u appuser ./dns-leak-check.sh -a "10.64.0.1" -l 192.168.1.53 -v 203.0.113.
PASS  resolv.conf uses allowed resolver 10.64.0.1
PASS  no search/domain suffix in resolv.conf
PASS  LAN resolver 192.168.1.53 is not reachable from here
PASS  egress IP is 203.0.113.25 (matches VPN prefix)
```

The last example uses placeholder addresses. On a machine that is not behind a VPN, the same script reports `FAIL` for the resolver and the LAN check, which is the point.

## Running from cron

```cron
# 07:00 daily: complain if any guest has no backup from the last 26 hours
0 7 * * * root /usr/local/bin/check-backup-age.sh -a 26 >/var/log/backup-age.log 2>&1 || logger -t backup-age "stale or missing backups, see /var/log/backup-age.log"
```
