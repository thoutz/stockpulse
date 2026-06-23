# Market Tab — Chip Detail Cards & Live News

**Date:** June 9, 2026  
**Feature:** Richer tap-through detail for Broad Market indices and industry constituent chips, with periodic news headlines.

---

## Overview

Tapping a Broad Market index card (SPY / QQQ) or an industry constituent chip now opens a colorful inline detail panel with group context, ripple signals, and tappable news links. Headlines refresh every 15 minutes while a detail card stays open, and also on pull-to-refresh.

---

## User Experience

### Broad Market (SPY / QQQ)
- Index cards are now tappable (toggle open/close)
- Selected card gets an accent border (teal for SPY, blue for QQQ)
- Detail panel shows index blurb, price stats, sparkline, SPY vs QQQ spread, and news headlines

### Industry chips (NVDA, RKLB, etc.)
- Chips use per-industry accent colors (purple semis, blue space, amber EV)
- Detail panel shows:
  - Company display name
  - Group rank, vs-group 30D, breadth
  - Horizontal peer strip (switch between constituents in-place)
  - Ripple signal badges
  - Ticker headlines + industry pulse headlines from peers
  - “View in Watchlist” drill-down

### News
- Each headline is a `Link` opening the article in Safari
- Source, relative time, and sentiment badge (when server provides score)
- Empty state: “No recent headlines. News refreshes every 15 minutes.”

---

## Architecture

```
Tap chip/index
  → StockPulseViewModel.selectMarketTicker / selectMarketIndex
  → NewsService.fetchNews (server /api/news or Massive /v2/reference/news)
  → 15-min background refresh loop while detail open
  → MarketTickerDetailCard / MarketIndexDetailCard
```

**News sources (priority order):**
1. **Server** — `GET /api/news?symbols=...` from `news_items` table (Finnhub/Alpha Vantage ingest every 15–60 min)
2. **Massive** — `GET /v2/reference/news?ticker=...` when `STOCKPULSE_API_BASE_URL` is unset but `MASSIVE_API_KEY` is set

---

## Files Added

| File | Purpose |
|------|---------|
| `ios/StockPulse/Services/NewsService.swift` | Unified news fetch + 15-min cache |
| `ios/StockPulse/Views/Market/MarketDetailViews.swift` | Ticker/index detail cards + `MarketNewsRow` |

## Files Modified

| File | Change |
|------|--------|
| `server/stockpulse-api/routers/data.py` | `GET /api/news` endpoint |
| `ios/StockPulse/Models/Models.swift` | `NewsArticle`, `MarketDetailSelection` |
| `ios/StockPulse/Data/IndustryCatalog.swift` | Company names, blurbs, accent colors |
| `ios/StockPulse/Services/StockPulseAPIService.swift` | `APINewsItem`, `news()` |
| `ios/StockPulse/ViewModels/StockPulseViewModel.swift` | Selection state, news loading, refresh loop |
| `ios/StockPulse/Views/Market/MarketView.swift` | Tappable indices/chips, detail section |

---

## Server Endpoint

```
GET /api/news?symbols=NVDA,AMD&limit=8&hours=72
```

Returns deduplicated headlines sorted by `published_at` desc.

---

## CSS / Design Tokens Used

No global dashboard style changes. Detail cards reuse existing `DS` tokens:

| Element | Token |
|---------|-------|
| Left accent bar | Industry/index accent hex from `IndustryCatalog` |
| Group panel background | `accent.opacity(0.06)` |
| Selected chip border | `accent.opacity(0.45)` |
| News row background | `DS.Color.surface2` |
| Sentiment bullish/bearish | `DS.Color.green` / `DS.Color.red` |
| News source label | Industry accent or `DS.Color.blue` |

Industry accent hex map:
- Semiconductors: `a78bfa` (purple)
- Space & Aerospace: `60a5fa` (blue)
- EV & Auto: `f59e0b` (amber)
- SPY index: `34d399` (teal)
- QQQ index: `60a5fa` (blue)

---

## Installation / Build

```bash
cd ios && xcodegen generate
```

Open `StockPulse.xcodeproj`. News works with:
- `STOCKPULSE_API_BASE_URL` (server ingest), and/or
- `MASSIVE_API_KEY` (direct reference news fallback)

Deploy server change for `/api/news` on the StockPulse API host.

---

## Periodic Refresh

- **While detail open:** `Task.sleep(15 min)` loop in `startMarketNewsRefreshLoop()`
- **Pull-to-refresh:** `refreshMarketTab()` forces news reload for active selection
- **NewsService cache TTL:** 15 minutes per symbol
