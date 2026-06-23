# Hybrid Ticker Search + Seeded Universe

**Date:** June 9, 2026

## Overview

Implemented the optional enhancement from the Stock Search plan:

1. **Seeded ticker universe** — S&P 500, NASDAQ-100, and Dow 30 constituents loaded into Postgres `tickers` table
2. **Hybrid search** — `GET /api/search` queries Postgres first, falls back to Massive when fewer than 5 local matches

No iOS changes required; Watchlist search continues to call `/api/search`.

## Verification

| Check | Result |
|-------|--------|
| Production `https://api.tryan.app/api/search?q=apple` | Unreachable from dev sandbox (connection reset) |
| Local Postgres + seeded tickers | 527 tickers loaded |
| `scripts/verify_search.py` | Passed — local + hybrid return `AAPL` for `apple` |
| Local `GET /api/search?q=apple` | `200 OK` → `[{"symbol":"AAPL","name":"Apple Inc."}]` |
| Massive fallback without API key | Local results returned when Massive returns 401 |

## Server changes

### Schema (`models/db_models.py`)

Added optional columns on `tickers`:

- `exchange` — e.g. `NASDAQ`, `NYSE`
- `index_tag` — e.g. `SP500`, `NDX100`, `DJIA` (comma-separated when symbol appears in multiple indices)

`init_db()` runs `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` for existing deployments.

### New files

| File | Purpose |
|------|---------|
| `services/ticker_search.py` | `search_tickers_local()`, `hybrid_search_tickers()` |
| `scripts/seed_tickers.py` | Fetch S&P 500 + NASDAQ-100 CSVs, merge Dow 30, upsert to Postgres |
| `scripts/verify_search.py` | Local verification script |

### Updated files

| File | Change |
|------|--------|
| `routers/data.py` | `GET /api/search` uses `hybrid_search_tickers(db, q)` |
| `database.py` | Schema migration for new ticker columns |

## Hybrid search logic

```
1. Query Postgres: symbol ILIKE '{q}%' OR name ILIKE '%{q}%' LIMIT 15
2. If >= 5 local results → return local only (no Massive call)
3. Else call Massive /v3/reference/tickers, merge + dedupe
4. If Massive fails but local has matches → return local
```

## Seeding tickers (production)

After deploy, run once on the server:

```bash
cd /opt/stockpulse-api
source venv/bin/activate
python scripts/seed_tickers.py
```

Data sources (public CSV, no API key):

- S&P 500: `datasets/s-and-p-500-companies` GitHub CSV
- NASDAQ-100: `mhyavas/SP500-NASDAQ100` GitHub CSV
- Dow 30: static list in `seed_tickers.py`

Optional offline fallback: `data/ticker_universe.json` (used only if both CSV fetches fail).

## Deploy

```bash
cd "stock market app"
rsync -avz --exclude venv --exclude .venv --exclude __pycache__ server/stockpulse-api/ mspclientpro:/opt/stockpulse-api/
ssh mspclientpro 'cd /opt/stockpulse-api && source venv/bin/activate && python scripts/seed_tickers.py && systemctl restart stockpulse-api'
```

## iOS behavior

Unchanged. Watchlist tab → `performSearch()` → `GET /api/search` → tap + → `POST /api/favorites` → backfill → dashboard refresh.

After seeding, popular symbols (AAPL, NVDA, MSFT, etc.) resolve instantly from Postgres even if Massive is rate-limited or temporarily unavailable.
