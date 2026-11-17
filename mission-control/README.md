# Mission Control: a live dashboard served by n8n

One web page that shows how my automations and my business are doing right now: which groups of workflows are healthy, what is waiting for my approval, what money is coming in and going out, what is due soon, and a replay of the last 24 hours. It runs on a wall display. There is no separate web app: n8n serves the page and its data feeds. Everything is redacted: no URLs, IDs, numbers from the business or credentials.

## How it works

```
browser (wall display)
  -> GET page          -> n8n webhook returns one self-contained HTML file
  -> poll main feed    -> n8n: workflow health, recent runs, approvals
  -> poll extras feed  -> n8n: money, usage, calendar, outreach, countdowns (every 60 s)
  -> replay feed       -> n8n: last 24 h of recorded snapshots
```

- **The page is plain HTML, CSS and JavaScript** returned by a webhook. No build step, so a change is an edit to the workflow and a publish.
- **Each feed is a workflow** that queries PostgreSQL, n8n's own API and data tables, and a few small local services, then returns JSON.
- **The look:** the business is drawn as a brain. Each "lobe" is a group of workflows owned by one manager, coloured by health; recent runs show as impulses; approvals waiting on me pulse in the brainstem. Workflows with no owner land in an "unassigned" lobe, which is a to-do list in itself.

## Panels

- **Workflow health** by owner, from n8n's execution data.
- **Approvals pending**, so nothing waits on me without my knowing.
- **Money and usage:** monthly bills against the break-even target, AI and GPU spend against their budgets, email-verification credits left, alerts in the last 24 hours, and the next bill due. Fed by the same tables the usage watches write (see [usage watches](../usage-watches/README.md)).
- **Today and tomorrow** from my self-hosted calendar.
- **Outreach pipeline:** messages ready to send and messages still in review.
- **Countdowns** to fixed dates plus the next bills.
- **24-hour replay:** a slider that scrubs back through the day.

## Design decisions

- **Only real data counts.** The "sites live" tile once showed 73, because test records were counted. Live tiles now exclude anything flagged as test, and the test count is kept separately for my own checks.
- **Replay costs nothing when nobody is looking.** Snapshots are recorded only while a page is actually polling, and kept for three days.
- **Every change keeps a rollback.** Each edit to the page or feeds is published as a new workflow version, and the previous version id is written down so a bad change is one click to undo.
- **Labels must be true.** The calendar card used to label every future event "Tomorrow". It now names the weekday for anything past tomorrow. Small, but a dashboard you can't trust gets ignored.

## Stack

n8n (webhooks, PostgreSQL, data tables, n8n API), hand-written HTML/CSS/JavaScript, PostgreSQL, a self-hosted calendar service.
