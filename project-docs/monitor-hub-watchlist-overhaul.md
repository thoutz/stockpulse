# Monitor Hub — Watchlist Overhaul

**Date:** June 15, 2026

## Summary

Replaced the flat Watchlist with a **Monitor** tab: tiered symbol groups (Hot / Warm / Cold), sector focus picker, Finnhub live quotes, 20-favorite cap, and 5-minute move columns for trading decisions.

## Server changes

### New modules
| File | Purpose |
|------|---------|
| `services/sector_catalog.py` | Canonical sector definitions (sync with `IndustryCatalog.swift`) |
| `services/monitor_tiers.py` | Tier resolution + quote interval rules |
| `services/monitor_service.py` | `GET /api/monitor` payload builder |
| `services/quote_scheduler.py` | Finnhub quote job every 30s (market hours) |
| `services/indicators.py` | Local RSI/SMA from daily bars |
| `routers/monitor.py` | `/api/monitor`, `PUT /api/monitor/focus` |

### Database
- `monitor_settings` — single row (`id=1`), `focus_sector_id`
- `snapshots` — added `change_5m_pct`, `change_15m_pct`, `quote_source`

### Tier rules
- **Hot:** symbols in focused sector → Finnhub quote every 30s
- **Warm:** favorites outside focus → ~60s
- **Cold:** default config tickers, not favorited → ~3 min
- **Favorite limit:** 20 (`FAVORITE_LIMIT` in config)

### Ingest optimization
- Removed Massive RSI/SMA API calls; computed locally after daily bars
- Minute ingest weighted toward Hot/Warm tiers
- Name lookup: Finnhub profile first, Massive fallback
- Search fallback: Finnhub first, Massive fallback

### Alerts
- Movement job every **1 min** (was 10 min)
- Hot tier: alert on `change_5m_pct` ≥ 2%
- Warm/cold: keep ~20 min velocity check

### Config (`.env`)
```
FINNHUB_API_KEY=          # required for live quotes
FAVORITE_LIMIT=20
QUOTE_SCHEDULER_SECONDS=30
```

## iOS changes

### Tab
- Label: **Watchlist → Monitor** (eye icon)

### `WatchlistView.swift`
- Focus sector menu (Semiconductors / Space / EV / none)
- Sections: Hot · Warm · Background
- Rows show price, 1D %, **5m %**, live dot
- Favorite limit banner at 20/20
- Polls `/api/monitor` every 30s while tab visible

### `MarketView.swift`
- **Monitor heavily** button on each industry card → sets focus + opens Monitor tab

### `StockPulseViewModel.swift`
- `syncMonitor()`, `setMonitorFocus()`, tier state
- Rebuilds `watchItems` from monitor payload for Ripple ticker tape

### `StockPulseAPIService.swift`
- `fetchMonitor()`, `setMonitorFocus(sectorId:)`
- `APISnapshot` extended with 5m/15m fields
- `GET /api/favorites` now returns `{ favorites, count, limit }`

## API reference

```
GET  /api/monitor
PUT  /api/monitor/focus  { "focus_sector_id": "space" | null }
GET  /api/favorites      { favorites[], count, limit }
POST /api/favorites      → 409 at limit
```

## Deploy

1. Set `FINNHUB_API_KEY` on server
2. Redeploy `stockpulse-api` (DB columns auto-migrate on startup)
3. Rebuild iOS app

## Budget (typical ~20 favorites, one focus sector)

| Provider | Usage |
|----------|-------|
| Finnhub | ~25–35 calls/min (quotes + news) |
| Massive | 5 calls/min (daily + tier-weighted minute) |
