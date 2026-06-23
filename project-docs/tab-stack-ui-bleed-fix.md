# Tab Stack UI Bleed Fix (v2)

**Date:** June 9, 2026

## Problem

Analyst tab showed garbled ticker, empty black blocks, and duplicate “Monitor heavily” rows — looked like the app was wiped. Backend/trading data was fine; this was iOS layout only.

## Root causes

1. **Tab stacking** — Hidden Pulse tab still painted (animated ticker + market cards).
2. **Wrong tab content** — `MarketIndicesSection` / `MarketIndustriesSection` lived on **Pulse** instead of **Analyst**, so industry cards appeared in the wrong place.
3. **Empty charts** — Industry cards with no sparkline data rendered as large empty black `SPCard` shells.

## Fixes

### `RootView.swift`

- Switched to **`TabView(selection:)`** + hidden system tab bar + custom `StockPulseTabBar` (reliable one-tab-at-a-time rendering).

### `PulseView.swift`

- Removed market indices/industries/detail sections.
- Pulse = ticker + catalyst/ripple charts only.

### `AnalystView.swift`

- Added **market trends** section (indices, industries, detail) below Market Brief / Research Watchlist.

### `MarketChartSections.swift`

- Industry card shows hint text when sparkline has &lt; 2 points (no empty black chart).

### `TickerTapeView.swift`

- Wider spacing, stops animating on disappear.

## Verify after rebuild

1. Xcode → **Product → Clean Build Folder** → Run.
2. **Pulse** — ripples/catalysts, no “Monitor heavily”.
3. **Analyst** — “Analyst” header, Market Brief, industries (with labels or “Chart loads…” hint).
4. All **5 tabs** visible in bottom bar.

## Not affected

Server API, paper trading, favorites, monitor symbols — unchanged.
