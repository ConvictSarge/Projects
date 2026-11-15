# Network dropouts: a NIC hang and a leaking switch

**Status:** NIC fix applied; switch on new firmware and under watch.

## Summary

For about two weeks the house network and the self-hosted services dropped out at random. It looked like one problem ("the switch is turning off"). It was two: one hypervisor node's network card hanging and taking that node's services down, and a managed switch that restarted itself about once a day, most likely from a memory leak in its firmware.

## Impact

- Three long outages (10, 3 and 54 minutes) where every service on one of the two Proxmox nodes was unreachable: automation, password vaults, document signing, file sync and media.
- Roughly daily 1 to 2 minute whole-network blips, when the switch restarted, that briefly took down internet access and the Cloudflare Tunnel.

## Timeline

- **Late Oct to Nov 4:** the switch's web interface refuses connections for 20 to 40 minutes most days.
- **Nov 2, Nov 4, Nov 8:** long outages; node B is unreachable and comes back only after a reboot.
- **Nov 11 to 12:** investigation starts; monitoring and a log receiver are added.
- **Nov 12, 16:56:** both nodes lose link in the same second; internet and router pings fail for about 1 minute 40 seconds; the switch logs a cold start.
- **Nov 13, 14:35:** a second spontaneous cold start, about 21.5 hours later.
- **Nov 13 to 14:** switch firmware upgraded to the latest release.

## Detection

The first theory was that the switch was losing power or overheating. Instead of guessing, I collected evidence from three places that fail independently:

- Prometheus metrics, which run on node B, so they are blind when node B is down.
- Uptime Kuma, which runs on node A, with new 30-second pings to the router and to a public IP. Router up but internet down means the WAN; both down means inside the LAN.
- A syslog receiver (Vector into Loki) for the switch's logs, plus SNMP polling of its uptime and PoE draw.

## Root cause

**1. NIC hang on node B (the long outages).** Node B's onboard Intel NIC (e1000e driver) logged `Detected Hardware Unit Hang` every two seconds until the node was rebooted. During these windows the tunnel and the internet were still up: public requests returned 502 (backend down), not 530 (tunnel down). That ruled out the switch for these outages. Node A stayed up for 43 days throughout. The cluster kept quorum the whole time, because a third vote comes from a QDevice.

**2. The switch restarting itself (the short blips).** Its own log showed `System Cold Start` with no power event. Power and heat were ruled out: it is on direct wall power on its own breaker, the fan reads OK, and PoE draw was 290 to 315 W of a 410 W budget. The CLI showed memory at about 95% used 16 hours after a reboot and 83% six minutes after one. That pattern points to a firmware memory leak, which would also explain the web interface refusing connections.

## Fix

- **NIC:** turned off TCP segmentation, generic segmentation and generic receive offload on node B's interface (`ethtool -K nic0 tso off gso off gro off`) and made it persistent in the interface config. This is the standard workaround for this hang on e1000e.
- **Switch:** upgraded the firmware to the latest release. The first attempt failed because the browser upload needed more free memory than the leaking switch had. TFTP to the backup partition worked once I dropped the `tftp://` prefix from the server field; a packet capture showed the switch was not sending any request while the prefix was there. The old firmware stays on the other partition for rollback.

## Prevention

- Switch syslog now goes to Loki with 60-day retention, and the switch's flash log is on, so the logs from before a crash survive the reboot.
- A Grafana dashboard tracks the switch's uptime and reboot count, PoE draw against its budget, and its syslog.
- Router and internet pings alert my phone after one missed 30-second check.
- Next step if the switch restarts again: a support ticket with the cold-start times and memory readings, and replacing the switch as a fallback.

## Lessons

- One symptom can have two unrelated causes. Splitting the outages by type (long ones on one node versus short whole-network ones) separated them.
- Don't let your monitoring live on the thing that fails. Metrics on node B could not see node B's outages; the second monitor on node A could.
- The HTTP status code told the story: 502 meant the backend was down, 530 meant the tunnel was down.
- Firmware upgrades on a device that is low on memory may need a different transfer method.
