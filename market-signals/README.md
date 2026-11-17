# Rules-based market scanner with paper trading

A small Python service that scans a crypto watchlist and a list of large US stocks once a day, scores each one with fixed rules, and posts the result to a private Discord server, one channel per asset. n8n runs it on a schedule. It also keeps a simulated (paper) trading ledger so the rules can be judged on results instead of on how convincing they sound.

**It does not give advice and it does not trade real money.** The only broker link is a paper account, and the code refuses any other endpoint. Everything here is redacted: no addresses, hostnames, IDs, keys or account details.

## What it does

- **Daily scan.** For each asset it pulls recent candles on several timeframes, scores trend and momentum, adds headline sentiment and (for crypto) chain health and derivatives positioning, and returns LONG, SHORT or NO TRADE with an entry, a stop, two targets and a position size. NO TRADE is a normal answer: on the first full run, none of 20 coins qualified.
- **Market regime.** A risk-off market raises the bar for longs. Stocks use the S&P 500 trend as their regime; crypto uses breadth, dominance and stablecoin supply.
- **Catalyst tracker.** Pulls dated upcoming events out of news headlines (rulings, unlocks, launches, earnings) and posts countdowns, so slow events are not forgotten. Headline-derived, so the dates are treated as approximate.
- **Add a stock by typing it.** A command channel takes a ticker or company name; the bot creates a channel and starts covering it.
- **Paper trading.** After each scan, qualifying signals open simulated positions with fees and slippage, a total exposure cap, a per-position cap, a time stop and a drawdown halt. Trades are mirrored to a broker's paper account (stocks as bracket orders; crypto as a buy plus a protective stop, reconciled to the ledger after each scan because the paper crypto API has no bracket orders). A review posts after a week. Nothing ever switches to live.

## How it fits together

```
n8n (4 schedules) --HTTP + API key--> scanner service (Python, systemd)
                                         |-> public market and news APIs
                                         |-> Discord bot (one channel per asset)
                                         |-> event webhook --> n8n --> data table
```

The house pattern for this lab: n8n never shells out. It calls small HTTP services that each need their own key, so the scheduler and the logic can be changed separately.

## Design decisions

- **Rules over opinions.** I was asked for "the best coins and entry points". That is personal financial advice, so I built descriptive tools instead: a ranking with a robustness test (the watchlist had to stay stable across 300 different weightings of the scoring factors), drawdown analogs, and sizing presets. The output says what the rules see, not what to do.
- **Event risk only ever shrinks a position.** If a dated event is within three days, a position whose direction matches the news tone keeps its size and anything else is halved. It is never increased: a gap can jump straight past a stop, so a bigger position makes the worst case worse. The rule prints in every summary.
- **Watchlist changes are proposals.** A weekly re-rank posts suggested swaps; nothing changes until someone applies it on purpose, and the old config is saved first.
- **Only documented data sources.** An attempt to scrape a finance site that required browser-style tricks was dropped. Stocks use a provider with a free API key.
- **A data budget the service enforces itself.** The stock data plan allows 800 calls a day. The service checks usage before each scan, trims the scan near the limit, alerts at 70% and 90%, and caches candles for 25 minutes so a failed run does not spend the budget twice.
- **Quiet by default.** Only the two daily summaries notify. Every other post is sent with Discord's suppress-notifications flag, set in one function, so it works regardless of anyone's client settings.
- **Spot crypto is long-only.** You cannot short spot crypto and I did not want derivatives, so crypto shorts were removed from the ledger and the trial clock restarted. Stock shorts stay on under the exposure cap.

## Problems testing caught

- **A root-owned file broke the first stock scan.** A test run as root left a file in the service's state folder that the service user could not write. Lesson: never test as root in a service's own data folder.
- **Never restart mid-scan.** The deploy script checks the service's status endpoint and refuses to restart while a scan is running.
- **A truncated headline date** ("Nov 2...") was read as November 2027. The catalyst tracker is marked v1 and reviewed after a week.
- **The first install landed on the wrong server.** It was removed, the removal was verified, and it was reinstalled next to the scheduler that calls it, so the webhook can stay on localhost.

## Stack

Python 3, systemd, n8n, Discord bot API, public market and news APIs, a broker's paper-trading API.
