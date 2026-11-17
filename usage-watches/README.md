# Usage and budget watches for pay-as-you-go services

A few of the services my automations use bill by usage: an AI API, a GPU cloud for video rendering, and an email-verification service sold in credits. Any of them can quietly run up a bill if a job loops or a server is left running. These are small n8n workflows that watch each one and tell me once, early, when something is off. Everything is redacted: no account details, keys or IDs.

| Watch | When | What it checks |
|---|---|---|
| GPU cloud | Hourly | Spend this month against a $50 budget, the month's pace, and a runaway check on the current hourly rate |
| AI API | Daily | Cost this month against the $200 of usage included in my plan |
| Email-verification credits | Daily | How fast credits are being used against the plan; adds a "top up or upgrade" item to my to-do list three days before they would run out |
| Bills | Daily | Every recurring business bill with its amount and whether it is on autopay |

## How the GPU watch works

The provider's API reports a balance and a current spend rate, not "spend this month", and the account refills itself automatically. So the workflow works it out:

1. Every hour it records the balance and spend rate in a data table.
2. Spend for the month = the sum of every **drop** in balance between readings. Jumps up are refills and are ignored.
3. **Over budget:** alert (urgent) once spend passes $50.
4. **On pace to go over:** after the third day of the month, alert if spend so far, projected to the end of the month, is over budget.
5. **Runaway:** alert (urgent) if the last two hourly readings both show more than $0.50 an hour, with the daily cost at that rate, because that usually means something was left running.

## Design decisions

- **Alert once per problem, not once per check.** Each alert has a de-duplication key (for example "over budget, this month" or "runaway, today") and goes into an alert log table with `INSERT ... ON CONFLICT DO NOTHING`. Only a row that was actually inserted sends a push. An hourly check never becomes an hourly nag.
- **Phone first, Discord as backup.** Alerts go to my phone through my assistant's alert workflow; if that fails, they post to a Discord alerts channel instead.
- **Read the units.** The AI provider's cost report returns amounts in **cents**. Treating them as dollars would overstate the bill a hundredfold, so the watch converts, and the note is written down where the next person will look.
- **Autopay is not "paid".** Bills on autopay roll forward to the next due date on their own, but they still show in the countdown, so I see what is about to leave the account.
- **Feeds the dashboard.** The watches also write summaries that the [Mission Control](../mission-control/README.md) page shows as gauges, so I can see where I stand without waiting for an alert.

## Stack

n8n (schedules, HTTP, data tables, code nodes), PostgreSQL alert log, the providers' usage APIs, phone push via Home Assistant, Discord.
