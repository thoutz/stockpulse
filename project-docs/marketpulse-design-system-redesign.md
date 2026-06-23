# MarketPulse — Design System & Full-Screen UI Redesign

**Date:** June 3, 2026

## Summary

Implemented the StockPulse full-screen UI redesign: centralized design tokens from `stockpulse-v2-reference.jsx`, hardened mock data fallback, fixed Watchlist layout/navigation issues, and aligned all four tabs with the reference dark theme.

## Phase 1 — DesignSystem.swift

**File:** `ios/MarketPulse/Utilities/DesignSystem.swift`

### Color tokens (hex from reference)

| Token | Hex | SwiftUI name |
|-------|-----|--------------|
| Background | `#060a0f` | `Color.mpBackground` |
| Surface | `#0d1117` | `Color.mpSurface` |
| Surface selected | `#111827` | `Color.mpSurfaceSelected` |
| Border | `#1e2535` | `Color.mpBorder` |
| Text primary | `#e2e8f0` | `Color.mpTextPrimary` |
| Text secondary | `#6b7280` | `Color.mpTextSecondary` |
| Text muted | `#4b5563` | `Color.mpTextMuted` |
| Accent | `#60a5fa` | `Color.mpAccent` |
| Positive / negative | `#22c55e` / `#ef4444` | `Color.mpPositive` / `Color.mpNegative` |
| Amber (SPCX catalyst) | `#f59e0b` | `Color.mpAmber` |

### Layout constants

- `horizontalPadding`: 16pt
- `tabBarClearance`: 72pt
- Watchlist columns: ticker 90, price 80, sparkline 72, 30D 56

### View modifiers

- `.mpScreenBackground()` — full frame + dark background
- `.mpCard(padding:)` — surface card with border stroke
- `.mpSectionLabel()` — uppercase mono section headers
- `.mpRowPadding()` — 16pt horizontal row insets
- `.mpDeltaColor(_:)` — green/red by sign

### Verdict colors

`RippleVerdict.swiftColor` and `.backgroundColor` read hex from `Catalyst.swift` model — single source, used in badges and ripple cards.

## Phase 2 — Data loading

**File:** `ios/MarketPulse/ViewModels/RippleViewModel.swift`

- Trim whitespace from `POLYGON_API_KEY`
- After live fetch, if no ticker has non-empty history → fall back to `MockDataLoader.loadHistories()`
- Fixes $0.00 when API key is set but Polygon returns empty bars (e.g. fictional `SPCX` ticker)
- DEBUG-only `errorMessage` on catch fallback

## Phase 3 — Full-screen shell

### RootTabView

- `.mpScreenBackground()` instead of `systemBackground`
- Tint `.mpAccent`

### AppTabBar

- Surface background `#0d1117`, top border `#1e2535`
- Selected tab: accent color + 2pt bottom underline
- Unselected: `mpTextSecondary`

### TabScreenLayout (MarketPulseScrollScreen)

- Inline navigation title (removes large-title black void)
- Toolbar background `mpSurface`
- Scroll content bottom margin `tabBarClearance` (72pt)
- Dark loading overlay on `mpSurface`

## Phase 4 — Watchlist

**File:** `ios/MarketPulse/Views/Watchlist/WatchlistView.swift`

### Navigation / List

- `.navigationBarTitleDisplayMode(.inline)`
- `.toolbarBackground(Color.mpSurface)`
- `.contentMargins(.bottom, tabBarClearance)`
- `.listRowInsets(EdgeInsets.zero)` — row controls its own padding
- Hidden list separators; custom bottom border per row

### WatchRowView layout

Flexible `HStack`:

```
[Ticker+badges] — Spacer — [Price+1D] — [Sparkline 72pt] — [30D%]
```

- `.mpRowPadding()` (16pt leading/trailing)
- Verdict badges use `RippleVerdict.swiftColor`
- Sparklines use `mpPositive` / `mpNegative`

### StockDetailBanner

- `mpSurfaceSelected` background, `mpBorder` stroke
- StatCards use DesignSystem

## Phase 5 — Ripple / Trends / AI

### RippleTrackerView

- Ripple verification: `LazyVGrid` with `GridItem(.adaptive(minimum: 220))`
- Catalyst cards: dark surface, amber accent for SPCX, border selection
- Ripple cards: verdict-colored border when expanded, left accent bar on explanation
- TrendChartCard: `.mpCard()` + caption line

### TrendCompareView

- Correlation rows use `.mpCard()`
- Section label via `.mpSectionLabel()`

### AIAnalystView

- Bordered panel matching reference (`mpSurface`, chip buttons on `mpSurfaceSelected`)
- Analysis block: left `mpAccent` bar, `mpSurfaceSelected` background

### SparklineView / VerdictBadge / StatCard

- Verdict colors from model hex
- Event rule marks use `mpAmber`
- Stat cards: `mpSurfaceSelected` + border

### ChartFormatting

- Palette aligned to reference: amber, green, blue, purple, orange, teal
- Grid lines use `mpBorder`

## Build verification

```bash
cd ios && xcodegen generate
xcodebuild -project MarketPulse.xcodeproj -scheme MarketPulse \
  -destination 'generic/platform=iOS Simulator' build
```

**Result:** BUILD SUCCEEDED

## Simulator checklist (manual)

- [ ] SPCX ~$324, RKLB ~$26, RDW ~$7.34
- [ ] 1D/30D% non-zero; sparklines visible
- [ ] No large black gap under nav title
- [ ] Watchlist 16pt margins; 30D% not truncated
- [ ] List clears bottom tab bar
- [ ] Ripple grid cards styled; catalyst selector readable
- [ ] Tap row → detail banner from top
- [ ] Pull-to-refresh works

## Files changed

| File | Change |
|------|--------|
| `Utilities/DesignSystem.swift` | **New** |
| `ViewModels/RippleViewModel.swift` | Mock fallback on empty API |
| `App/RootTabView.swift` | DesignSystem background |
| `Views/Components/AppTabBar.swift` | Reference tab styling |
| `Views/Components/TabScreenLayout.swift` | Inline nav, margins |
| `Views/Watchlist/WatchlistView.swift` | Full watchlist + AI redesign |
| `Views/Ripple/RippleTrackerView.swift` | Grid + card styling |
| `Views/Trends/TrendCompareView.swift` | DesignSystem cards |
| `Views/Components/SparklineView.swift` | Tokens + verdict colors |
| `Views/Components/NormalizedTrendChart.swift` | Border/amber colors |
| `Utilities/ChartFormatting.swift` | Reference palette |
| `MarketPulse.xcodeproj` | Regenerated via xcodegen |

## Out of scope (unchanged)

- `RippleEngine` logic
- `Catalyst.defaults`
- SwiftData `HistoryPoint` struct migration
- Reference header / ticker tape (future follow-up)
