# Hypervisor at 98% swap with almost no load

**Status:** resolved; two further optimizations are still open.

## Summary

One Proxmox node had 7.8 of 8 GB of swap in use and about 80% of its RAM used, even though CPU load was low and there was no I/O wait. The cause was a single VM with a large fixed memory allocation and no ballooning. Most of what the host counted as "used" was that guest's own page cache.

## Impact

- High swap use risks slow services and out-of-memory kills on a node that runs about 30 containers and several VMs.
- No outage occurred.

## Investigation

- Host: 25.4 of 31.2 GB RAM used, swap 97.7%, load around 2, no I/O wait.
- All 33 containers together used about 6 GB. Container memory limits are not reservations, so they were not the problem.
- One VM had 18 GB of RAM assigned with no balloon device configured. Inside the guest, only 7.4 GB was in use by applications; another 9.5 GB was page cache.
- From the host's point of view, all 16.7 GB the guest had touched was used memory, and the host does not reclaim a guest's page cache on its own.

## Root cause

A fixed-size VM with no ballooning holds every page it has ever touched, and Linux inside the guest fills spare RAM with cache. So the guest looked healthy and the host looked full.

## Fix

1. Dropped the guest's page cache once (9.5 GB down to 2.5 GB inside the guest) to relieve pressure immediately.
2. Enabled ballooning with an 8 GB minimum (`qm set <vmid> --balloon 8192`), applied live, after confirming the guest had the `virtio_balloon` driver. Undo: `qm set <vmid> --delete balloon`.
3. Result: host memory at 79.9%, swap down from 97.7% to 79.9%, with no restarts.

Proxmox's automatic ballooning only reclaims memory when host usage is above 80%. Under pressure, this VM can now shrink toward 8 GB instead of pushing the host into swap.

## Still open

- Another VM has 8 GB allocated but uses about 1.6 GB; right-sizing it to 4 GB would free more.
- Swap is still mostly full of old pages; clearing it in a quiet window would reset the baseline.

## Lessons

- Container memory is a limit; VM memory is an allocation. Check VMs first when the host looks full.
- Guest page cache counts as used memory on the host unless the guest can give it back.
- Fix the steady state (ballooning), not just the moment (dropping caches).
