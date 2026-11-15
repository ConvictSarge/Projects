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
- The isolation step is a backstop, not a licence. One container in my lab has a second interface on a protected VLAN. The isolation step would strip that interface before boot, but the weekly job still doesn't use that container: guests attached to protected networks are kept out of the rotation entirely.

## Real runs

Addresses replaced with placeholders.

```text
# Weekly target: the DNS container (single untagged interface, no mounts)
# pve-restore-test -c 107 -s backup-share -i 192.168.1.250/24 -a 72 -k "systemctl is-active --quiet pihole-FTL"
2026-11-14 22:33:03  newest archive: backup-share:backup/vzdump-lxc-107-2026_11_12-03_44_44.tar.zst (66h old)
2026-11-14 22:33:14  restored to 9107 in 11s
2026-11-14 22:33:18  isolated: removed [net0], one untagged NIC at 192.168.1.250/24, no gateway
2026-11-14 22:33:24  booted: systemd state 'running'
2026-11-14 22:33:25  health check passed: systemctl is-active --quiet pihole-FTL
2026-11-14 22:33:30  destroyed temporary copy 9107
2026-11-14 22:33:30  RESULT: PASS (container 107, archive vzdump-lxc-107-2026_11_12-03_44_44.tar.zst)
```

The live DNS server kept answering throughout. The copy had a different address and no route out. (`-a 72` was used for this run because the nightly backups had been down for two nights. See the incident write-up.)

An earlier run on a container with a second, VLAN-tagged interface showed `isolated: removed [net0,net1]`, so the copy never touched that network. That container is still kept out of the weekly schedule.

The failure path was tested with a health check for a service that does not exist. The run reported `FAIL`, exited 1, logged to syslog, and still destroyed the copy.

## Schedule

```cron
# /etc/cron.d/pve-restore-test - Sundays 05:15, after the nightly 03:30 backups
15 5 * * 0 root /usr/local/sbin/pve-restore-test -c 107 -s backup-share -i 192.168.1.250/24 -k "systemctl is-active --quiet pihole-FTL" >>/var/log/pve-restore-test.log 2>&1
```

## Next

- Rotate through every eligible container (single untagged interface, no mounts or passthrough), oldest-tested first.
- Add a dead-man's switch: on success, ping an Uptime Kuma push monitor, so both a failed test and a test that never ran raise an alert.
