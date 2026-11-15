# DNS leak on a VPN-only container

**Status:** resolved.

## Summary

A container that is only allowed to use the internet through a WireGuard VPN was still sending its DNS lookups to the local network's resolver. The tunnel and kill switch were working; DNS simply went around them. The fix moved DNS into the tunnel and blocked the application's user from reaching the LAN at all.

## Impact

- The names of the external services the application contacts were visible to the local resolver, and from there to the upstream DNS provider, outside the VPN.
- No traffic other than DNS left the tunnel.

## Timeline (Nov 14)

- **Afternoon:** a read-only check of the local DNS resolver shows lookups coming from that container, some with the home domain appended through the DNS search path.
- **Follow-up:** the tunnel, kill switch and application binding all check out; only DNS is leaking.
- **Evening:** fix applied, then verified.

## Detection

I was reviewing the Pi-hole query log for an unrelated reason and saw the container's lookups. Its address should never appear there: everything it does is meant to go through the VPN.

## Root cause

Three settings combined:

1. The container's `resolv.conf` pointed at the LAN resolver, as Proxmox sets by default.
2. The kill-switch firewall rules allowed traffic to the local subnet, which is normal for management access, so DNS to the LAN resolver was allowed.
3. A DNS search domain caused names to be looked up a second time with the home domain appended.

The VPN itself was fine. DNS was never routed through it.

## Fix

1. Set `resolv.conf` to the VPN provider's DNS server, which is only reachable through the tunnel, with the LAN resolver as a fallback for root. Removed the search domain and set short timeouts.
2. Created `/etc/.pve-ignore.resolv.conf` so Proxmox does not overwrite the file.
3. Added an nftables output rule that drops any traffic from the application's user on the LAN interface. Root keeps LAN DNS, because the tunnel refresh script needs to resolve names while the tunnel is down.
4. Backed up the original files and wrote down the undo steps first.

## Verification

- The application's user cannot reach the LAN resolver.
- Its lookups resolve through the VPN provider's DNS.
- The Pi-hole log shows no further queries from the container.
- The external IP is still the VPN's, and the application still works.

## Lessons

- A VPN plus a kill switch covers traffic, not necessarily DNS. Test DNS on its own.
- Scope firewall rules to the user or process that needs isolation, not just to the interface.
- Platforms rewrite config files. Check whether yours will overwrite a change before relying on it.
