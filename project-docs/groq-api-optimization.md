# Groq API Optimization Implementation

**Date:** June 9, 2026

## Problem

Groq free tier (100k TPD) was exhausted by ~16 successful calls. Root cause: `run_suggestions` fired 5 full-context Groq calls every 15 minutes (~480/day), plus `run_ai_insight_alert` every 30 minutes.

## Architecture: Two-Tier Data Model

### Tier 1 — Continuous observation (no Groq)

| Job | Cadence | Purpose |
|-----|---------|---------|
| `run_movement_alerts` | 10 min | 5% daily swings, 2% velocity, 4h dedupe → `ai_alerts` + `market_observations` |
| `run_session_tracker_job` | 10 min | Intraday velocity, RSI crosses, ripple verdict changes |
| `run_news_ingest_job` | 15 min | Finnhub headlines → `news_items` |
| `run_snapshot_suggestions` | 60 min | Rule-based bias from snapshots → `ai_suggestions` |

### Tier 2 — AI synthesis (Groq)

| Job | Cadence | Context |
|-----|---------|---------|
| `pulse_open` | 10:00 ET | `build_pulse_analysis_packet()` |
| `pulse_midday` | 13:00 ET | Same + observations since last pulse |
| `pulse_close` | 16:00 ET | Full-day arc |
| `POST /api/ai/chat` | On demand | `build_chat_context()`, max 10/day |

## Server Changes

### New files

- `services/groq_budget.py` — daily token + Q&A counters, 85k TPD soft cap
- `services/analysis_packet.py` — curated pulse/chat context (snapshots, observations, news, trends, ripples)
- `services/finnhub_client.py` — company news fetch
- `services/session_tracker.py` — intraday event detection + news rotation

### Removed Groq usage

- `run_suggestions` Groq loop (replaced with rule-based `run_snapshot_suggestions`)
- `run_ai_insight_alert` Groq digest (no-op)
- iOS market brief no longer calls `/api/ai/chat` when server API configured

### New DB tables

- `market_observations` — structured intraday events between pulses
- `news_items` — Finnhub headlines (dedupe by URL)

### Config (`.env`)

```
FINNHUB_API_KEY=          # optional
ALPHAVANTAGE_API_KEY=     # optional — used in preference to Finnhub
ALERT_THRESHOLD_PCT=5.0
ALERT_VELOCITY_PCT=2.0
ALERT_COOLDOWN_HOURS=4.0
GROQ_DAILY_TOKEN_BUDGET=85000
GROQ_CHAT_DAILY_LIMIT=10
```

### New endpoint

- `GET /api/ai/groq-usage` — token and Q&A budget status

### Groq client

- Global lock serializes calls
- TPD limit: fail fast (no 5× retry storm)
- Records token usage from API response

## iOS Changes

### `StockPulseViewModel.swift`

- `marketBriefCacheTTL`: 4h → **24h**
- Server mode: market brief from `pulse_open` (fallback: any pulse, then cache)
- No Groq call on market tab refresh

### `BackgroundReportTask.swift`

- Morning notification uses server `pulse_open` report instead of Groq chat

## Deploy

```bash
# Add FINNHUB_API_KEY to server .env
rsync -avz --exclude venv --exclude .venv --exclude __pycache__ \
  "server/stockpulse-api/" mspclientpro:/opt/stockpulse-api/
ssh mspclientpro 'systemctl restart stockpulse-api'
```

Tables are created automatically on startup via `init_db()`.

## Expected Daily Groq Usage

| Use | Calls | ~Tokens |
|-----|-------|---------|
| Pulse reports | 3 | ~10,500 |
| User Q&A | ≤10 | ~15,000 |
| **Total** | **≤13** | **~25,000** |

## Verification

1. `curl https://your-api/api/ai/groq-usage`
2. Confirm no `/api/ai/chat` in logs when opening Market tab
3. Watch Groq console — should stay well under 100k TPD
