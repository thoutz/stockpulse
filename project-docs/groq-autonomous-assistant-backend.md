# Groq Autonomous Assistant Backend

**Date:** June 4, 2026

## Overview

StockPulse now uses a **FastAPI backend** on `45.63.64.79` that:

- Ingests **Massive.com** data (daily bars, minute aggregates, RSI, SMA) within the free-tier **5 calls/minute** budget
- Runs **Groq** (`llama-3.3-70b-versatile`) on a schedule for reports, suggestions, and movement alerts
- Persists everything in **PostgreSQL** (`stockpulse` database)
- Exposes a **HTTPS API** for the iOS app (keys stay on the server)

Public base URL: **`https://api.tryan.app`**

## Architecture

```
iOS StockPulse
  → https://api.tryan.app/api/*
       → Nginx → uvicorn :8002
            → PostgreSQL
            → Massive API (scheduled ingest)
            → Groq API (scheduled + chat)
```

## Server setup

| Item | Value |
|------|--------|
| Host | `45.63.64.79` (SSH: `mspclientpro`) |
| App path | `/opt/stockpulse-api` |
| systemd | `stockpulse-api.service` |
| Port | `127.0.0.1:8002` |
| Nginx | `api.tryan.app` vhost → port 8002 |
| Database | PostgreSQL 14, db `stockpulse`, user `stockpulse` |
| Secrets | `/opt/stockpulse-api/.env` (chmod 600) |

### Deploy from Mac

```bash
cd "stock market app"
rsync -avz --exclude venv --exclude __pycache__ server/stockpulse-api/ mspclientpro:/opt/stockpulse-api/
ssh mspclientpro 'systemctl restart stockpulse-api'
```

### Local source

Repo path: [`server/stockpulse-api/`](../server/stockpulse-api/)

## Server-only market data (June 4, 2026 update)

The iPhone **never** calls Massive when `STOCKPULSE_API_BASE_URL` is set.

| Layer | Behavior |
|-------|----------|
| Server Postgres | Hot **30d** bars for all tickers; **90d** for ripple/catalyst set |
| Server ingest | Incremental daily append when data exists; full 90d backfill only when empty |
| iOS launch | Instant paint from `MarketDataCache` (`last_dashboard.json`) |
| iOS refresh | Single `GET /api/dashboard` (snapshots + histories + ripple_results) |
| iOS polling | `lightRefresh()` every 60s — full dashboard only every 5 min |

Config: leave `MASSIVE_API_KEY` and `GROQ_API_KEY` blank in `ios/Config.xcconfig`; server holds keys.

## API endpoints

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/api/health` | Health check |
| GET | `/api/dashboard` | **Primary** — bundled snapshots, 30d/90d histories, ripple results |
| GET | `/api/data-status` | Per-ticker bar counts / last date (debug) |
| GET | `/api/snapshot` | Latest per-ticker snapshots |
| GET | `/api/histories?tickers=...` | Bulk daily history |
| GET | `/api/history/{symbol}` | Single ticker history |
| GET | `/api/minute/{symbol}` | Minute bars |
| GET | `/api/indicators/{symbol}` | RSI / SMA rows |
| GET | `/api/ai/reports` | Automated Groq reports |
| GET | `/api/ai/suggestions` | Per-ticker suggestions |
| GET | `/api/ai/alerts` | Movement alerts (>3% 1D) |
| POST | `/api/ai/chat` | Full-context Groq Q&A |

## Scheduled jobs (APScheduler)

| Job | Cadence |
|-----|---------|
| Massive ingest | Every **12s** (~5 calls/min rotating daily/minute/RSI/SMA) |
| Movement alerts | Every **5 min** |
| Morning pulse report | **06:30** cron |
| Market pulse report | Every **30 min** |
| Suggestions | Every **15 min** |
| AI digest | Every **30 min** (market hours) |

## Database tables

- `tickers`, `bars_daily`, `bars_minute`, `indicators`, `snapshots`
- `ai_reports`, `ai_suggestions`, `ai_alerts`

## iOS changes

| File | Change |
|------|--------|
| `StockPulseAPIService.swift` | New — server HTTP client |
| `AssistantFeedView.swift` | New — reports / suggestions / alerts feed on AI tab |
| `StockPulseViewModel.swift` | Server-first refresh + chat; 60s auto-refresh |
| `RootView.swift` | Auto-refresh loop while app open |
| `AIAnalystView.swift` | Assistant feed + pull-to-refresh |
| `RippleTrackerView.swift` | AI suggestion overlay on chart |
| `BackgroundReportTask.swift` | Uses server data + server alert lines in local notification |
| `Config.xcconfig` | `STOCKPULSE_API_BASE_URL = "https://api.tryan.app"` (quoted) |

Regenerate Xcode project after config changes:

```bash
cd ios && xcodegen generate
```

## Push notifications (deferred)

- **Now:** Alerts and reports appear in the **Assistant Feed** (in-app). Morning background task sends **local notifications** with ripple verdicts + top server alerts.
- **Later (APNs):** Requires Apple Developer Program + auth key + server-side push to device tokens. Document when ready.

## Security notes

- `MASSIVE_API_KEY` and `GROQ_API_KEY` live only in server `.env`.
- iOS can omit Groq/Massive keys when `STOCKPULSE_API_BASE_URL` is set (local keys remain as fallback).

## Free-tier Massive expectations

- Data is **end-of-day / delayed**, not live streaming.
- Ingest rotates through tickers using the **5 calls/minute** rate limit.
- Groq outputs are **analysis and suggestions**, not guaranteed price predictions.
