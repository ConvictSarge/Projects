# A spoken morning recap from my self-hosted assistant

Every morning at 7:30 my assistant sends me one Discord message with two short voice clips and the same text underneath: a personal brief in one voice and a business line in another, plus anything that alerted overnight. It replaced a 6:30 weekday announcement played through Home Assistant, so the recap now reaches me wherever I am, every day. Everything is redacted: no addresses, IDs, tokens or personal details.

## How it works

```
n8n schedule (7:27)
  -> ask the assistant for today's brief
  -> ask the business manager for one line     (what needs attention today)
  -> collect alert titles from the last 24 h   (from the alert log table)
  -> text-to-speech, two voices                (Home Assistant + Piper, runs locally)
  -> one Discord DM: voice clip 1 + voice clip 2 + the full text
       if the upload fails -> send the text only
```

## Design decisions

- **Local speech, no cloud TTS.** Home Assistant runs Piper, a small offline text-to-speech engine. n8n asks Home Assistant for an audio URL, downloads the clip and attaches it. Nothing about my day goes to a speech API.
- **Two voices on purpose.** The personal assistant and the business manager have different voices, so I know which part I'm hearing without looking.
- **Same prompts as before.** The text comes from the same prompts the old morning brief used, so moving it from the speaker to Discord changed the delivery, not the content.
- **The overnight alerts come from one table.** Every watch that can alert me (bills, budgets, credit balances) writes to one alert log with a de-duplication key, so the recap lists each problem once, not once per check.
- **Fails soft.** If the audio upload fails, the text still goes out. A recap that sometimes arrives without sound is fine; one that sometimes doesn't arrive is not.
- **One message, not three.** It is a single DM with both clips attached, so my phone buzzes once.

## Stack

n8n, an LLM for the brief text, Home Assistant with Piper TTS, PostgreSQL alert log, Discord bot API.
