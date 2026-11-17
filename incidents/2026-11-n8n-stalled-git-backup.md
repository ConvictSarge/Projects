# Nightly workflow backup stalled after an n8n update

**Status:** resolved.

## Summary

A nightly n8n workflow that copies every automation workflow to a private Git repository started failing after an n8n update. Each run hung for five minutes on a step that fetches one file per workflow from the GitHub API, then failed with "Response body timed out". My first fix (retry and continue) made it worse, so I rolled it back, reproduced the fault in a read-only copy, and found that the new HTTP layer loses replies when one node handles a few hundred items. Processing 25 items per loop fixed it.

## Impact

- Four nights with no workflow backups (Nov 14 to 17). 75 of 277 workflows had never been backed up.
- No workflow was lost or changed; the backup is a safety copy, not the source of truth.
- The first attempted fix briefly turned a loud failure into a silent hang. It was rolled back within the hour.

## Timeline

Times are Eastern.

- **Nov 13:** n8n container rebuilt on a newer 2.x release.
- **Nov 14 to 17, 2:20 AM:** the backup fails each night at the same step after exactly five minutes.
- **Nov 17, 9 AM:** the morning failure review flags it as recurring (second night in the review window).
- **11:06 AM:** first fix applied: retry the fetch step three times and continue on error.
- **11:30 AM:** the test run is still "running" after 20 minutes with no open connection to GitHub. Something other than GitHub is stuck.
- **11:43 AM:** first fix rolled back so the job fails loudly again. Read-only test copy built.
- **11:49 to 11:55 AM:** fault reproduced and narrowed down (see below).
- **11:57 AM:** fix applied to the live workflow. **12:01 PM:** a hand run finishes in 4.5 minutes.
- **12:09 PM:** independent check: all 277 workflow files present in the repository.

## Detection

The daily self-heal review, which lists every failed n8n run with its error. The error message pointed at an idle timer inside n8n's HTTP code, not at GitHub, which was the first useful clue.

## Investigation

I watched the n8n container's open connections to GitHub while a run was going (`ss` inside the container's network namespace). The workflow made two batches of ten requests, then stopped opening connections entirely, with nothing in flight, until the five-minute timer fired. So n8n was waiting on replies that had already arrived.

Reading the timer code in the installed package showed it waits for a stream's `end` event. If the stream has already finished before anything listens, that event never arrives and only the timer ends the wait.

Then I narrowed it down in a read-only copy of the workflow (GET requests only, nothing written):

| Test | Result |
|---|---|
| Compression turned off (`Accept-Encoding: identity`) | Stalled |
| One request at a time, all 277 items | Stalled |
| A file that does not exist (404) | Fine |
| Eight separate runs of 35 items each | All fine, about 15 s each |
| All 277 items, **25 per loop pass** | **Fine, 29 to 30 s, twice in a row** |

No single file was the problem. The trigger was one HTTP node handling a few hundred items in one execution.

## Root cause

A regression in the newer n8n HTTP layer: when a single HTTP Request node processes a long list of items, it stops making progress and waits until its five-minute idle timer fails the run. The most likely mechanism, from the code and the empty connection list, is that some response bodies finish before n8n starts reading them, so the end-of-stream signal is missed. I proved the trigger and the workaround, not the exact line of the bug. It started with the container rebuild on Nov 13 and hit this workflow first because it makes far more requests per run (one per workflow) than anything else.

## Fix

1. Wrapped the "fetch existing file" step in a Loop Over Items node with a batch size of 25.
2. Did the same for the "save file" step, since the first run had at least 75 new files to upload.
3. Kept the earlier version as a one-click rollback.
4. Verified twice: the live run succeeded (its own "some files not saved" guard did not fire), and a separate read-only pass found 277 of 277 files in the repository, up from 202.

## Prevention

- Swept every active workflow for the same pattern. n8n's logs since the update showed the error only for this job, and the other list-processing HTTP steps handle 11 to 40 items per run. They are on a watch list to get the same 25-item loop if they grow.
- Failures stay loud: every workflow reports errors to a central error workflow, and the daily review counts them.
- Re-test after the next n8n update and remove the workaround if the regression is fixed.

## Lessons

- **"Retry and continue" is not a fix until you know the cause.** Here it hid the failure: the run hung forever instead of failing, which is worse than a clear error.
- **Watch the system, not just the logs.** Seeing zero open connections while the run was "waiting" ruled out the remote service in one step.
- **Narrow it down with a read-only copy.** Halving the input and changing one thing at a time found the trigger in about 15 minutes without touching the live job.
- **A backup that fails every night is only useful if someone notices.** This one was caught by a daily failure review, not by luck.
