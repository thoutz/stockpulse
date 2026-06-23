# Stock Search + Favorites (server-driven) + Groq

**Date:** June 4, 2026

## Overview

Added the ability to **search for any US stock**, **save it as a favorite**, and have the StockPulse server **ingest its Massive data** so the **server-side Groq analyst** can analyze it alongside the existing watchlist.

Because Groq now runs entirely on the FastAPI server (`45.63.64.79` / `https://api.tryan.app`) over the Postgres data, favorites had to be tracked **server-side** rather than only on the device — a local-only favorite would be invisible to the AI. The feature is therefore server-driven; the iOS app is a thin client.

This is a single-user implementation (no auth): favorites are one shared set. Per-user favorites can be added later with authentication.

## Data flow

```
Watchlist search field
  -> GET /api/search?q=...            (server -> Massive /v3/reference/tickers)
  -> POST /api/favorites {symbol}     (insert favorite + immediate daily backfill)
       -> favorites table
       -> tracked symbols = config tickers + favorites
            -> 12s ingest loop -> Postgres bars/snapshots
            -> GET /api/dashboard (now returns `favorites` + favorite histories)
            -> server Groq context (labels USER FAVORITES)
```

## Server changes (`server/stockpulse-api/`)

### New / changed files

| File | Change |
|------|--------|
| `services/massive_client.py` | Added `search_tickers(query)` -> `GET /v3/reference/tickers?search=&active=true&market=stocks&limit=15`. Returns `[{symbol, name}]`. |
| `models/db_models.py` | Added `Favorite` table (`symbol` PK, `name`, `created_at`). Created automatically by `create_all` (no migration). |
| `services/tracked.py` | New. `get_tracked_symbols(session)` = `settings.ticker_list` ∪ favorites (deduped, upper-cased). |
| `routers/data.py` | Added `GET /api/search`, `GET/POST/DELETE /api/favorites`. POST upserts `Favorite` + `Ticker(active=True)` and schedules an immediate `ingest_scheduler._ingest_daily_only(symbol)` via `BackgroundTasks` so data lands in seconds. |
| `services/ingest.py` | `run_cycle` and `full_refresh` now read tracked symbols from the DB each cycle instead of the static config list. |
| `services/dashboard_build.py` | `build_dashboard` + `build_data_status` iterate tracked symbols; dashboard payload now includes a `favorites` array. |
| `services/ai_context.py` | Adds a `=== USER FAVORITES ===` section so Groq prioritizes user-added tickers (their bars/snapshots already flowed in automatically). |

### Endpoints added

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/api/search?q=` | Massive symbol/name lookup |
| GET | `/api/favorites` | List favorites |
| POST | `/api/favorites` | Add favorite (`{"symbol","name"}`) + immediate backfill |
| DELETE | `/api/favorites/{symbol}` | Remove favorite |

### Deploy

```bash
cd "stock market app"
rsync -avz --exclude venv --exclude __pycache__ server/stockpulse-api/ mspclientpro:/opt/stockpulse-api/
ssh mspclientpro 'systemctl restart stockpulse-api'
```

Note: the lifespan warm-up (`full_refresh`) blocks startup ~60s (one 60s sleep between rate-limited batches), so expect ~60-90s of 502 right after a restart before the API serves. The new `favorites` table is created on startup by `init_db()`.

### Verification (run after deploy)

```
GET  /api/search?q=apple            -> [{"symbol":"AAPL","name":"Apple Inc."}, ...]
POST /api/favorites {"symbol":"AAPL","name":"Apple Inc."} -> {"symbol":"AAPL",...}
GET  /api/favorites                 -> [{"symbol":"AAPL",...}]
GET  /api/dashboard                 -> favorites:["AAPL"], AAPL present in histories (backfilled within seconds)
DELETE /api/favorites/AAPL          -> {"removed":"AAPL"}
```

All verified on June 4, 2026. (The `/api/ai/chat` call can intermittently 500 due to Groq's own free-tier 429 rate limit — unrelated to this feature.)

## iOS changes (`ios/StockPulse/`)

| File | Change |
|------|--------|
| `Services/StockPulseAPIService.swift` | Added `APITickerSearchResult`, `APIFavorite`; methods `searchTickers`, `favorites`, `addFavorite`, `removeFavorite`. `APIDashboard` gains `favorites: [String]` with a custom decoder so older cached payloads (without the field) still decode. |
| `ViewModels/StockPulseViewModel.swift` | Added `searchQuery`, `searchResults`, `searchLoading`, `searchError`, `favoriteSymbols`; `performSearch()` (300ms debounce, cancels in-flight), `addFavorite/removeFavorite` (call server then `refresh()`), `isFavorite(_:)`. `applyDashboard` sets `favoriteSymbols` and builds `watchItems` from `watchlistTickers ∪ favorites`. |
| `Views/Watchlist/WatchlistView.swift` | Added `SearchField`, `SearchResultsList`, `SearchResultRow`. `WatchRow` shows a star for favorites. `WatchDetailBanner` gains a "Remove from favorites" button for favorited tickers. |

The Ripple ("dashboard") tab was intentionally left untouched per project styling rules. The Watchlist tab reuses the existing `DS` design tokens — no new design system changes.

### UI / style notes (Watchlist tab only)

- Search field: `DS.Color.surface2` rounded container (`DS.Radius.md`), magnifying-glass icon, `DS.Font.mono(13)` input, character autocapitalization, clear (`xmark.circle.fill`) button, inline `ProgressView` while loading.
- Search result row: symbol in `DS.Font.mono(14, .bold)`, company name in `DS.Font.sans(11)` muted; trailing `plus.circle` (blue) -> `checkmark.circle.fill` (green, disabled) once favorited.
- Watch row favorite marker: `star.fill` in `DS.Color.orange` before the ticker.
- Remove control: full-width button in the detail banner, `star.slash` + red tint.

### Build

```bash
cd ios && xcodebuild -project StockPulse.xcodeproj -scheme StockPulse \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build
```

`** BUILD SUCCEEDED **` on June 4, 2026. No `xcodegen generate` needed (no `project.yml`/config changes; only existing-target source edits).

## Behavior summary

- Type in the Watchlist search field -> debounced server search across all US tickers.
- Tap `+` -> server saves the favorite, backfills its daily bars immediately, and the watchlist refreshes to show it with a star.
- The favorite now flows into `/api/dashboard` and the Groq context automatically; the AI tab can answer questions about it and prioritizes favorites on open-ended prompts.
- Open a favorited row -> "Remove from favorites" stops tracking it (historical bars are retained server-side).

## Notes / limitations

- No auth: favorites are a single shared set. Per-user favorites need authentication (future).
- Search uses the Polygon-compatible `/v3/reference/tickers`; adjust `MassiveClient.search_tickers` if Massive's plan changes the path.
- Each favorite adds one symbol to the 5-calls/min ingest rotation; the on-add single-ticker backfill keeps the UX responsive without exceeding the rate limit.
- The on-device direct-Massive `MarketDataService` path remains only as the local-dev fallback; this feature targets the server path.
