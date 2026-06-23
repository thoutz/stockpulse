# Web Monitor Hub — tryan.app

**Date:** June 17, 2026

## Summary

Rebuilt the web **Watchlist** tab as a **Monitor hub** aligned with iOS: Hot/Warm/Cold tiers, focus sector, live 5m/15m fields, and top intraday movers. Uses `/api/monitor` only — **no changes** to session intelligence, Groq pulses, or AI tab.

## Problem

Web Watchlist showed a flat catalyst-based table from `/api/dashboard`. iOS already had a tier-aware Monitor hub (`/api/monitor`) with Finnhub 5m data and sector focus. Backend scripting produced rich intraday data with no active web surface.

## Solution

### API client (`web/src/lib/api.ts`)

- `GET /api/monitor`
- `PUT /api/monitor/focus`
- `GET/POST/DELETE /api/favorites` (server favorites — same as iOS, drives WARM tier)

### Hook (`web/src/hooks/useMonitor.ts`)

- Loads monitor payload on mount
- Polls every **30s** while Monitor tab is active (matches iOS)
- `setFocusSector`, `addFavorite`, `removeFavorite` refresh monitor state
- Computes **top 5m movers** from Hot + Warm rows client-side

### UI (`web/src/views/WatchlistView.tsx`)

| Section | Content |
|---------|---------|
| Toolbar | Favorites count, focus sector picker |
| Top movers | Chips for top 5 Hot/Warm 5m moves |
| Hot / Warm / Cold | Tier sections with price, 1D%, 5m%, live dot |
| Detail banner | 1D / 5M / 15M / 30D, tier label, remove favorite |
| Search | Add tickers via server `/api/favorites` |

Tab bar label changed: **Watchlist → Monitor** (tab id `watchlist` unchanged).

### Styling

`web/src/views/WatchlistView.css` — monitor-specific layout (grid rows, mover chips, focus menu, detail stats).

## Data flow

```
Finnhub quote_scheduler → snapshots (5m/15m)
monitor_tiers.py → HOT/WARM/COLD
GET /api/monitor → useMonitor (30s poll) → Monitor tab
```

Separate from:

```
session_intelligence → build_pulse_analysis_packet → Groq → AI tab
```

## Deploy

```bash
cd web && ./deploy/deploy.sh
```

Verify:

```bash
curl -s https://api.tryan.app/api/monitor | head -c 400
```

Open https://tryan.app → **Monitor** tab during market hours for 5m columns.

## Files changed

- `web/src/lib/api.ts`
- `web/src/hooks/useMonitor.ts` (new)
- `web/src/views/WatchlistView.tsx`
- `web/src/views/WatchlistView.css`
- `web/src/App.tsx`
- `web/src/components/TabBar.tsx`

## Notes

- Favorites on Monitor use **server** `/api/favorites` (not session cookies) so WARM tier matches iOS.
- Off-hours, 5m may be empty and quote_source may show `daily_bar` — expected.
- No backend or AI pipeline changes in this work.
