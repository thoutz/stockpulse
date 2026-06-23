# Market Tab Refresh Button Fix

**Date:** June 9, 2026  
**Issue:** Market tab Refresh did not reliably produce updated analysis.

---

## Root causes

1. **Refresh button only called `generateMarketBrief(force: true)`** — industry/index snapshots were not refetched first, so the AI brief could be regenerated from stale price data.
2. **Silent no-op when `!usesLiveData`** — tapping Refresh did nothing if dashboard data had not loaded yet.
3. **Stale fallback on manual refresh (server mode)** — if server chat failed on force refresh, the app showed an old cached pulse report instead of an error.
4. **`guard !marketLoading`** blocked manual refresh while auto-generation from `.task` was in flight.

---

## Fixes

### `refreshMarketTab()` in `StockPulseViewModel`

New unified entry point used by the Refresh button and pull-to-refresh:

1. `refresh()` — fetches latest dashboard / Massive data and recomputes industry + index snapshots
2. `syncAssistantFeed()` — when using server API, pulls latest AI reports
3. `generateMarketBrief(force: true)` — requests a new analysis (bypasses 4h cache)

### `generateMarketBrief(force:)` improvements

- **Force path** bypasses cache TTL and `marketLoading` guard (user intent wins)
- **Force path** clears `marketBriefGeneratedForRefresh` before generating
- **Force path** shows a clear error if data is unavailable or AI call fails (no stale pulse fallback)
- **Non-force path** unchanged — still respects cache and pulse report fallback

### `MarketView` UI

- Refresh button and pull-to-refresh both call `refreshMarketTab()`
- Loading spinner shows during `isRefreshing` **or** `marketLoading`
- Status text: "Refreshing market data..." while fetching, then AI message while analyzing

---

## Files changed

- `ios/StockPulse/ViewModels/StockPulseViewModel.swift`
- `ios/StockPulse/Views/Market/MarketView.swift`

---

## Test plan

1. Open Market tab with `STOCKPULSE_API_BASE_URL` configured.
2. Tap **Refresh** — indices/industries should update, then Market Brief timestamp should change.
3. Pull to refresh — same behavior.
4. With no network — brief should show a connection/data error, not a silently stale report.
