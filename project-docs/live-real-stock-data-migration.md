# Live real stock data migration

**Date:** June 3, 2026  
**Goal:** Replace fictional mock prices (SPCX, fixed May–Jun 2026 arrays) with Polygon live daily bars and a real-ticker catalyst catalog.

## What changed

### Data source

- **Removed:** [`ios/StockPulse/Data/MockDataStore.swift`](../ios/StockPulse/Data/MockDataStore.swift) (runtime mock prices and `dateIndex` events).
- **Added:** [`ios/StockPulse/Data/CatalystCatalog.swift`](../ios/StockPulse/Data/CatalystCatalog.swift)
  - Active catalysts: **NVDA** (earnings May 28, 2026), **RKLB** (earnings May 14, 2026) with space-sector ripples (ASTS, LUNR, HWM, RDW).
  - Watchlist: RKLB, TSLA, NVDA, ASTS, LUNR, HWM, RDW, AMD, AVGO (no SPCX until listed).
  - `futureTickers = ["SPCX"]` and `spacexPlaceholder` for when SpaceX lists.

### Models

- `Catalyst.eventDateIndex` → `eventDate: Date`
- `MarketEvent.dateIndex` → `date: Date`

### Services / VM

- [`RippleEngine`](../ios/StockPulse/Services/RippleEngine.swift): uses `catalyst.eventDate` with Polygon histories.
- [`StockPulseViewModel`](../ios/StockPulse/ViewModels/StockPulseViewModel.swift): catalog init, `refresh()` on launch (90-day bars), no mock fallback; `refreshError` when `POLYGON_API_KEY` missing.
- [`LiveDataBridge`](../ios/StockPulse/Services/LiveDataBridge.swift): `periodChangePct`, `sparklinePoints` helpers.
- [`AIAnalystService`](../ios/StockPulse/Services/AIAnalystService.swift): dynamic date range in context; Groq key guard.
- [`BackgroundReportTask`](../ios/StockPulse/Services/BackgroundReportTask.swift): uses `CatalystCatalog`.

### UI

- [`RootView`](../ios/StockPulse/App/RootView.swift): `.task { await vm.refresh() }` on launch.
- Header: **LIVE** / **OFFLINE**, dynamic **DATA THROUGH** from `lastRefreshed`.
- Ripple / Trends / Watchlist / AI: no `MockDataStore` references; charts and sparklines from `liveHistories`.
- AI sample prompts updated (NVDA / RKLB, not SPCX).

## API keys (required)

1. Copy `ios/Config.xcconfig.example` → `ios/Config.xcconfig` (gitignored).
2. Set:
   - `POLYGON_API_KEY` — live stock bars ([polygon.io](https://polygon.io))
   - `GROQ_API_KEY` — AI Analyst tab ([console.groq.com](https://console.groq.com))
3. Regenerate and build:

```bash
cd ios && xcodegen generate
open StockPulse.xcodeproj
```

Run on **iPhone Simulator or device**, not “My Mac (Designed for iPhone)”.

## When SpaceX (SPCX) lists

1. Add `SPCX` to `CatalystCatalog.watchlistTickers`.
2. Append `spacexPlaceholder` (or a copy with real `eventDate`) to `CatalystCatalog.catalysts`.
3. Rebuild — no engine changes needed.

## Verification

- Cold launch with keys: charts and ripple cards populate without pull-to-refresh.
- Pull-to-refresh still works (5 min Polygon cache in `MarketDataService`).
- Empty/missing Polygon key: banner text, OFFLINE status, no fake prices.
- AI tab: requires live data + `GROQ_API_KEY`.

## Out of scope (unchanged)

SwiftData, Supabase, WidgetKit, Live Activity, push alerts — see `STOCKPULSE_REWRITE_PLAN.md` Phase 4.
