# Self-hosted voice and chat assistant

A household assistant that answers by voice (Home Assistant Assist) and by chat (a Discord DM bot). It can read the calendar, manage tasks, search my notes, check the state of the house and read service logs. It is built around one rule: **every tool does one narrow thing, and the model never gets more access than that tool needs.**

## Capabilities

- **Calendar and tasks** over CalDAV: list, add, update and complete. There is no delete for tasks, and deleting an event needs an explicit confirmation. Every change is written to a change log.
- **Notes search:** read-only search and read over a mirrored copy of my notes. Notes are treated as information, never as instructions.
- **Home state:** search entities and read one entity, its history, or a summary of what's flagged. These use fixed templates, and the model only supplies a search word or entity ID, so it cannot run its own template code. Token and camera-URL attributes are stripped before the model sees them.
- **Service logs:** tail logs from an allowlist of services. Secrets are masked (bearer tokens, key=value pairs, long hex strings, passwords in URLs), and lines and output are length-capped. A redaction test caught a real token leak before deploy.
- **Proactive messages:** a "time to head out" reminder before events that have a location, a weekly summary of free time blocks, and a morning brief. Quiet hours apply, except for real outage alerts.
- **Model routing:** short requests go to a small, fast model, and planning or long requests go to a larger one.

## Access control

- Only my user gets the full assistant. Everyone else in the house gets a limited household mode.
- The chat bot accepts messages from a single user ID and ignores everyone else.
- Memory is kept in its own database role, and row-level security limits it to its own rows. That role has no DELETE permission.

## Stack

Home Assistant (Assist, Whisper speech-to-text, Piper text-to-speech, openWakeWord), n8n AI agent, a small Python tools service, Nextcloud CalDAV, PostgreSQL, Discord.
