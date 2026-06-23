# Daily AV Bundle + Massive Session Stats

**Date:** June 10, 2026

## Goal

Enrich Groq pulse reports without blowing the token budget:
- **Open / midday:** Massive intraday stats + observations + rolling news
- **Close (4 PM ET):** Massive full-day stats **plus** once-daily Alpha Vantage bundle

## Alpha Vantage daily bundle (~6 API calls/day)

Scheduled **15:45 ET** (15 min before close pulse). Also runs immediately before `pulse_close` if missing.

| Call | Endpoint | Stored as |
|------|----------|-----------|
| 1 | `EARNINGS_CALENDAR` | Upcoming earnings for tracked tickers (30d) |
| 2 | `TOP_GAINERS_LOSERS` | US market breadth (top 3 each) |
| 3–6 | `OVERVIEW` × up to 4 | P/E, EPS, sector, 52wk range (NVDA, RKLB priority + rotation) |

**0 API calls:** 24h news sentiment aggregate computed from `news_items` in Postgres.

Table: `av_daily_bundles` (one row per ET session date).

## Massive session stats (0 API calls)

Computed in `market_stats.py` for every pulse:
- Opening gap % (minute open vs prior daily close)
- Volume vs 20-day average
- Sector group averages (Chips/AI, Space, EV/Tech)

## Groq packet layout

| Section | Open | Midday | Close |
|---------|------|--------|-------|
| Snapshots | ✓ | ✓ | ✓ |
| Intraday stats (Massive) | ✓ | ✓ | ✓ |
| Observations since last pulse | ✓ | ✓ | ✓ |
| News headlines | ✓ | ✓ | ✓ |
| 30D trends + ripples | ✓ | ✓ | ✓ |
| **AV daily bundle** | | | **✓** |

## Files

- `services/alphavantage_client.py` — earnings, breadth, overview
- `services/daily_av_ingest.py` — bundle job + `ensure_daily_av_bundle()`
- `services/market_stats.py` — gap/volume/sector from Massive bars
- `services/analysis_packet.py` — close slot injects AV bundle
- `models/db_models.py` — `AVDailyBundle`, `NewsItem.sentiment_score`

## Deploy

```bash
rsync -avz --exclude venv --exclude .venv --exclude __pycache__ server/stockpulse-api/ mspclientpro:/opt/stockpulse-api/
ssh mspclientpro 'systemctl restart stockpulse-api'
```

Manual test on server:

```bash
cd /opt/stockpulse-api && source venv/bin/activate
python -c "import asyncio; from database import init_db, SessionLocal; from services.daily_av_ingest import ingest_daily_av_bundle; asyncio.run(init_db()); asyncio.run((lambda: __import__('asyncio').get_event_loop().run_until_complete(_t()))())" 
# Or simpler one-liner via run_daily_av_ingest_job
```
