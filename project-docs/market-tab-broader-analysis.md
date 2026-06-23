# Market Tab — Broader Market Analysis

**Date:** June 4, 2026  
**Feature:** 5th tab ("Market") with industry trends, S&P 500 / Nasdaq tracking, and Groq-powered market brief.

---

## Overview

The Market tab aggregates the app's tracked tickers into hand-curated industries, compares them against broad-market ETF proxies (SPY, QQQ), and uses Groq (`llama-3.3-70b-versatile`) to generate a broader-market brief. Users can tap any constituent to see inline detail and jump to Watchlist for deeper drill-down.

---

## Architecture

```
refresh() → liveHistories (+ SPY, QQQ)
         → MarketAnalysisEngine → industrySnapshots + indexSnapshots
         → MarketView (UI)
         → generateMarketBrief() → MarketBriefContextBuilder → AIAnalystService (Groq)
         → MarketBriefStore (UserDefaults cache)

BackgroundReportTask (6 AM) → same Groq brief → persist + notification snippet
```

---

## Files Added

| File | Purpose |
|------|---------|
| `ios/StockPulse/Data/IndustryCatalog.swift` | Industry groupings + SPY/QQQ index definitions |
| `ios/StockPulse/Services/MarketAnalysisEngine.swift` | Rule-based industry/index aggregation |
| `ios/StockPulse/Services/MarketBriefContext.swift` | Groq prompt builder + UserDefaults persistence |
| `ios/StockPulse/Views/Market/MarketView.swift` | Market tab UI |

## Files Modified

| File | Change |
|------|--------|
| `ios/StockPulse/Models/Models.swift` | `AppTab`, `Industry`, `IndustrySnapshot`, `IndexSnapshot`, `MarketBrief`, `TickerPerformance` |
| `ios/StockPulse/Data/CatalystCatalog.swift` | `allTickers` now includes `SPY`, `QQQ` |
| `ios/StockPulse/ViewModels/StockPulseViewModel.swift` | Market state, snapshots, `generateMarketBrief()`, drill-down via `focusTicker()` |
| `ios/StockPulse/App/RootView.swift` | 5th Market tab with `TabView(selection:)` |
| `ios/StockPulse/Views/Watchlist/WatchlistView.swift` | Responds to `focusedTicker` from Market drill-down |
| `ios/StockPulse/Services/BackgroundReportTask.swift` | Morning task generates + persists market brief |

---

## Industry Groupings

| Industry | Tickers |
|----------|---------|
| Semiconductors | NVDA, AMD, AVGO |
| Space & Aerospace | RKLB, ASTS, LUNR, RDW, HWM |
| EV & Auto | TSLA |

Indices use ETF proxies (Massive free tier has no official index tickers):
- **S&P 500** → SPY
- **Nasdaq** → QQQ

---

## Market Analysis Engine

`MarketAnalysisEngine` computes per-industry:
- Average 1D and 30D % change (equal-weight)
- Breadth (tickers up today / total)
- Leader and laggard by 30D performance
- Equal-weight normalized sparkline series

Per-index (SPY/QQQ):
- Price, 1D/30D %, normalized sparkline

---

## Groq Market Brief

- **Trigger:** Market tab `.task` on open; pull-to-refresh; background morning report
- **Cache:** 4-hour TTL via `marketBriefGeneratedForRefresh` + `MarketBriefStore` (UserDefaults)
- **Model:** `llama-3.3-70b-versatile` via existing `AIAnalystService`
- **Prompt:** Identifies sector rotation, divergences vs SPY/QQQ, and suggests drill-down tickers

Requires `GROQ_API_KEY` in `ios/Config.xcconfig`.

---

## UI (Design System)

Uses existing `DS` tokens — no dashboard style changes:
- `SPCard` for industry and index cards
- `SparklineView` for trend lines
- `SectionLabel` for section headers
- `FlowLayout` for tappable constituent chips
- Purple-accented brief panel (distinct from AI tab's blue)

### Market tab sections
1. **Broad Market** — SPY + QQQ side-by-side cards
2. **Industries** — expandable cards with breadth, leader/laggard, constituent chips
3. **Market Brief** — Groq analysis with refresh button
4. **Company detail** — inline card on chip tap with "View in Watchlist" drill-down

---

## Drill-Down Flow

1. User taps constituent chip in Market tab → inline detail card
2. "View in Watchlist" → `vm.focusTicker(ticker, tab: .watchlist)`
3. `RootView` `TabView(selection:)` switches tab
4. `WatchlistView` opens detail banner for that ticker

---

## Background Task

`BackgroundReportScheduler` morning report now:
1. Fetches histories (server or Massive)
2. Runs ripple analysis (existing)
3. Calls Groq for market brief → `MarketBriefStore.save()`
4. Adds brief snippet to local notification

---

## Installation / Build

No new dependencies. Regenerate Xcode project if needed:

```bash
cd ios && xcodegen generate
```

Open `StockPulse.xcodeproj`, ensure `GROQ_API_KEY` and `MASSIVE_API_KEY` (or `STOCKPULSE_API_BASE_URL`) are set in `Config.xcconfig`.

---

## Future Extensions

- Add tickers to `IndustryCatalog.industries` to expand coverage
- Paid Massive tier for real index constituents and sector classifications
- Server-side market brief generation when using `StockPulseAPIService`
