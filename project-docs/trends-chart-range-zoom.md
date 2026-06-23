# Trends Chart Range Zoom (1D / 1W / 1M / 30D / 1Y)

## Goal

Add time-range controls to the Trends tab so users can zoom/compare ripple networks over **1D, 1W, 30D, or 1Y** (1M removed — redundant with 30D).

## Approach

| Range | Data source | Extra API calls |
|-------|-------------|-----------------|
| 1W, 30D | Slice bars already in `/api/dashboard` | **0** |
| 1Y | One batched `/api/histories?days=365` (Postgres read, cached per session) | **1** on first select |
| 1D | Per-ticker `/api/minute/{symbol}` (cached minute bars, cached per session) | **8** on first select (one per trend ticker) |

Charts always re-normalize to **% change from the first bar in the selected range**.

## Server fix

`/api/history/{symbol}` and `/api/histories` previously returned the **oldest** N rows (`LIMIT` without date cutoff). Both now filter with `bar_date >= cutoff` so 1Y requests return recent history.

## Web changes

- `web/src/lib/trendRange.ts` — range types, daily/minute slicing helpers
- `web/src/hooks/useTrendRangeData.ts` — range state + lazy fetch/cache for 1D and 1Y
- `web/src/lib/api.ts` — `histories()` and `minute()` client methods
- `web/src/views/TrendsView.tsx` — horizontal range pill bar
- `web/src/views/TrendsView.css` — `.trends-range-*` styles
- `web/src/components/TrendChart.tsx` — dynamic `rangeLabel` instead of hardcoded "30d"

## iOS changes

- `ios/StockPulse/Models/TrendChartRange.swift` — enum + `TrendRangeHelper` slice logic
- `ios/StockPulse/Services/StockPulseAPIService.swift` — `histories(tickers:days:)` and `minuteBars(ticker:)`
- `ios/StockPulse/ViewModels/StockPulseViewModel.swift` — `trendRange`, lazy load, range-aware `chartSeries` / `periodChangePct`
- `ios/StockPulse/Views/Trends/TrendsView.swift` — horizontal range picker + loading state
- `ios/StockPulse.xcodeproj/project.pbxproj` — added new Swift file to target

## CSS (web)

Range pills use existing tokens:

- Inactive: `--surface2` background, `--border`, `--text-dim`
- Active: `--blue` text, `rgba(96, 165, 250, 0.12)` background

## 1D / 1W display fix (follow-up)

- **1W** now uses the last **7 trading bars** (not calendar days), and all tickers are aligned to the same trailing window.
- **1D** filters minute bars to the latest **US regular session** (9:30–16:00 ET), with fallback to the last 2 daily bars if minute data is unavailable.
- Charts align series lengths so compared lines share the same x-axis.
- Web intraday axis shows **time (ET)**; iOS uses hourly marks for 1D and daily marks for 1W.

## Notes

- **1Y** is capped by server retention (`full_days` ≈ 180 in DB today), not a full calendar year until retention is extended.
- **1D** requires server API on iOS; local Massive-only mode shows a connect message for intraday.
- Fetched 1D/1Y data is cached in memory for the session — switching back to those ranges does not re-fetch.

## Install / deploy

No new packages. Redeploy `stockpulse-api` for the history endpoint fix. Rebuild web (`npm run build`) and iOS app as usual.
