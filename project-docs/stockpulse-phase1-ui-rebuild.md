# StockPulse Phase 1 UI Rebuild

Completed June 3, 2026 per [STOCKPULSE_REWRITE_PLAN.md](STOCKPULSE_REWRITE_PLAN.md) and [stockpulse-v2-reference.jsx](../ios/stockpulse-v2-reference.jsx).

## What was built

- New target: **StockPulse** (`ios/StockPulse.xcodeproj`, `ios/project.yml`)
- Design authority: `DS` tokens in `StockPulse/Utilities/DesignSystem.swift` (hex palette from JSX)
- Data: inline `MockDataStore.swift` — synchronous first-frame data, no JSON bundle
- Shell: `StockPulseApp` + `RootView` with `ZStack { DS.Color.bg }` + system `TabView`
- Fonts: IBM Plex Mono + DM Sans in `StockPulse/Resources/Fonts/` (converted from fontsource woff2)

## File map

| Area | Path |
|------|------|
| App | `StockPulse/App/StockPulseApp.swift`, `RootView.swift` |
| VM | `StockPulse/ViewModels/StockPulseViewModel.swift` |
| Data | `StockPulse/Data/MockDataStore.swift` |
| Models | `StockPulse/Models/Models.swift` |
| Ripple tab | `StockPulse/Views/Ripple/RippleTrackerView.swift` |
| Watchlist | `StockPulse/Views/Watchlist/WatchlistView.swift` |
| Trends | `StockPulse/Views/Trends/TrendsView.swift` |
| AI | `StockPulse/Views/AI/AIAnalystView.swift` |
| Components | `SparklineView`, `VerdictBadge`, `SectionLabel`, `SPCard`, `TickerTapeView` |
| Layout util | `StockPulse/Utilities/Utilities.swift` (`FlowLayout`) |

## Phase 2 (live data) — included in same target

- `MarketDataService`, `RippleEngine`, `AIAnalystService`, `LiveDataBridge`, `BackgroundReportTask`
- `StockPulseViewModel.refresh()` — pull-to-refresh only; mock data remains on cold launch
- API keys: `Config.xcconfig` → `Info.plist` via `$(POLYGON_API_KEY)`, `$(GROQ_API_KEY)`

## Build & run

```bash
cd ios
xcodegen generate
xcodebuild -project StockPulse.xcodeproj -scheme StockPulse \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Open **StockPulse.xcodeproj** (not MarketPulse.xcodeproj).

## Phase 1 verification checklist

- [x] Background `#060a0f` on all tabs (`DS.Color.bg.ignoresSafeArea()`)
- [x] No `NavigationStack` / no `List`
- [x] Ticker tape under Ripple header
- [x] SPCX + NVDA catalyst cards and ripple verdicts from mock math
- [x] Watchlist 10 tickers with sparklines and badges
- [x] Trends: both catalyst network charts
- [x] AI suggestions + Groq via `AIAnalystService`
- [x] Cold launch: mock data in VM property initializers (no async gate)
- [x] **BUILD SUCCEEDED** (iPhone 17 simulator, Xcode 26.2)

## Legacy

`ios/MarketPulse/` remains for reference; active app is **StockPulse**.
