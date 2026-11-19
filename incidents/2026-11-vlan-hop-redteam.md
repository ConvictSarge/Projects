# A side project's hosting container could reach every other network, bypassing both the firewall and the switch

Homelab/small-business incident, November 2026. I run a self-hosted red team exercise against my own infrastructure every so often, to answer one question: if a public-facing workload on my hypervisor got compromised, what could it actually reach? Redacted: no IP addresses, hostnames, VLAN numbers, device counts or product/model names.

## Summary

A single unprivileged container, placed exactly where a public-facing website's container normally runs, could tag itself onto any other VLAN on the network using nothing but a standard Linux command available to any unprivileged container by default, and get a live, ARP-confirmed conversation with that VLAN's gateway. This fully bypassed both the firewall's inter-VLAN block rule and the switch's intended port-level VLAN membership, because the traffic never needed to look like inter-VLAN traffic to either device: it rode the hypervisor's own existing trunk link to the switch. A second, independent gap in the firewall's own routing rules meant that even without the first issue, the same outcome was reachable a different way. Found and closed the same night, then retested clean.

## Impact

No real breach occurred; this was a planned, scoped test with a written rule of engagement (one network segment was explicitly off-limits for the whole exercise, destructive actions were disallowed, and every active test was approved before it ran). Two lower-severity side incidents happened *during* remediation, both self-inflicted by in-progress configuration changes, both caught and reverted within minutes: a brief loss of hypervisor-cluster quorum after enabling a switch security feature, and a short admin-UI lockout on the firewall appliance after disabling a legacy access method mid-session (the appliance's own session had been riding the exact protocol being disabled).

## Detection

Passive, read-only review first: a hosting container and the hypervisor's management interfaces, the NAS and a personal password manager all sat on the same flat subnet, with no firewall rules separating them. That alone didn't prove anything could actually reach those targets, so the next phase tested it directly, from a disposable container placed on the same hypervisor host and virtual switch as the real public-facing workload, with a written scope and a line that one specific network segment could never be touched or tested against.

## Timeline (same session, in order)

1. Read-only pass across the firewall, the managed switch, and the hypervisor's own bridge configuration, with no changes made.
2. Found that the firewall's main inter-VLAN routing rule allowed far more than it needed to, and that the hypervisor's VLAN-aware bridge accepted tags for every VLAN on an untagged guest's own virtual port, by default, on every guest.
3. With approval, confirmed the theory from a disposable, unprivileged test container: tagging a single sub-interface for a VLAN that carried no personal or sensitive traffic got a real reply from that VLAN's gateway. Interface removed immediately after.
4. Traced the actual control point: not the hypervisor's bridge setting (removing it changed nothing), but a single physical switch port carrying more VLANs than it needed to, because it served a device whose guests needed none of them.
5. Fixed the switch port one VLAN at a time, re-testing cluster health and real device connectivity after each change, approved step by step rather than all at once.
6. Retested the exact same technique against the fixed VLANs: no reply, connection state stayed incomplete.
7. Separately narrowed the firewall's own inter-VLAN routing rule to two explicitly named exceptions, verified against real devices (not the router's own address, which answers pings through a separate always-on rule and will give a false "still open" result).
8. Closed the router's and switch's own admin interfaces down to the two VLANs that actually needed them, with the admin protocols not in use disabled outright.

## Root cause

Two independent causes, either one enough on its own:

- A hypervisor bridge set to accept 802.1Q tags for every VLAN on a guest's network port by default, combined with a physical switch port that was still a tagged member of VLANs none of its guests used. Tagging is usually thought of as something you opt a guest *into*; here, nothing stopped a guest from opting *itself* into a VLAN it was never assigned.
- A firewall rule written for convenience ("let the trusted side of the network reach everything") rather than for the smallest set of hosts that actually needed it.

Both had been true for a while without being noticed, because nothing had ever tried to use them.

## Fix

- Removed the unused VLAN tags from the one physical switch port that didn't need them, one VLAN at a time, with a health check and a real-device connectivity check after every single change.
- Narrowed the firewall's broad inter-VLAN rule to two named exception hosts, confirmed the previously-open VLANs are now unreachable from a real test device, and confirmed the traffic that still needs to flow (one monitoring path) still does.
- Disabled unused admin protocols on both the firewall and the switch outright; narrowed the ones still needed (web admin, SSH) to the two VLANs that actually use them.
- Logged, rather than guessed at, two multi-homed personal devices that had direct legs into networks they didn't need them for; left them logged-only pending a few days of real traffic data before writing a tighter rule, since blocking blind risked breaking real automation.

## Prevention

- The written rule of engagement, approval-before-each-active-test discipline, and verify-after-every-change habit (quorum, live monitoring counts, a real device ping) are what kept two self-inflicted side incidents from becoming worse than a few minutes of disruption.
- A retest script for the exact exploit technique now exists, so a future change to the hypervisor's bridge config or the switch's VLAN table can be checked the same way, not just inspected.
- The deeper fix, actually separating the hosting workload onto its own VLAN instead of a flat shared subnet, is in progress as its own piece of work, not a same-night patch.

## Lessons

- A hypervisor's own default bridge behavior can be a bigger attack surface than anything in the firewall, and it won't show up in a firewall audit at all.
- "The firewall blocks it" and "a device physically cannot reach it" are different claims. Test the second one directly; don't infer it from the first.
- A positive test result and a false positive can look identical if you test against the wrong thing (a router or gateway's own address often answers through a separate, more permissive rule than the one you're actually testing). Always retest against a real endpoint.
- Writing the scope, the stop conditions, and the approval checkpoints down before starting is what turned two live incidents into non-events instead of outages.
