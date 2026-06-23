# All tabs vertical-only scroll fix

**Date:** 2026-06-16

## Problem

After the AI tab horizontal drift fix, Trade (and potentially other tabs) still allowed left/right panning on the main vertical `ScrollView`.

## Solution

Centralized scroll layout helpers in `DesignSystem.swift` and applied them to every main tab.

### New helpers

| Modifier | Purpose |
|----------|---------|
| `spScrollContentWidth()` | Pins scroll content to screen width (`frame(maxWidth: .infinity, alignment: .leading)`) |
| `spVerticalScrollAxes()` | `scrollBounceBehavior(.basedOnSize, axes: .vertical)` — vertical bounce only |

### Tabs updated

- Ripple (`RippleTrackerView`)
- Monitor (`WatchlistView` + `SearchResultsList`)
- Trends (`TrendsView`)
- Market (`MarketView`)
- Trade (`TradeDashboardView`)
- AI (`AIAnalystView` — refactored to shared helpers)

### Supporting layout fixes

- `FlowLayout` containers in Ripple key events, Market industry chips, Market detail badges — `.frame(maxWidth: .infinity)`
- `HighlightedReportText`, `MarketTabReportView`, `AssistantFeedView` — width pinning via `spScrollContentWidth()`
- Trade proposal cards — `spScrollContentWidth()`

### Intentional horizontal scroll preserved

Nested `ScrollView(.horizontal)` regions (catalyst picker, trend range picker, ticker legend rows) are unchanged — those are deliberate carousels inside a vertically locked parent.

## Verification

Rebuild and swipe left/right on each tab — only vertical scroll should respond. Trade proposals and connection banner should stay pinned to screen width.
