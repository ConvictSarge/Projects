# Weekly email list on my own stack

A weekly email for my small business, built on infrastructure I already ran: PostgreSQL, n8n, an existing SMTP account and a few PHP pages. No mailing-list service, no new monthly bill, and the subscriber data stays on my own server.

## Ways onto the list

| Source | Consent |
|---|---|
| Sign-up form on the website | Double opt-in: a confirm link that expires after 7 days |
| "Send me the weekly email" box on the contact form | Double opt-in |
| Store checkout (being wired up) | Only if the buyer ticks the updates box |
| Digital product marketplace (built, waiting on the account) | Only if the buyer allowed contact; the sale is re-read from the marketplace API instead of trusting the webhook body |

People who unsubscribe or bounce stay in the table as a suppression list. Only a sign-up they confirm themselves brings them back. A buyer can't be re-added just by buying again.

## Weekly cycle

1. During the week, anything worth sharing goes into a notes table (title, body, optional link).
2. Monday morning: if there are notes, an LLM drafts the email from those notes only. I get one chat message with a link to a preview page and an Approve button.
3. Tuesday to Friday: once approved, the issue goes out. No notes means no email that week. An unapproved draft is skipped the next Monday, and its notes carry over.

## Design choices

- **The database holds the rules.** All logic lives in PostgreSQL functions (`SECURITY DEFINER`). The automation's database role can only execute those functions and add notes. It can't read or change the subscriber table directly, so a broken or compromised workflow can't dump or rewrite the list.
- **Claim before send.** Each recipient is claimed in a sends table before any mail goes out. A crash or rerun picks up only the people not yet claimed, so nobody gets the same issue twice:

  ```sql
  INSERT INTO nl_sends (issue_id, subscriber_id)
  SELECT i.id, s.id FROM nl_subscribers s
  WHERE s.status = 'active'
  ON CONFLICT DO NOTHING RETURNING subscriber_id;
  ```

- **Links can be fetched by bots, so links don't act.** Email scanners and chat apps open links on their own. Confirm, unsubscribe and approve links all open a page with a button, and only the button's POST does the action. Discord's link preview would otherwise have approved the email by itself.
- **One-click unsubscribe (RFC 8058).** The unsubscribe page also accepts the standard one-click POST.
- **Abuse limits on the form.** A honeypot field, a CSRF token, a minimum fill time, and at most one confirm email per address every 10 minutes.
- **Compliance.** Every email carries a postal address and an unsubscribe link, and the send refuses to run if the address isn't set. The privacy policy says what is collected and why.
- **Website-to-automation traffic stays on the LAN.** The PHP pages call n8n over the local network with a shared-secret header. A request without the secret gets a 403.

## Testing

- Before going live, I ran the whole database script inside a transaction with 26 checks (subscribe, confirm, expiry, throttle, suppression, claim and rerun, approve), then rolled it back.
- Live checks with no side effects: no secret returns 403, a bad operation returns invalid, an unknown unsubscribe token returns a neutral "done", and no rows were created.
- Bugs the dry run caught: the automation's role was blocked from reading a table directly (fixed with a new function, not a wider grant), and a confirm could be credited to the wrong source (fixed with a column set when the confirm email goes out).

## Stack

PostgreSQL (functions, least-privilege role), n8n, PHP, SMTP, Claude for drafting, Discord for the approval message.
