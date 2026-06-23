# Groq full app context

**Date:** June 3, 2026

## Goal

Give Groq (llama-3.3-70b) the complete StockPulse app state so the AI tab can answer questions about any watchlist ticker, catalyst, ripple verdict, or Massive price history in the app.

## Implementation

### New files

- [`ios/StockPulse/Services/AIAppContext.swift`](../ios/StockPulse/Services/AIAppContext.swift) — `AIAppContext` snapshot + `AIContextBuilder.build(from:)`

### Context sections sent to Groq (system message)

1. **Instructions** — StockPulse ripple model, verdict meanings, use-only-this-data rule
2. **Data freshness** — `lastRefreshed` from Massive load
3. **Future tickers** — e.g. SPCX placeholder
4. **Watchlist** — price, 1D/30D %, ripple badges per ticker
5. **Daily history** — last 30 closes per ticker (date:price series from Massive)
6. **Catalysts** — event name/date, chart markers, tracked ripples, catalyst post-event %, all ripple results (pre/post/verdict/description)
7. **Selected catalyst** — marked `[USER SELECTED ON RIPPLE TAB]`
8. **Ticker index** — all symbols in the dataset

### ViewModel

[`StockPulseViewModel.askAI()`](../ios/StockPulse/ViewModels/StockPulseViewModel.swift) builds `AIAppContext` from `liveHistories`, `watchItems`, `catalysts`, `liveRippleResults`, `selectedCatalystIndex`, `lastRefreshed`.

### Groq settings

- `max_tokens`: 500 → **1200**
- `temperature`: **0.4**
- HTTP error body surfaced on failure

### UI

- AI header: **"Full app + Massive data"** when live
- Sample prompts include watchlist-wide comparison

## Requirements

- Massive data must be loaded (`usesLiveData`) before `askAI()` runs
- `GROQ_API_KEY` in `ios/Config.xcconfig`

## Not included

- Live Massive API calls from Groq (all data is pre-fetched in-app)
- Tickers outside `CatalystCatalog` / watchlist
