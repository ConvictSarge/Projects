# Email triage with local LLMs

Six business inboxes are triaged by small language models running locally (Ollama), so mail content never leaves the network. The models classify each message, summarize it, and draft a reply that a person reviews. Nothing is sent automatically.

## Pipeline

1. An IMAP trigger per mailbox picks up new mail.
2. A deduplication check skips messages already logged.
3. A small model classifies the message (contact, lead, spam, no-reply, automated) and rates urgency.
4. A routing step either moves spam, logs only, or sends the message on to drafting.
5. A second model drafts a reply, and a third model proofreads it.
6. The draft is saved in the mailbox for review, and everything is logged to PostgreSQL.

## Reliability work

- **Retry queue.** Any failure in classify, draft, proofread or save goes to a queue table. A sweep every 10 minutes retries up to 3 times, then marks the message "gave up" and sends one combined alert.
- **Watchdog.** Every 15 minutes it compares unread mail against the log. If a message older than 10 minutes was missed, it logs a stub row, restarts that mailbox's trigger, and alerts.
- **Proofreader guardrails.** A rewrite is used only if it keeps the greeting and sign-off, keeps at least 80% of the length, and adds no new URLs, prices or phone numbers. Otherwise the original draft is kept.

## The bug that taught me the most

For two weeks every classification came back "unreadable". The model's JSON was being parsed onto the item itself, but the routing step only looked in the raw text field. So no spam was ever moved, urgency was never high, and every draft was flagged for review. The fix was four lines. The lesson: when a guardrail fires on 100% of items, the guardrail is the bug.

## Stack

n8n, Ollama (small local models), IMAP, PostgreSQL, Discord alerts.
