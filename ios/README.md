# StockPulse — iOS App

**Active target:** `StockPulse.xcodeproj` (SwiftUI, iOS 17+)

```bash
cd ios && xcodegen generate
open StockPulse.xcodeproj
```

Phase 1 UI rebuild docs: [../project-docs/stockpulse-phase1-ui-rebuild.md](../project-docs/stockpulse-phase1-ui-rebuild.md)

Legacy `MarketPulse/` sources are kept for reference only.

---

## Original build guide (MarketPulse era)

React web prototype → SwiftUI iOS app

---

## Project Structure

```
stockpulse-ios/
├── StockPulse.xcodeproj
├── StockPulse/
│   ├── App/
│   │   └── StockPulseApp.swift          # App entry point
│   ├── Models/
│   │   ├── Stock.swift                  # Stock, HistoryPoint, RippleRelation
│   │   ├── Catalyst.swift               # Catalyst + ripple definitions
│   │   └── RippleVerdict.swift          # CONFIRMED/FORMING/FAILED/WATCHING logic
│   ├── Services/
│   │   ├── MarketDataService.swift       # Polygon.io API client
│   │   ├── RippleEngine.swift           # Correlation + verdict computation
│   │   └── AIAnalystService.swift       # Groq/Anthropic API client
│   ├── ViewModels/
│   │   ├── WatchlistViewModel.swift
│   │   ├── RippleViewModel.swift
│   │   └── TrendViewModel.swift
│   ├── Views/
│   │   ├── RootTabView.swift            # Tab container
│   │   ├── Watchlist/
│   │   │   ├── WatchlistView.swift
│   │   │   ├── WatchRowView.swift
│   │   │   └── StockDetailView.swift
│   │   ├── Ripple/
│   │   │   ├── RippleTrackerView.swift
│   │   │   ├── RippleCardView.swift
│   │   │   └── RipplePanelView.swift
│   │   ├── Trends/
│   │   │   ├── TrendCompareView.swift
│   │   │   └── TrendChartView.swift     # Swift Charts
│   │   ├── AI/
│   │   │   └── AIAnalystView.swift
│   │   └── Components/
│   │       ├── SparklineView.swift
│   │       ├── TickerTapeView.swift
│   │       ├── VerdictBadge.swift
│   │       └── StatCardView.swift
│   └── Resources/
│       ├── Assets.xcassets
│       └── MockData.json                # Seed data for dev/preview
```

---

## Data Architecture

### Live Data (Polygon.io — free tier works)
```
GET https://api.polygon.io/v2/aggs/ticker/{ticker}/range/1/day/{from}/{to}
```
- Free tier: 5 API calls/min, 2-year history
- Upgrade to Starter ($29/mo) for real-time websocket

### AI Analyst (two options)
- **Groq** (recommended — you already use it for Whetstone): `llama-3.3-70b-versatile`, fast + cheap
- **Anthropic**: `claude-sonnet-4-20250514` — better reasoning, slightly slower

### Ripple Verdicts (computed locally — no API needed)
- Normalize all stocks to % change from a baseline date
- Compare post-event delta of catalyst vs. ripple
- Thresholds: CONFIRMED = catalyst >3% AND ripple >2% post-event

---

## Tech Stack Recommendation

| Layer | Choice | Notes |
|-------|--------|-------|
| UI | SwiftUI | Charts via Swift Charts (iOS 16+) |
| State | @Observable + SwiftData | iOS 17+; or @StateObject + CoreData |
| Networking | async/await URLSession | No Alamofire needed |
| Charts | Swift Charts | Built-in, no deps |
| Background refresh | BackgroundTasks framework | Scheduled 6AM reports |
| Notifications | UNUserNotificationCenter | Push alerts on ripple events |
| Storage | SwiftData | Persist watchlist + history |
| AI | URLSession → Groq/Anthropic REST | No SDK needed |

---

## Key Implementation Notes

### 1. Ripple Verdict Logic
See `RippleVerdict.swift` — pure computation, no network needed.
Runs on every data refresh. Can be unit tested easily.

### 2. Scheduled Reports (6AM)
Use `BGAppRefreshTask` — register in Info.plist, fetch + compute in background,
fire local notification with summary.

### 3. Chart Normalization
All trend charts normalize to % change from a chosen baseline date.
This is what makes multi-stock comparison readable (avoids price scale issues).

### 4. Mock Data
`MockData.json` contains the full 30-day dataset from the web prototype.
Use `#Preview` with mock data so you can build UI without hitting APIs.

---

## Code signing

Team and bundle ID are set in **`project.yml`** (`DEVELOPMENT_TEAM: 3U49743Z3T`). After `xcodegen generate`, Xcode should show **TRISTAN JAMES HOUTZ** without re-selecting the team. Change the team ID only in `project.yml`, then regenerate.

---

## Environment Variables (store in .xcconfig, NOT in source)
```
POLYGON_API_KEY=your_key_here
GROQ_API_KEY=your_key_here
ANTHROPIC_API_KEY=your_key_here      # optional if using Groq
SUPABASE_URL=your_project_url        # if you want cloud sync
SUPABASE_ANON_KEY=your_anon_key
```

---

## Phased Build Plan

### Phase 1 — Core (1-2 weeks)
- [ ] Models + MockData
- [ ] WatchlistView with sparklines
- [ ] RippleTrackerView with verdict cards
- [ ] Static TrendChartView using Swift Charts

### Phase 2 — Live Data (1 week)
- [ ] Polygon.io integration
- [ ] RippleEngine computing live verdicts
- [ ] Pull-to-refresh + auto-refresh timer

### Phase 3 — AI + Notifications (1 week)
- [ ] AIAnalystView with Groq
- [ ] Background refresh task
- [ ] Ripple event push notifications ("RKLB just confirmed SPCX ripple +4.2%")

### Phase 4 — Polish
- [ ] Supabase sync (multi-device watchlist)
- [ ] Widget (WidgetKit) — sparkline + ripple status
- [ ] Live Activity — active ripple tracking
