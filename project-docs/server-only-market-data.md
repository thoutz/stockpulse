# Server-Only Market Data

**Date:** June 4, 2026

## Problem solved

- iPhone was slow (~1–2 min) and hit Massive **rate limits** because it fell back to on-device `MarketDataService` and re-downloaded 90 days every launch and every 60 seconds.

## Solution

1. **Server** owns all Massive calls (5/min budget, incremental updates into Postgres).
2. **iPhone** reads one bundled endpoint and caches it locally.

## Server changes

- [`services/ingest.py`](../server/stockpulse-api/services/ingest.py) — incremental daily ingest; warm-up runs daily-only first; minute/RSI/SMA after `warm_complete`.
- [`services/dashboard_build.py`](../server/stockpulse-api/services/dashboard_build.py) — builds `/api/dashboard` payload.
- [`routers/data.py`](../server/stockpulse-api/routers/data.py) — `GET /api/dashboard`, `GET /api/data-status`.
- Config: `HOT_DAYS=30`, `FULL_DAYS=90`.

## iOS changes

- [`MarketDataCache.swift`](../ios/StockPulse/Services/MarketDataCache.swift) — disk cache for dashboard JSON.
- [`StockPulseViewModel.swift`](../ios/StockPulse/ViewModels/StockPulseViewModel.swift) — server-only when `STOCKPULSE_API_BASE_URL` set; no Massive fallback.
- [`RootView.swift`](../ios/StockPulse/App/RootView.swift) — `loadFromCacheIfAvailable()` then `refresh()`; `lightRefresh()` every 60s.
- [`Config.xcconfig`](../ios/Config.xcconfig) — `MASSIVE_API_KEY` cleared (optional for local dev only).

## Test

```bash
curl -s 'https://api.tryan.app/api/dashboard' | head -c 200
```

DNS: A record `api` → `45.63.64.79` on tryan.app. See [tryan-app-api-migration.md](tryan-app-api-migration.md).

**xcconfig:** Always quote URLs: `STOCKPULSE_API_BASE_URL = "https://api.tryan.app"` — unquoted `https://` is truncated at `//`.

Rebuild iOS:

```bash
cd ios && xcodegen generate && open StockPulse.xcodeproj
```

Expected: charts appear immediately from cache; status **SERVER** or **CACHED**; no Massive wait spinner.
