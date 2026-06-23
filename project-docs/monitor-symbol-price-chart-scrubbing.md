# Monitor Symbol Price Chart + Scrubbing

**Date:** June 19, 2026

## Summary

Added Robinhood-style price charts to the Monitor tab symbol detail panel on **iOS (StockPulse)** and **web**. Tapping a symbol shows a price line chart with **1D / 1W / 30D / 1Y** range pills and tap-and-drag scrubbing that updates the header price, timestamp, and range % change.

## Behavior

| State | Header price | Sub-label | Change |
|-------|-------------|-----------|--------|
| Idle | Live quote from monitor row | `Live · {tier}` | Period change for selected range (first bar → last bar) |
| Scrubbing | Bar `close` at crosshair | Formatted bar datetime | Change from range start → scrubbed bar |

- Chart plots **absolute close price** (not normalized % like Trends).
- Line color: green if range period change ≥ 0, red otherwise.
- Scrub selection persists after finger/mouse release until range change, symbol change, or detail close.
- **Web:** double-click chart plot to clear scrub selection.

## Range → data source

| Range | Source |
|-------|--------|
| **1W, 30D** | Slice dashboard daily bars (`liveHistories` / `dashboard.histories`) |
| **1D** | `GET /api/minute/{symbol}` + RTH session filter |
| **1Y** | `GET /api/history/{symbol}?days=365` (iOS) or `GET /api/histories?tickers={symbol}&days=365` (web) |

No backend changes required.

## iOS changes

| File | Change |
|------|--------|
| `ios/StockPulse/Views/Watchlist/MonitorPriceChartView.swift` | **New** — SwiftUI Charts price chart, range pills, `chartXSelection` scrub, crosshair + dot |
| `ios/StockPulse/Views/Watchlist/WatchlistView.swift` | `MonitorDetailBanner` dynamic header + chart; load chart on symbol/range change |
| `ios/StockPulse/ViewModels/StockPulseViewModel.swift` | `monitorChartRange`, per-symbol cache, `loadMonitorChart`, `monitorChartBars`, `clearMonitorChartCache` |
| `ios/StockPulse/Services/LiveDataBridge.swift` | `changePct(from:to:)`, `nearestBar(to:in:)` |
| `ios/StockPulse.xcodeproj/project.pbxproj` | Added `MonitorPriceChartView.swift` to target |

### iOS scrub implementation

- `@State selectedDate` + `.chartXSelection(value:)`
- `RuleMark` vertical crosshair + `PointMark` dot at nearest bar
- No `.chartLineTrace` on monitor chart (avoids hit-testing conflicts)

## Web changes

| File | Change |
|------|--------|
| `web/src/hooks/useMonitorChartData.ts` | **New** — single-symbol range data hook with per-symbol/range cache |
| `web/src/components/ScrubbablePriceChart.tsx` | **New** — SVG price chart + range pills + pointer scrub |
| `web/src/components/ScrubbablePriceChart.css` | **New** — range pills, plot cursor, header helpers |
| `web/src/views/WatchlistView.tsx` | `MonitorDetail` chart + dynamic header; `useMonitorChartData` |
| `web/src/App.tsx` | Pass `dashboard` into `WatchlistView` |

### Web scrub implementation

- Transparent SVG `rect` over plot with `onPointerDown/Move/Up`
- Maps pointer X → nearest bar index
- Vertical dashed line + circle at scrub point

## CSS / styling notes

- Web range pills mirror Trends `.trends-range-btn` styling (`scrub-price-range-btn`).
- Monitor detail header uses larger price (`monitor-detail-price-large`) when chart is shown.
- No changes to global dashboard layout or tab bar design.

## Installation

No new dependencies. Rebuild:

- **iOS:** Open `StockPulse.xcodeproj`, build/run.
- **Web:** `npm run build` in `web/` (verified).

## Test checklist

1. Tap symbol in Monitor → chart appears with default **1D**.
2. Switch **1W / 30D / 1Y** → chart updates; 1D/1Y fetch from API when needed.
3. Drag on chart → header price/date/% update; crosshair visible.
4. Close detail → selection and cache cleared (iOS).
5. Trends tab and Market `PriceChart` unchanged.

## Range filter fix (June 19, 2026)

**Problem:** 1W/30D/1Y used dashboard hot-window data (~30 days) so ranges looked identical or mislabeled; daily charts used calendar-time x-axis (weekend gaps).

**Fix:**
- Monitor charts fetch **365 days daily history per symbol** on open (`/api/history/{symbol}?days=365`), cache locally, slice per range:
  - **1W** → last 7 trading bars
  - **30D** → last 30 calendar days (ET)
  - **1Y** → last 365 calendar days (ET)
  - **1D** → minute bars (RTH session) via `/api/minute/{symbol}`
- iOS daily charts use **evenly spaced index x-axis** with date labels at ticks (Robinhood-style).
- Web axis labels use `formatMonitorAxisDate` aligned to selected range.
