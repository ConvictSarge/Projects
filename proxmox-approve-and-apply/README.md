# Approval-gated Proxmox fixes in n8n

Two n8n workflows that don't stop at a report: they find a problem on a Proxmox VE cluster, ask a person, and then make the change safely. I built them as free templates for the n8n template library after the reviewers turned down two of my read-only templates as "too basic".

- **Guest rightsizing:** finds VMs and containers with too much or too little CPU and RAM from Proxmox's own usage history (average and peak), and resizes the ones you approve.
- **Guest hygiene:** checks every guest for six basics (in a backup job, starts at boot, delete protection, an owner tag, a description, the QEMU guest agent) and fixes the ones you approve.

## The pattern

Report-only workflows are safe because they can't do anything. Once a workflow changes real machines, every step between "found it" and "changed it" needs a guard. Both workflows use the same chain:

1. **Confirm before offering.** Every run is saved to an n8n Data table. Rightsizing only offers a change once the same finding shows up in N runs in a row (default 2), so one odd week never resizes a guest. Hygiene uses the history to say what is new, what is still open and since when, and what got fixed.
2. **Ask with a signed link.** The alert carries an n8n Wait-node form URL with a signature, open for a set number of hours. No answer means no change.
3. **Whitelist the answer.** The form is prefilled with one line per guest. A person can delete a line or a single value, but the workflow rejects anything that was not in the report: a raised value, a new guest, an added fix.
4. **Re-check right before the change.** Between the report and the click, things move. Each guest's config is read again: still the same size, not locked, CPU sockets divide evenly, the setting is still wrong.
5. **Make the change reversible or atomic.** Rightsizing takes a snapshot and polls the task until it finishes; no finished snapshot, no change. Hygiene sends Proxmox's config digest with the update, so if anyone edited the guest in the meantime Proxmox refuses the write instead of overwriting it.
6. **Read it back.** After every write the workflow reads the config (or the `/pending` list, for changes that only apply after a reboot) and reports applied, after reboot, skipped or failed, with the old values so any change can be undone by hand.

## Things that went wrong, and what I changed

- **The template portal broke my workflow without an error.** After submission, the portal's automatic review renamed all 42 nodes for readability but did not update the JavaScript that refers to other nodes by name. My report code wraps those reads so a missing node returns nothing, which meant every run would have reported "0 guests, all fine". I caught it by diffing the processed copy against mine, then adopted the portal's names in my build step, which rewrites every reference. A check proves the result: reversing the renames gives back exactly the workflow I tested. The second template uses names in the portal's style from the start.
- **A disabled check looked like a fix.** Hygiene first counted a problem as "fixed" whenever it was in last week's run but not this week's. Turning a check off would have reported every guest it used to flag as fixed. Now a finding only counts as fixed if the same check still ran on that guest.
- **A token with too little access failed loudly, as it should.** My first test used a token without `Sys.Audit`, so Proxmox refused the backup-coverage call. The run ended as a failed execution instead of a quiet "every guest is backed up". The test copy now uses a separate read-only token.

## How I tested it

- Live runs on a two-node Proxmox VE 9 cluster (about 50 guests) with alerts pointed at a dead local URL, so nothing reached a real channel. I submitted "Change nothing" on the real approval forms to prove the resume path.
- To prove the new and fixed lists without touching any guest, I edited two rows in the test history table and checked that the next run reported exactly those two.
- The fix steps can't run with a read-only token, so I unit-tested their five Code nodes in Node.js with mocked n8n globals (`$()`, `$json`, `$now`, `$execution`): 21 cases covering the whitelist, every backup-job mode, the lock and digest refusals, read-back catching a change that didn't take, and the summary counts.
- A linter checks the template rules (sticky notes, node names, no credentials or private addresses, code and HTTP notes), and every file is test-imported into n8n before it goes up.

Not yet done: the resize and settings changes have not been applied to a real guest. That waits for a throwaway test guest.

## Tools

n8n (Data tables, Wait-node forms, Loop Over Items, Code nodes), the Proxmox VE REST API, JavaScript, Python for the build and lint steps, Node.js for the unit tests.
