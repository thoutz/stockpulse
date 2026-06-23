# Pulse & Monitor horizontal scroll fix

**Date:** 2026-06-16

## Problem

Pulse and Monitor tabs allowed left/right panning on the main vertical scroll, unlike other tabs that were locked to vertical-only scrolling.

## Root cause

Main `ScrollView`s already had `spVerticalScrollAxes()` and `spScrollContentWidth()`, but **child views widened scroll content**:

1. **`TickerTapeView`** — `GeometryReader` + very wide animated `HStack` reported full tape width to the parent scroll (primary Pulse issue).
2. **Nested horizontal `ScrollView`s** — chart range pickers, catalyst cards, ticker legend rows, monitor chart range picker expanded parent content width without width constraints.

## Fix

### New helper — `DesignSystem.swift`

```swift
func spContainedHorizontalScroll() -> some View {
    frame(maxWidth: .infinity, alignment: .leading)
}
```

Apply to intentional horizontal carousels so they scroll internally but don't widen the vertical scroll.

### Files updated

| File | Change |
|------|--------|
| `TickerTapeView.swift` | Removed `GeometryReader`; clip tape to screen width |
| `PulseView.swift` | Catalyst card carousel → `spContainedHorizontalScroll()` |
| `CatalystTrendChartCard.swift` | Range picker + legend row contained; card content width pinned |
| `MarketChartSections.swift` | Section VStacks + index row + industry chips width pinned |
| `MarketDetailViews.swift` | Ticker detail card content width pinned |
| `MonitorPriceChartView.swift` | Range picker contained; chart block width pinned |
| `WatchlistView.swift` | Monitor sections + legacy fallback width pinned |

## Verification

Rebuild and swipe left/right on Pulse and Monitor — only vertical scroll should respond. Horizontal carousels (ticker tape, range buttons, catalyst picker) still work within their rows.
