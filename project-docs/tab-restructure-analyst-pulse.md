# Tab Restructure: Analyst + Pulse

**Date:** 2026-06-20

## Summary

Restructured StockPulse from 6 tabs to 5 by merging related screens and splitting AI into digest vs chat.

| Tab | Replaces | Content |
|-----|----------|---------|
| **Pulse** | Ripple + Trends | Market indices/industries, chart range, catalyst picker, verification, collapsible compare-all |
| **Monitor** | (unchanged) | Watchlist |
| **Analyst** | Market + AI feed | Market Brief, Research Watchlist, Reports/Alerts digest |
| **Trade** | (unchanged) | Paper trading |
| **AI** | AI (slimmed) | Ask AI chat only — suggestion chips, input, response |

## Implementation Steps

### 1. Tab enum (`Models.swift`)

- Removed `AppTab.trends` and `AppTab.market`
- Added `AppTab.pulse` (icon: `waveform.path.ecg`) and `AppTab.analyst` (icon: `chart.bar.doc.horizontal`)
- Re-indexed: `pulse=0, watchlist=1, analyst=2, trade=3, ai=4`

### 2. Root routing (`RootView.swift`)

- `PulseView()` → `.pulse`
- `AnalystView()` → `.analyst`
- Removed Trends and Market `TabHost` entries

### 3. Analyst tab

- **New file:** `ios/StockPulse/Views/Analyst/AnalystView.swift`
- Renamed header from "Market" → "Analyst"
- Embedded `AssistantFeedView` below Research Watchlist
- Preserved `.task { generateMarketBrief() }` and `.refreshable { refreshMarketTab() }`
- **Deleted:** `MarketView.swift`

### 4. AI tab (chat only)

- **Modified:** `ios/StockPulse/Views/AI/AIAnalystView.swift`
- Removed `AssistantFeedView`
- Header renamed to "Ask AI"

### 5. Pulse tab

- **New files:**
  - `ios/StockPulse/Views/Pulse/PulseView.swift` — merged scroll layout
  - `ios/StockPulse/Views/Pulse/CatalystTrendChartCard.swift` — extracted multi-catalyst chart + `TrendRangePicker`
- Section order: AppHeader → ticker tape → broad market → industries → range picker → catalyst focus → verification → collapsible "Compare All Networks" → market detail
- Moved `loadTrendRangeIfNeeded()` lifecycle from deleted TrendsView
- **Modified:** `RippleTrackerView.swift` — `AppHeaderView` subtitle → "Market Context · Catalyst Networks · Verification"
- **Deleted:** `TrendsView.swift`

### 6. ViewModel

- Default tab: `.pulse`
- Comment on `refreshMarketTab()` updated for Analyst tab (logic unchanged)

### 7. Xcode project

- Updated `StockPulse.xcodeproj/project.pbxproj` with Analyst and Pulse groups; removed MarketView and TrendsView references

## Files Changed

| Action | Path |
|--------|------|
| Modified | `ios/StockPulse/Models/Models.swift` |
| Modified | `ios/StockPulse/App/RootView.swift` |
| Modified | `ios/StockPulse/ViewModels/StockPulseViewModel.swift` |
| Created | `ios/StockPulse/Views/Analyst/AnalystView.swift` |
| Created | `ios/StockPulse/Views/Pulse/PulseView.swift` |
| Created | `ios/StockPulse/Views/Pulse/CatalystTrendChartCard.swift` |
| Modified | `ios/StockPulse/Views/AI/AIAnalystView.swift` |
| Modified | `ios/StockPulse/Views/Ripple/RippleTrackerView.swift` (header subtitle) |
| Deleted | `ios/StockPulse/Views/Market/MarketView.swift` |
| Deleted | `ios/StockPulse/Views/Trends/TrendsView.swift` |
| Modified | `ios/StockPulse.xcodeproj/project.pbxproj` |

## CSS / styling

No design-system token or color changes. Existing card styles (purple brief, orange research, blue chat response) preserved. Structural moves only.

## Verification

```bash
xcodebuild -project StockPulse.xcodeproj -scheme StockPulse \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Build succeeded.

## Manual test checklist

- [ ] Tab bar shows 5 tabs: Pulse, Monitor, Analyst, Trade, AI
- [ ] Analyst: brief + research + reports/alerts feed; pull-to-refresh works
- [ ] AI: chat only, no feed
- [ ] Pulse: range picker, catalyst chart, verification cards, expand "Compare All Networks"
- [ ] Pulse: market card tap opens detail panel

## Web frontend (2026-06-20 follow-up)

The initial tab restructure was **iOS-only**. The web app at https://tryan.app was updated to match:

| Tab | Content |
|-----|---------|
| Pulse | Ripple + Trends merged |
| Monitor | Watchlist |
| Analyst | Market brief + research + assistant feed |
| AI | Ask AI chat only |

**Deployed:** `rsync dist/` → `mspclientpro:/var/www/tryan.app/`  
**Restarted:** `stockpulse-api`, `nginx`  
**New bundle:** `index-MDSUYFhQ.js`

If the old UI still appears, hard-refresh (Cmd+Shift+R) or clear cache — the previous bundle was `index-D3Vi8_ap.js`.
