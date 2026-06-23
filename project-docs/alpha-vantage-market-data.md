# Alpha Vantage market data

> **Superseded:** StockPulse now uses [Massive](massive-market-data.md). This doc is kept for reference only.

**Date:** June 3, 2026

## Change

Replaced Polygon.io with [Alpha Vantage](https://www.alphavantage.co/documentation/) `TIME_SERIES_DAILY` in [`MarketDataService.swift`](../ios/StockPulse/Services/MarketDataService.swift).

## Configuration

| Key | File |
|-----|------|
| `ALPHA_VANTAGE_API_KEY` | `ios/Config.xcconfig` (gitignored) → `Info.plist` |

Example template: [`ios/Config.xcconfig.example`](../ios/Config.xcconfig.example)

```bash
cd ios && xcodegen generate
```

## API behavior

- Endpoint: `https://www.alphavantage.co/query?function=TIME_SERIES_DAILY&symbol=NVDA&outputsize=compact&apikey=...`
- `outputsize=compact` returns the latest **100** daily bars (enough for 90-day charts).
- Tickers are fetched **one at a time** with a **12.5s** pause between calls (free tier: 5 calls/minute).
- In-memory cache per symbol: **1 hour** (reduces repeat quota use).

## Free-tier limits (important)

- **5 API calls per minute** — first full refresh (~9 symbols) takes ~2 minutes.
- **25 API calls per day** — avoid frequent pull-to-refresh; cache covers repeat opens within an hour.

## Security

Store the key only in `Config.xcconfig`. If the key was shared in chat or email, regenerate it in the Alpha Vantage support portal.

## Future: SpaceX (SPCX)

Unchanged — add to `CatalystCatalog` when the symbol trades; Alpha Vantage will return data like any other ticker.
