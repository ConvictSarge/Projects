# Small-business back office on n8n

The operations back end for my IT consulting business: lead intake, contracts, invoicing, payment schedules, client portal access and appointment reminders. Built on n8n and PostgreSQL and tested in sandbox mode before launch.

## What it does

- **Lead intake:** web form and email leads land in PostgreSQL, get an acknowledgement, and follow-ups stop automatically when the lead replies or opts out.
- **Contracts:** a contract is generated from the order, sent for e-signature, and a signed-contract webhook starts billing.
- **Billing:** projects over a set amount are billed 50% up front and 50% on approval, and smaller ones in full. Overdue invoices accrue simple interest, but every collection step needs a human tap and nothing is sent automatically.
- **Payments catalog:** the payment processor's catalog is generated from one price list, so contract, invoice and catalog prices cannot drift apart.
- **Client portal access:** a desired-state SQL view decides who should have portal access, and a sync job makes the access group match it.
- **Appointment reminders:** reminders and rebooking links, with quiet hours and stop rules.

## Design choices

- **Webhook first.** Every flow can be triggered and tested on its own.
- **Data in PostgreSQL, logic in n8n.** Each client automation gets its own schema and database role, so one client's workflow cannot read another's data.
- **Test mode is a switch, not a copy.** While test mode is on, all outbound mail goes to a test recipient with a [TEST] tag.
- **Every workflow has an error path.** Failures go to one error workflow that posts a deduplicated alert.

## Problems I hit and fixed

- n8n Data Table filters default to "match any condition". One unfiltered stop rule could have marked every active lead as replied. Fix: set "all conditions" explicitly on every multi-condition filter, and check for it in reviews.
- An UPDATE ... RETURNING step reported success even when it changed zero rows, so a one-time question was sent every hour. Fix: an IF node that checks the returned key before the send step.
- A batch job fetched slow or dead websites one after another with no overall time limit, so the runner was killed before it saved anything, and it retried the same rows forever. Fix: a time budget that stops starting new work after 40 seconds and saves what finished.

## Stack

n8n, PostgreSQL (roles, schemas, row-level security), webhooks, a payment processor's sandbox API, an e-signature API, Cloudflare Access, Proxmox LXC, Docker.
