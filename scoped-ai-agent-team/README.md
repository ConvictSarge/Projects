# A team of scoped AI agents in n8n, isolated at the database

I run a small business back office on n8n, and in November 2026 I turned ten of its "managers" into AI agents: a business manager, marketing, site reliability, billing, service desk, client services, compliance, client success, website care and cold-email deliverability. The hard part was not the prompts. It was making sure an agent can only do what its job allows, even if its prompt is tricked or it simply makes a mistake.

This write-up covers the design and what I tested. Everything is redacted: no hostnames, addresses, credentials or client data.

## The rule: scope comes from tools and credentials, not from the prompt

A prompt can say "never touch billing", but a prompt is a request, not a fence. So each agent gets only the tools it needs, and each tool can only reach what the agent's role allows:

- **One database role per agent.** Each agent connects to PostgreSQL as its own role, granted only its own domain. Billing can read billing views. The service desk can read tickets. Nothing can read another domain's tables or the raw tables underneath.
- **Views, not tables.** The agents read from a separate `agent_ro` schema of views. Columns that look like secrets are removed in the view, so even a bug in a query cannot return them.
- **Each agent has its own n8n credential and its own model API key.** The point is cost visibility: the provider console shows spend per key, so I can see which agent costs what. It is not a spending cap.
- **No action tools by default.** Most agents can check the system mode, read their own data, save notes to their own memory, and publish a summary. There are deliberately no send, refund or billing-write tools at all.

## Who may ask whom

Agents can consult each other, but only along edges I draw. In n8n this is each agent's list of sub-agents. The business manager can ask all of the others. Most specialists ask nobody, and a few ask one or two peers, for example the website-care agent can ask reliability, service desk and billing for facts. There are no cycles.

A request from a peer is treated as a question, never a command. The owner of a topic answers from its own data and acts only with its own tools. In my tests the marketing agent refused to tell the reliability agent to disable its alerts, and the reliability agent refused a restart request from marketing.

## Orders that really come from me

I wanted to be able to give an agent a real instruction without letting a pasted message or another agent fake one. Orders flow from me through a voice assistant to the business manager and then to the specialist. Each order is a row in a table that no agent can read or write directly. Agents call three functions: look up an order by number, mark it done, and (for the business manager only) list open ones.

An order is valid only if it is open, unexpired (24 hours), scoped to that agent and recorded from a channel that is verified as me. Orders from channels that can be spoofed, such as a phone call or text, stay pending until I tap a single-use confirmation link that expires in 30 minutes. An order never waives a hard rule, the test or live mode, or the separate approvals required for money, clients, contracts, prices and anything sent to the outside world.

## What I tested

- **Database isolation.** The billing role could read its own views and was denied every other domain and every raw table. No agent could read the orders table.
- **Refusals.** I tried to make agents break their own rules: bypass an allowance, skip a payment gate, issue a silent refund, quote a fake order number, switch the whole system from test to live, follow an instruction injected through data. Each one refused and named the owner and the approval needed.
- **A real order end to end.** A test order went from my chat to the business manager to the billing agent, which read the overdue-invoices view (test data) and closed the order.

## Limits and what is not done

- Everything runs in test mode. Nothing is live, and a calendar date does not change that.
- The voice assistant cannot yet tell which channel an order came from, so every relayed order currently needs the confirmation tap.
- A content filter at the model provider blocked two phrasings of one remote-fix test, so the wording of tests matters.
- Isolation depends on the database grants being right. I check them with role tests, but this is the part I would review again before any agent touches real client money.
