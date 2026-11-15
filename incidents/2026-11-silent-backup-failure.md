# Nightly backups stopped silently after a reboot

**Status:** resolved.

## Summary

After a planned reboot, both Proxmox nodes lost their connection to the network backup share. The nightly backup jobs stopped running, and nothing alerted, because the alerting only covered jobs that ran and failed, not jobs that never started. I found it during a routine health check two days later.

## Impact

- Two nights with no backups of any VM or container.
- One earlier night's archives were written but logged as failed, so they cannot be trusted without a restore test.
- No data was lost: nothing needed restoring during the gap.

## Timeline

- **Nov 11, evening:** planned reboot of the cluster.
- **Nov 12:** the backup job writes archives but logs the run as failed.
- **Nov 13 to 14:** the scheduled jobs never start.
- **Nov 14:** a health check shows the backup storage inactive on both nodes; the share is remounted, backups are tested and alerting is added.

## Detection

A manual health check, not an alert. Proxmox showed the CIFS backup storage as inactive on both nodes, and the job history had a gap. That is the real finding: **the system had no way to tell me backups had stopped.**

## Root cause

The backup target is an SMB/CIFS share on the NAS. After the reboot, the mount on each node was left with a **stale file handle**. Proxmox treated the storage as unavailable, so the scheduled `vzdump` jobs never started. Because they never started, they never failed, and no failure notification was sent.

## Fix

1. Lazily unmounted the stale share on both nodes (`umount -l`), which let Proxmox remount it.
2. Confirmed through the Proxmox API that the storage was active on both nodes.
3. Ran a test backup of one container (243 MB in 12 seconds) and confirmed retention pruned old copies per policy.

## Prevention

- **Alerting:** Proxmox notifications now go to an authenticated n8n webhook, which posts to Discord on errors only.
- **Secret handling found along the way:** n8n saved the full data of every successful run, including the webhook key in the request headers. I turned off saving successful runs for that workflow (errors are still saved), rotated the key so the stored copies were useless, and confirmed new runs were not stored. The key is generated on the server into a root-only file and never printed.
- **Next:** an automated restore test, which restores the latest backup into an isolated pool, checks that it boots, and tears it down. Missing or broken backups then show up as a failed test rather than as silence.

## Lessons

- "No failure alerts" does not mean "backups are working." A job that never starts never fails.
- Check that backups ran, not just that runs didn't fail. The age of the newest backup is a better signal than the error count.
- When adding a webhook, check what the automation tool logs before sending a secret through it.
