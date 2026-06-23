# Ticker Name Refresh Scheduler

**Date:** June 12, 2026

## Goal

Keep `tickers.name` current for every tracked symbol so the watchlist/search show real company names and newly listed IPOs (e.g. **SpaceX / `SPCX`**, plus more summer IPOs) get named automatically once tracked. Previously `Ticker.name` was `NULL` for all base tickers because ingest only upserted `symbol`.

## Key constraint

The Massive free tier allows **5 calls/min**, and the 12s ingest loop already consumes that entire budget. A *separate* name-fetch job would collide and trigger HTTP 429s. The solution uses a **single rate governor**: name resolution is folded into the existing ingest cycle (one lookup per tick), so the combined Massive call rate never exceeds 5/min.

## How it works

```
12h interval job  ->  request_full_name_resync()  ->  fills _name_resync_queue (all tracked)
startup (+30s)    ->  request_full_name_resync()
                          |
ingest run_cycle (every 12s, after warm-up):
   1. if resync queue has a symbol  -> resolve its name (1 Massive call), return
   2. else if any tracked name NULL -> resolve it (1 Massive call), return
   3. else                          -> normal bar/indicator ingest
```

- Names drain one-per-tick (~12s), so 10 symbols resolve in ~2 min, fully within budget. Verified in logs: no 429s.
- Favorites added from the app already carry a client-provided name, so they are named **instantly** on `POST /api/favorites` with **zero** Massive calls.
- Unknown symbols (404 / no name) are added to an in-memory `_name_skip` set so they are not retried every tick; the 12h full resync clears it and retries.

## Changes (`server/stockpulse-api/`)

| File | Change |
|------|--------|
| `services/massive_client.py` | Added `fetch_ticker_details(symbol)` -> `GET /v3/reference/tickers/{symbol}`; returns `{name, exchange}`, `None` on 404/no-name, raises on transient errors. |
| `services/ingest.py` | `IngestScheduler` gains `_name_resync_queue`, `_name_skip`; new `_pick_name_to_resolve`, `_ingest_name`, `request_full_name_resync`. `run_cycle` resolves one missing/queued name per tick (after warm-up) before normal ingest, updating `Ticker.name`/`exchange` and backfilling `Favorite.name`. |
| `routers/data.py` | `POST /api/favorites` now sets `Ticker.name` from the client-provided name (on-conflict update) so favorited IPOs are named immediately. |
| `main.py` | Registered `name_resync` job (`interval`, every 12h) and a one-shot full resync ~30s after startup in the background catch-up task. |

No new tables or migrations: `Ticker` already had `name`/`exchange` columns.

## Deploy

```bash
cd "stock market app"
rsync -avz --exclude '.venv' --exclude venv --exclude __pycache__ --exclude '*.pyc' --exclude '.env' \
  server/stockpulse-api/ mspclientpro:/opt/stockpulse-api/
ssh mspclientpro 'systemctl restart stockpulse-api'
```

(Restart has the usual ~60-90s warm-up before the API serves; name resolution begins after warm-up.)

## Verification (June 12, 2026)

- `GET /api/tickers` -> all base names populated: e.g. `NVDA` -> "Nvidia Corp", `RKLB` -> "Rocket Lab Corporation Common Stock", `ASTS` -> "AST SpaceMobile, Inc. Class A Common Stock".
- `POST /api/favorites {"symbol":"SPCX","name":"Space Exploration Technologies Corp. Class A Common Stock"}` -> SpaceX is now tracked and named immediately; bars backfill in the background.
- `GET /api/search?q=rocket` -> returns `RKLB` by **company name** (local name search now works because names are populated).
- Logs show `Queued full ticker-name resync for 10 symbols` then `Resolved name for ...` one per ~12s, with no rate-limit errors.

## Notes

- SpaceX trades as **`SPCX`** ("Space Exploration Technologies Corp."). Note Massive's `search` matches by symbol, not the word "spacex", so name population + local name search is what makes it findable by company name.
- New IPOs this summer: add them as favorites (search by symbol, tap +). They are named instantly and tracked; the 12h resync also keeps existing names fresh in case of renames/exchange changes.
- To force a name refresh sooner than 12h, restart the service (startup enqueues a full resync) — but mind the warm-up downtime.
