# Proxmox tools packaged as n8n workflows

Six n8n workflows for people who run Proxmox VE, built and tested on my own two-node cluster, then packaged for sale by my business. Each one runs on a least-privilege API token and is safe to leave unattended. This write-up covers how they work and the problems testing caught. Everything is redacted: no addresses, hostnames, IDs or credentials.

| Workflow | What it does |
|---|---|
| Backup Proof | Every night, restores one guest's newest backup to a throwaway copy with no network, checks it boots and stays up, deletes it, and records the result |
| MSP Proof Pack | Backup Proof across several clusters, plus a branded monthly PDF per client |
| Access Audit | Who can get in and how: accounts without 2FA, admin rights on the whole cluster, tokens that never expire or aren't privilege-separated, root and failed logins |
| Patch & Reboot Report | Updates waiting per node, nodes that need a reboot for a newer kernel, version drift, VMs past end of security support |
| VM Lease Manager | Tag a guest `expires-2026-12-31`: a warning before the date, a clean shutdown after a grace period, never a delete |
| Backup Freshness Watch | Free: a daily check that every guest has a recent backup |

## Backup Proof: proving restores, safely

A backup you've never restored is a guess. The drill picks the guest proven longest ago, restores its newest backup into a scratch pool and ID range, and boots it.

- **The copy never gets a network card.** Every NIC is removed from the copy's config before its first boot, so it can't reach the network or clash with the real guest's IP and MAC. The QEMU guest agent still answers over virtio-serial, so a VM can still prove it booted.
- **A safety gate before every start.** The drill re-reads the copy's config and refuses to start it unless it has no network and carries the drill's own marker. In an early test, Proxmox ignored the network override passed to the restore call and the copy came back with its NIC live. The gate refused to boot it and cleanup removed it. The fix was a separate config update after the restore, with the gate kept in place.
- **It can only delete its own copies.** Cleanup runs in a sub-workflow that checks three things first: the guest is in the scratch pool, its ID is in the scratch range, and its description carries the marker. The token can create and delete guests only inside that pool, plus the two storages it restores from and to.
- **Guests it won't test, with the reason:** PCI or USB passthrough, raw QEMU arguments, privileged containers, bind mounts, and backups or memory over a size limit. A copy that grabbed real hardware would be worse than no test.
- **Only a pass counts.** At first a failed run marked a guest as tested, so the rotation skipped it. Now only a pass resets a guest's turn, and a failure is retried the next night.
- **Network storage stalls.** Listing backups on a CIFS share sometimes timed out. Reads now retry with a pause, and a run that still can't read is reported as a setup problem, not a failed backup.

A real run: a 13 GB VM backup restored in 142 seconds, booted with all three network cards removed, stayed up 120 seconds while the guest agent answered, and was deleted. The whole test took 273 seconds and the real VM never stopped.

## Monthly report: a PDF with no PDF library

The monthly report has to work on hosted n8n, where you can't install packages or run a PDF service. So one Code node writes the PDF by hand: the file structure, the cross-reference table, the standard Helvetica fonts with a width table for text fitting and wrapping, table rows that flow onto new pages, a JPEG logo embedded as-is, and page numbers added at the end. A test with 70 guests made a correct 4-page document.

Several clusters share one run table with a `client` column, and each cluster keeps its own rotation. The drill also saves the full guest list each night with the reason any guest can't be tested, so the report covers every guest, not just the ones that have run. Two bugs from the first live report:

- Runs at 11 PM were counted on the next day because dates were grouped in UTC. They now use the workflow's time zone.
- Forty guests simply waiting their turn showed as "Not tested" in amber, which read as alarming. They now show as "Queued" on one line, and only guests that really can't be tested get a reason.

## Packaging and buyer-style testing

- **The test copy is never the shipped copy.** A build script makes my copy (my tokens, my alert hook, my error workflow) and a separate buyer copy (no credentials, placeholders, report-only defaults). The packager refuses to build a zip if any file still contains one of my IDs, addresses or account names.
- **Reproducible zips.** Fixed timestamps mean a zip only changes when a file inside changes, so the published SHA-1 and SHA-256 sums stay valid.
- **A fresh-import test.** I downloaded the finished zips, checked their sums, imported them with n8n's own command-line import, set each one up using only its setup guide, and ran it on the cluster. It caught two things:
  - With a token that can't see backup files, the free check reported "no backup found" for every guest, a scary false alarm. Now "no backup files visible anywhere" stops once with the exact permissions the token needs.
  - My own test copies used the same manual-run webhook addresses as the buyer files, so every buyer would have known them. Test copies now get a private suffix.

## Store

Payments go through Square payment links. The webhook's HMAC signature is checked, then the payment is read back from Square's API, so the webhook body is never trusted. Each order is claimed in a table before anything is delivered, so a retried webhook can't send a second set of links. Download links last 30 days with a 10-download limit, stored as locked JSON files because the web server has no database extension. The whole path, from checkout to the paid download, has been tested end to end in Square's sandbox.

## Demo videos

The demo videos are built only from real runs. A script renders evidence cards from the workflow results with headless Chrome. Lab names are swapped for neutral labels, and a guard refuses to render a card that still contains a hostname, an IP or a token name. A small render service adds per-line voice-over and captions, and writes drafts that can't be scheduled or posted until I approve them.

## Stack

Proxmox VE API, n8n (Code, HTTP Request, Data Tables, sub-workflows), JavaScript, Python build scripts, PHP, Square, headless Chrome, ffmpeg.
