# Store sales webhook: signed, deduplicated, hands-off

My business sells n8n workflow packs on Gumroad. When a sale happens, Gumroad sends a "ping" (a webhook) to an n8n workflow I run. This write-up covers how that workflow decides a ping is real, makes sure each sale is handled exactly once, and what happens next, plus the small management layer that lets me run the store from any computer. Everything is redacted: no URLs, IDs, tokens or buyer data.

## The flow

```
Gumroad ping
  -> read the raw body (before any parsing)
  -> HMAC of the raw body with a shared secret -> compare -> reject if it doesn't match
  -> seen this event before? -> yes: stop (a test ping only gets a one-line notice)
  -> claim the event id in a table (so a retry or a duplicate can't run it twice)
  -> read the sale back from the store's API -> check it
  -> record it (sale or refund) -> tell me on Discord -> add the buyer to the newsletter only if they opted in
```

## Design decisions

- **Verify the raw body, not the parsed one.** A signature is computed over exact bytes. If the workflow parsed the form data first and re-serialized it, field order or encoding could change and good pings would fail, or a check could be written loosely enough to pass bad ones. The first node keeps the raw body; the HMAC is computed on that; parsing happens after the check.
- **The secret lives in a data table, not in the workflow.** The workflow can be exported, shared or backed up to Git without carrying the secret. Pings without a valid signature go no further.
- **Claim before work.** Webhook senders retry. The event id is written to a table before any side effect, and a second delivery of the same id stops at "seen before". This is the same claim-before-send pattern I use for email, so a rerun never double-records a sale or double-mails a buyer.
- **Don't trust the ping for the details.** After the signature check, the workflow reads the sale back from the store's API and records what the API says.
- **One notice per event, and only real ones.** Sales and refunds post to Discord. A store "test ping" gets a single line saying the endpoint works, so testing never looks like revenue.
- **Opt-in only for the newsletter.** Buyers are added to the list only if they opted in at checkout.

## Managing the store

I also connected the store's API to my self-hosted MCP hub (the server that gives AI assistants controlled access to my tools), so products, files and prices can be managed from any of my computers without a browser. One thing testing turned up: **attaching a file and embedding it in the product were two separate steps** in the API. The tool now does both in one call; I tested it by adding a checksum file to the free product.

## Verified, and what isn't yet

- Verified end to end with a real sale and real signed pings, with signature checking switched on.
- Not yet seen in the wild: refunds, disputes and subscription events. They are handled in the same path, but only with made-up data so far. They get checked the first time a real one arrives.

## Stack

n8n (webhook, Crypto node for HMAC, data tables, HTTP), Gumroad API, Discord, a PostgreSQL-backed newsletter, a self-hosted MCP hub.
