# Automated backup restore test

A backup you have never restored is only a guess. This script proves an LXC container's newest backup really restores and boots, then throws the copy away. It runs weekly from cron on a Proxmox VE node.

It came out of [the silent backup failure](../incidents/2026-11-silent-backup-failure.md): the backup jobs had stopped and nothing alerted. This checks the result end to end: is there a recent archive, does it extract, does the container boot, and is the service running.

## What one run does

1. Finds the newest vzdump archive of the container on the backup storage and fails if it is older than 30 hours.
2. Restores it to a temporary ID (9000 + the container ID) with unique MAC addresses.
3. **Isolates the copy before its first boot.** It deletes every network interface (including VLAN-tagged ones), every bind mount and every raw mount entry, turns off autostart, and adds a single untagged interface with an unused static IP and **no gateway**. If any of that is still present, it refuses to start the copy.
4. Starts the copy, waits for systemd, and runs a health check inside it (for example, "is the service active?").
5. Destroys the copy, but only if its hostname is the `restoretest-<id>` name this run gave it.
6. Logs every step to stdout and to syslog (`journalctl -t pve-restore-test`). Exit code `0` means pass, `1` means fail.

## Safety rails

- It refuses to run if the temporary ID already exists, if the ID is below 9000, or if the test IP already answers a ping.
- The cleanup trap destroys only what this run created.
- The isolation step exists because a real container in my lab has a second interface on a separate VLAN. A plain restore and start would have put a duplicate device on that network.

## A real run

Address replaced with a placeholder.

```text
# pve-restore-test -c 105 -s backup-share -i 192.168.1.250/24 -k "systemctl is-active --quiet ntfy"
2026-11-14 22:00:01  newest archive: backup-share:backup/vzdump-lxc-105-2026_11_14-12_59_31.tar.zst (9h old)
2026-11-14 22:00:06  restored to 9105 in 5s
2026-11-14 22:00:10  isolated: removed [net0,net1], one untagged NIC at 192.168.1.250/24, no gateway
2026-11-14 22:00:15  booted: systemd state 'degraded'
2026-11-14 22:00:16  health check passed: systemctl is-active --quiet ntfy
2026-11-14 22:00:20  destroyed temporary copy 9105
2026-11-14 22:00:20  RESULT: PASS (container 105, archive vzdump-lxc-105-2026_11_14-12_59_31.tar.zst)
```

The failure path was tested the same way, with a health check for a service that does not exist. The run reported `FAIL`, exited 1, logged the failure to syslog, and still destroyed the copy.

("Degraded" is expected here: with no gateway, units that need the internet fail. The check that matters is the service.)

## Schedule

```cron
# /etc/cron.d/pve-restore-test - Sundays 05:15, after the nightly 03:30 backups
15 5 * * 0 root /usr/local/sbin/pve-restore-test -c 105 -s backup-share -i 192.168.1.250/24 -k "systemctl is-active --quiet ntfy" >>/var/log/pve-restore-test.log 2>&1
```

## Next

- Rotate through more containers instead of always testing the same one.
- Add a dead-man's switch: on success, ping an Uptime Kuma push monitor, so both a failed test and a test that never ran raise an alert.
