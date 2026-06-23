# Monitor row tap hit area + expand reliability (iOS)

**Date:** 2026-06-20  
**Issue:** Monitor symbol rows only responded to taps on the symbol name or chevron — not the full row width. Expansion also felt inconsistent (tap multiple symbols before detail appeared).

## Root causes

1. **Hit testing:** `MonitorRow` used `Button` + `HStack` + `Spacer`. SwiftUI does not treat spacer gaps as tappable unless `.contentShape(Rectangle())` is applied.
2. **Animation race:** Root `.animation(..., value: selectedTicker)` stacked with `withAnimation` in toggle and immediate `scrollTo` — expansion layout and scroll fought each other, hiding the detail panel off-screen.

## Changes

**File:** `ios/StockPulse/Views/Watchlist/WatchlistView.swift`

### Full-row tap target
- `MonitorRow`: added `.frame(maxWidth: .infinity, alignment: .leading)` and `.contentShape(Rectangle())` on the button label so any point along the row toggles expand/collapse.
- `WatchRow` (legacy fallback list): same pattern.

### Expand reliability
- Removed root `.animation(.spring, value: selectedTicker)` — single animation source remains in `toggleMonitorSelection(withAnimation:)`.
- Deferred `scrollTo` via `DispatchQueue.main.async` so expanded chart/stats layout completes before scrolling.
- Removed `.transition(.opacity.combined(with: .move(edge: .top)))` on inline detail.
- Switched monitor list container from `LazyVStack` to `VStack` (three tier sections; avoids lazy layout glitches on dynamic row height).

## Verification

```bash
xcodebuild -project StockPulse.xcodeproj -scheme StockPulse \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

**BUILD SUCCEEDED**

## Manual test

1. Monitor tab → tap middle of a row (between symbol and price) → should expand on first tap.
2. Tap another symbol → previous collapses, new one expands with chart visible.
3. Tap same row again → collapses.
