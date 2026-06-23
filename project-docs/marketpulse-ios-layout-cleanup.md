# MarketPulse — iOS Layout & Chart Cleanup

**Date:** June 2026

## Problems observed

1. **Tab content not filling the screen** — `TabView` children (especially `NavigationStack` + `ScrollView`) sized to content height, so the floating tab bar appeared mid-screen with large black gaps.
2. **Chart lines invisible** — Y values are percentage *points* (e.g. `5.0` = 5%) but axes used `FloatingPointFormatStyle.Percent.scale(0.01)`, which expects fractions (`0.05`). Lines rendered far outside the visible domain.
3. **Catalyst cards showed +0.0%** — Post-event math used raw `Date` comparison in the selector while `RippleEngine` uses `startOfDay`; mock dates used UTC while catalyst dates used local calendar.
4. **Truncated event names** — Fixed-width 200pt cards clipped NVDA subtitle.
5. **Ripple verification section** — Often below the fold; no empty state when results missing.

## Fixes applied

### Layout (`TabScreenLayout.swift`)

- `marketPulseTabRoot()` — `frame(maxWidth:maxHeight: .infinity)` on every tab root.
- `MarketPulseScrollScreen` — shared `NavigationStack` + `ScrollView` with `contentMargins(.bottom, 72)` for floating tab bar clearance.
- `RootTabView` — `toolbarBackground(.visible, for: .tabBar)` for clearer tab chrome.

### Charts (`ChartFormatting.swift`, `NormalizedTrendChart.swift`)

- `NormalizedChartPoint` model for identifiable series.
- `chartPercentPointAxis()` — labels like `5%` for percentage-point values.
- `chartDateAxis()` — month/day labels on X.
- `chartYScale(domain:)` — auto padding so lines stay in frame.
- `interpolationMethod(.catmullRom)` for readable multi-line charts.
- Replaced nested `ForEach` + `LineMark` with `ForEach(points)` on stable IDs.

### Data alignment

- `MockDataLoader` parses dates in `Calendar.current.timeZone` (not forced UTC).
- `RippleEngine.postEventChange` / `preEventChange` made public for UI stats.
- Catalyst selector uses `RippleEngine.postEventChange` for post-event %.

### UI polish

- Catalyst cards: ~78% screen width, 2-line event names, grouped background colors.
- Ripple cards: improved padding, empty-state copy, expanded dual-chart uses shared chart helpers.
- `SparklineView`: full-series area + line, proper Y domain.
- Watchlist / AI tabs: same tab-root layout; AI uses `MarketPulseScrollScreen`.

## Files touched

- `MarketPulse/App/RootTabView.swift`
- `MarketPulse/Utilities/ChartFormatting.swift` (new)
- `MarketPulse/Views/Components/TabScreenLayout.swift` (new)
- `MarketPulse/Views/Components/NormalizedTrendChart.swift` (new)
- `MarketPulse/Views/Components/SparklineView.swift`
- `MarketPulse/Views/Ripple/RippleTrackerView.swift`
- `MarketPulse/Views/Watchlist/WatchlistView.swift`
- `MarketPulse/Views/Trends/TrendCompareView.swift`
- `MarketPulse/Services/MockDataLoader.swift`
- `MarketPulse/Services/RippleEngine.swift`

## Verify in Xcode

1. Run on Simulator (⌘R).
2. **Ripple** tab: full-height scroll, visible colored trend lines, ripple cards below chart, tab bar at bottom.
3. **Watchlist**: full list; tap row for detail chart.
4. **Trends** / **AI**: same layout behavior.

Build: `xcodebuild -project ios/MarketPulse.xcodeproj -scheme MarketPulse -destination 'generic/platform=iOS Simulator' build` — succeeded after cleanup.

---

## Update: Tab bar + signing (follow-up)

### Root cause of “smushed” UI + tab bar in middle
SwiftUI `TabView` on iOS 18+ can size itself to content height instead of the window, centering the whole tab UI vertically. `GeometryReader` inside a vertical `ScrollView` (catalyst cards) worsened layout proposals.

### Fix
- Replaced `TabView` with **`AppTabBar`** pinned via `.safeAreaInset(edge: .bottom)` on a full-screen `ZStack`-style shell in `RootTabView`.
- Removed `GeometryReader` from `CatalystSelectorView`; fixed-width cards (280pt) in horizontal `ScrollView`.
- `MarketPulseScrollScreen` uses `LazyVStack` + full-screen `ZStack` background.

### Persistent code signing
- [`ios/Signing.xcconfig`](ios/Signing.xcconfig) — `DEVELOPMENT_TEAM = 3U49743Z3T` (from your machine’s last Xcode setting).
- Wired in [`ios/project.yml`](ios/project.yml) so `xcodegen generate` does not wipe the team.
- Template: [`ios/Signing.xcconfig.example`](ios/Signing.xcconfig.example) (gitignored local file).

If signing still prompts, set your Team ID once in `Signing.xcconfig`, then Product → Clean Build Folder (⇧⌘K) and Run.
