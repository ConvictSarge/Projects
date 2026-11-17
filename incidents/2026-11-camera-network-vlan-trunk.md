# Building camera network down: dead switch, bad fiber, and a VLAN that stopped one hop short

Day-job incident (campus IT, November 2026). The camera system belongs to a different department, but it shares our server room, so it came to me. Redacted: no building names, IP addresses or device names.

## Summary

A residence building's camera network went dark. Its access switch showed no link and a hard reset did not help, and the building's own fiber run also failed its light test. We brought the building back by running a fiber jumper from the building next door and installing a pre-configured replacement switch. The cameras stayed offline until I found that the neighboring switch, now the upstream hop, was not carrying the camera VLAN. That switch's management IP did not match the playbook, so I found it from the Layer 3 core, tagged the VLAN on the downstream link, and the cameras came back.

## Impact

- Every camera in one building was offline until the fix.
- Phones and internet were not affected (separate network).

## Timeline (same day, in order)

1. Building switch reported with no link. Hard reset: no change.
2. Building's fiber uplink tested: no usable receive/transmit light.
3. Plan: fiber jumper from the neighboring building plus a replacement switch, pre-programmed with the right management IP and VLANs.
4. Jumper run and switch installed. Link up, cameras still offline.
5. Realized the neighboring switch had to carry the camera VLAN too. Its playbook IP was wrong.
6. Found the switch's real address from the Layer 3 core switch and logged in.
7. Added the camera VLAN, tagged only on the port feeding the downstream building. Moved the upstream core port to a working one and turned on spanning tree on the new switch to match its upstream.
8. Cameras online.

## Detection

Reported by the department that owns the cameras. No alerting covered this switch.

## Root cause

Two physical failures (the switch and the building's fiber run; the likely cause is a damaged or collapsed run between the building's electrical room and the core). The longer outage came from a configuration gap: routing a building through a neighbor's switch makes that switch part of the path, and a VLAN has to be allowed on every hop between the endpoints and the core. The neighbor switch had been moved from another site and never re-addressed, so the documentation pointed to the wrong device.

## Fix

- Fiber jumper from the neighboring building as a temporary trunk.
- Replacement switch with the building's IP and VLAN layout.
- Camera VLAN added on the neighboring switch, tagged only on the downstream link (smallest change, nothing else on that switch exposed to it).
- Upstream port moved and spanning tree enabled on the new switch.

## Prevention

- Playbook corrected with the neighbor switch's real IP.
- Sent a written summary to the owning department: the new path, each config change, and the inconsistencies I found along the way (several switches whose IPs don't match the spreadsheet, one still on its factory default, a DNS name that points at the wrong device, unlabeled dead fiber ends in two closets).
- Recommended putting back a fiber switch that had been removed. It used to serve this area, and without it the core has no free port for the building's original uplink.
- Recommended repairing the building's own fiber run so the temporary trunk can be retired.

## Lessons

- When traffic is rerouted through a neighbor, check every hop's VLAN config, not just the new device.
- Documentation that is wrong costs more time than none at all. The Layer 3 switch's ARP and MAC tables are the source of truth when the spreadsheet is in doubt.
- Write it up the same day, wrong entries included, so the next person isn't guessing.
