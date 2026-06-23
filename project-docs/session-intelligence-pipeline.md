# Session Intelligence Pipeline

**Date:** June 13, 2026

## Summary

Implemented persisted **session intelligence** that feeds the three daily Groq pulse reports (open 10:00 / midday 13:00 / close 16:00 ET) and a new reporting API. Quote ticks are now stored in Postgres so 5m/15m intraday windows survive server restarts.

## Problem

Monitor tiers (Hot/Warm/Cold) and Finnhub quotes produced rich intraday fields (`change_5m_pct`, `change_15m_pct`) on `snapshots`, but `build_pulse_analysis_packet` only sent Groq **1D% and 30D%**. Pre-pulse analytics were rebuilt ephemerally with no audit trail or future API.

## Solution

### New database tables

| Table | Purpose |
|-------|---------|
| `quote_ticks` | Finnhub price ticks (24h retention) for 5m/15m window recovery |
| `session_intelligence` | Pre-computed rows per session date + pulse slot |

### New modules

| File | Role |
|------|------|
| `services/quote_history.py` | In-memory deque + DB persist/load/prune |
| `services/session_intelligence.py` | Build intelligence rows; format for pulse packet |
| `routers/intelligence.py` | `GET /api/intelligence/session/{date}` and `/{slot}` |
| `scripts/backfill_quote_windows.py` | Recompute snapshot 5m/15m from stored ticks after deploy |

### Scheduler (ET)

| Job ID | Time | Action |
|--------|------|--------|
| `intel_open` | 09:55 | `run_pre_pulse_intelligence("open")` |
| `intel_midday` | 12:55 | `run_pre_pulse_intelligence("midday")` |
| `intel_close` | 15:55 | `run_pre_pulse_intelligence("close")` |
| `pulse_*` | 10:00 / 13:00 / 16:00 | Groq reports (unchanged) |

On startup: `load_quote_history_from_db()` restores quote deques.

If a pulse runs without pre-computed rows, `run_pulse_report` builds intelligence on the fly.

### Intelligence row categories

- `focus` — monitor sector focus + HOT tickers
- `tier_summary` — HOT/WARM/COLD counts
- `sector_breadth` — focused sector 1D breadth
- `intraday_mover` — top 5m/15m movers in HOT/WARM tiers
- `observation_digest` — market_observations since session window
- `observation` — individual observation lines
- `ripple` — CONFIRMED/FORMING ripple pairs
- `data_quality` — stale HOT quotes (close slot only)

### Pulse packet changes (`analysis_packet.py`)

New sections in Groq context:

1. **SESSION INTELLIGENCE** — pre-computed rows for the slot
2. **MONITOR FOCUS** — focused sector name/id
3. **TICKER SNAPSHOTS (tier-aware)** — includes tier label, 5m%, 15m%, quote source

Updated system prompt references Finnhub intraday + Monitor tiers.

## API reference

```
GET /api/intelligence/session/2026-06-13
GET /api/intelligence/session/2026-06-13/open
GET /api/intelligence/session/2026-06-13/midday
GET /api/intelligence/session/2026-06-13/close
```

Response shape:

```json
{
  "session_date": "2026-06-13",
  "slot": "open",
  "count": 12,
  "rows": [
    {
      "category": "intraday_mover",
      "symbol": "NVDA",
      "tier": "hot",
      "metric_key": "change_5m_pct",
      "metric_value": 2.4,
      "summary_text": "NVDA [hot]: 5m +2.4%, ..."
    }
  ]
}
```

## Deploy

1. Rsync / restart `stockpulse-api` (tables auto-create via `init_db`)
2. Optional after restart: `python scripts/backfill_quote_windows.py`
3. Verify: `curl https://api.tryan.app/api/intelligence/session/$(date +%Y-%m-%d)/open`

## Files changed

- `models/db_models.py` — `QuoteTick`, `SessionIntelligence`
- `services/quote_scheduler.py` — uses `quote_history`
- `services/analysis_packet.py` — tier + intelligence enrichment
- `services/ai_jobs.py` — fallback intelligence build before pulse
- `main.py` — startup load, pre-pulse cron jobs, intelligence router
