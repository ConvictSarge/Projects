# Time-based VLAN and device access control on a router (Bash, iptables, conntrack)

A small Bash script that runs on the router itself and turns network access on and off for a whole VLAN, for individual devices, or for an allowlist of approved devices, without touching the router firewall's own rules.

## The problem

A restricted VLAN needed to be switched off and back on, with only approved devices allowed when it was open. A pair of devices on another VLAN needed the same on/off control. The router's firewall framework already manages its own chains, so these controls had to sit beside it without breaking it. The router is a Linux-based device.

## What it does

```text
usage: control.sh {block|unblock|status} {allowlist|device-a|device-b|tv|vlan|all}
```

(Target and status names are generalized in this write-up.)

- `block vlan` drops new TCP and UDP connections from the VLAN interface and deletes the existing connection-tracking entries for the subnet, so open sessions end immediately.
- `block allowlist` drops the whole VLAN but inserts ACCEPT rules for an approved list of device IPs above the drops ("allowlist mode").
- `block device-a|device-b|tv` blocks one device (or a pair of devices) without touching any other rule.
- `unblock <target>` removes only that target's rules.
- `status` prints one state: `UNBLOCKED`, `TOTAL_BLOCKED`, `ALLOWLIST_ONLY`, `ALLOWLIST+DEVICES`, `TV_BLOCKED`, `DEVICE_BLOCKED` or `PARTIAL_BLOCK`. Allowlist mode is checked before a plain global block, because both install the same VLAN-wide drops and only the ACCEPT exceptions tell them apart.

## Design decisions

1. **Respect the router's own firewall.** The router's firewall framework saves the outgoing-interface mark into the connection before later rules end the packet, and the script's own comments say its ACCEPT and DROP rules must not run before that step. For VLAN-wide and allowlist blocks, a helper (`ensure_save_mark_first`) removes any duplicate copies of that jump and reinstalls exactly one at position 1 of the FORWARD chain. The framework's own chain is never modified.
2. **Fixed insert positions.** The VLAN-wide drops and the allowlist ACCEPT rules are inserted at position 2, right behind that jump; the loop order is chosen so the ACCEPT rules end up above the drops. Per-device drops are inserted at position 1.
3. **Only new connections are dropped.** Rules match `conntrack --ctstate NEW`. Existing flows are cut separately with `conntrack -D`, scoped to the subnet or to the specific device IPs, so a block takes effect immediately instead of when sessions time out.
4. **Idempotent by construction.** Every removal helper loops `iptables -D` until it fails, so running a block twice cannot stack duplicate rules, and unblock leaves a clean chain.
5. **One writer at a time.** A `flock` on a lock file (10 second wait, then an error exit) prevents overlapping runs from interleaving rule changes.
6. **Independent controls.** Per-device blocks are deliberately not removed by a global or allowlist block, so they behave as separate manual overrides.

## Example (simplified, sanitized)

```bash
ensure_save_mark_first() {
    # remove duplicates, then reinstall exactly one copy at position 1
    while iptables -D FORWARD -m comment --comment "<router mark-saving jump>" \
          -j <router-mark-chain> 2>/dev/null; do :; done
    iptables -I FORWARD 1 -m comment --comment "<router mark-saving jump>" \
          -j <router-mark-chain>
}

block_vlan() {
    remove_global_rules
    ensure_save_mark_first || return 1
    iptables -I FORWARD 2 -i "$VLAN_IFACE" -p udp -m conntrack --ctstate NEW -j DROP
    iptables -I FORWARD 2 -i "$VLAN_IFACE" -p tcp -m conntrack --ctstate NEW -j DROP
}
```

## What I would improve

- IPv4 only: the script uses iptables, so IPv6 would need an ip6tables twin.
- Device and VLAN values are hard-coded variables; moving them into a small config file would make the script safer to share.
- It trusts whatever calls it to call unblock. A maximum-duration failsafe (auto-unblock after N hours) would stop a failed unblock from leaving a VLAN dark.
