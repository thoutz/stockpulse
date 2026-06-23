# Massive market data (StockPulse)

**Date:** June 3, 2026

## Overview

StockPulse loads US equity daily bars from [Massive](https://massive.com/) (formerly Polygon.io) via the Custom Bars REST API.

## Configuration

| Key | Where |
|-----|--------|
| `MASSIVE_API_KEY` | `ios/Config.xcconfig` (gitignored) → `Info.plist` |

1. Sign up at [massive.com](https://massive.com/) (Stocks Basic is free).
2. Copy your API key from the dashboard.
3. Set in `ios/Config.xcconfig`:

```xcconfig
MASSIVE_API_KEY = your_key_here
```

4. Regenerate and build:

```bash
cd ios && xcodegen generate
```

## API used

- **Host:** `https://api.massive.com`
- **Endpoint:** `GET /v2/aggs/ticker/{symbol}/range/1/day/{from}/{to}`
- **Implementation:** [`ios/StockPulse/Services/MarketDataService.swift`](../ios/StockPulse/Services/MarketDataService.swift)

## Free tier (Stocks Basic)

Per [Massive pricing](https://massive.com/pricing):

- 5 API calls per minute
- End-of-day US stock data
- 2 years of historical daily bars per request
- No Alpha Vantage–style 25 calls/day cap

The app fetches ~9 tickers in **batches of 5**, then waits 60 seconds before the next batch (~1–2 minutes on first load). Results are cached **5 minutes** per symbol.

## Why we switched from Alpha Vantage

Alpha Vantage free tier allows only **25 requests/day**. One StockPulse refresh uses ~9 calls, so the app could only refresh twice per day. Massive fits a multi-ticker watchlist with pull-to-refresh and launch refresh.

See also: [`alpha-vantage-market-data.md`](alpha-vantage-market-data.md) (superseded).

## SpaceX (SPCX)

When the ticker lists, add it to `CatalystCatalog` — Massive returns bars like any other US symbol.
