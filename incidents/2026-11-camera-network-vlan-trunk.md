# Building camera network down: dead switch, bad fiber, and a VLAN that stopped one hop short

Day-job incident, November 2026, outside my normal role. The camera system belongs to another department, so I was asked to help. Redacted: no site, building or device names, and no addresses.

## Summary

One building's camera network went dark. Its access switch showed no link and a hard reset did not help, and the building's fiber uplink also failed its light test. We brought the building back by running a fiber jumper from the building next door and installing a pre-configured replacement switch. The cameras stayed offline until I found that the neighboring switch, now the upstream hop, was not carrying the camera VLAN. That switch's management IP did not match the playbook, so I found it from the Layer 3 core, tagged the VLAN on the downstream link, and the cameras came back.

## Impact

- The cameras in one building were offline until the fix.
- Phones and internet were not affected (separate network).

## Timeline (same day, in order)

1. Building switch reported with no link. Hard reset: no change.
2. Building's fiber uplink tested: no usable receive/transmit light.
3. Plan: fiber jumper from the neighboring building plus a replacement switch, pre-programmed with the right management IP and VLANs.
4. Jumper run and switch installed. Link up, cameras still offline.
5. Realized the neighboring switch had to carry the camera VLAN too. Its playbook IP was wrong.
6. Found the switch's real address from the Layer 3 core switch and logged in.
7. Added the camera VLAN, tagged only on the port feeding the downstream building. Moved the uplink to a working core port and turned on spanning tree on the new switch to match its upstream.
8. Cameras online.

## Root cause

Two physical failures: the building's switch and its fiber uplink. The longer outage came from a configuration gap: routing a building through a neighbor's switch makes that switch part of the path, and a VLAN has to be allowed on every hop between the endpoints and the core. The neighbor switch had been moved from another location and never re-addressed, so the documentation pointed to the wrong device.

## Fix

- Fiber jumper from the neighboring building as a temporary trunk.
- Replacement switch with the building's IP and VLAN layout.
- Camera VLAN added on the neighboring switch, tagged only on the downstream link (smallest change, nothing else on that switch exposed to it).
- Uplink moved and spanning tree enabled on the new switch.

## Prevention

- Playbook corrected with the neighbor switch's real IP.
- Sent the owning department a written summary of the new path, every config change, and the documentation gaps I ran into, with recommendations for a permanent fix.

## Lessons

- When traffic is rerouted through a neighbor, check every hop's VLAN config, not just the new device.
- Documentation that is wrong costs more time than none at all. When the spreadsheet is in doubt, the Layer 3 core shows what is really connected.
- Write it up the same day, so the next person isn't guessing.
