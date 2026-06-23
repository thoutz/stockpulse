# Monitor accordion detail redesign

**Date:** 2026-06-20  
**Goal:** Expand symbol detail inline in the Monitor list (folder-style accordion), one row expanded at a time, with price/change filling the header right column and no pinned banner above the scroll view.

## Problem

The previous layout pinned `MonitorDetailBanner` / `MonitorDetail` above the tier list. That left blank space in the top-right of the expanded header and detached the chart from the row the user tapped.

## Design

- Tap a row to expand/collapse (chevron indicates state).
- Only one symbol expanded at a time; selecting another collapses the previous and clears its chart cache (iOS).
- Expanded content renders **below** the row inside the same scroll list.
- Header uses two columns: symbol + name on the left; live/scrub price + change on the right.
- Chart sits above stat boxes; no close (X) button — tap row again to collapse.
- On expand, scroll the row into view (`ScrollViewReader` on iOS; `scrollIntoView` on web).

## iOS changes

**File:** `ios/StockPulse/Views/Watchlist/WatchlistView.swift`

- Removed pinned detail banner above `ScrollView`.
- Wrapped list in `ScrollViewReader`; `onChange(of: selectedTicker)` scrolls to row id.
- `monitorSection`: each row is a `VStack` with `MonitorRow` + conditional `MonitorExpandedDetail`.
- `toggleMonitorSelection(_:)`: single selection, clears chart cache for collapsed symbols, resets scrub state.
- `MonitorRow`: hides price/5m when expanded; chevron up/down.
- `MonitorExpandedDetail`: split header (left symbol/name, right price/change), chart, stat boxes, meta.
- Removed unused `monitorRow(for:)`.

## Web changes

**Files:** `web/src/views/WatchlistView.tsx`, `web/src/views/WatchlistView.css`

- Removed standalone `MonitorDetail` block above tier sections.
- `renderTier`: wraps each row in `.monitor-accordion-item`; inlines `MonitorDetail` when selected.
- `toggleSelection`: one-at-a-time expand; clears scrub on toggle.
- `MonitorRow`: `expanded` prop, chevron, hides price/5m when expanded.
- `MonitorDetail`: split header layout; removed `onClose`; fixed duplicate `ScrubbablePriceChart`.
- Top movers chips scroll to `#monitor-row-{symbol}` on select.

**CSS additions:**

- `.monitor-accordion-item.expanded` — row highlight background.
- `.monitor-detail-inline` — inset orange bar, nested under expanded row.
- `.monitor-detail-header-split`, `-left`, `-right`, `-price-large`, `-change`, `-sublabel`.
- `.monitor-row-chevron`; grid column for chevron (`1fr auto auto 16px 16px`).

## Verification

- Web: `npm run build` — success.
- iOS: `xcodebuild -project StockPulse.xcodeproj -scheme StockPulse -destination 'platform=iOS Simulator,name=iPhone 17' build` — **BUILD SUCCEEDED**.

## Usage

1. Open Monitor tab.
2. Tap any symbol row — detail expands inline with chart and stats.
3. Tap another row — previous collapses, new one expands.
4. Tap the same row again — collapses.
