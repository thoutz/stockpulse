# Stale Ticker Sync & Hidden UI Messages

**Date:** June 13, 2026

## Symptom

Ripple tab showed two user-facing sync messages:
- Red: `Background sync in progress for: SPCX`
- Orange: `Background sync in progress (~2 min). Data may update shortly.`
- Header badge: `SYNCING`

Ticker tape also overlapped symbols onto prices (e.g. `$488.48 HWM`).

## Root cause

**Server:** After warm-up, `IngestScheduler.run_cycle` only ran name resolution and secondary tasks (minute / RSI / SMA). It never re-ran **daily bar backfill** for tracked symbols missing hot-window data. New favorites like `SPCX` depended on a one-shot `_backfill_favorite` at `POST /api/favorites`; if that failed or raced with rate limits, the symbol stayed in `stale_tickers` indefinitely while the 12s loop ignored it.

**iOS:** `applyDashboard` surfaced `dashboard.stale` as `refreshError`, and `RippleTrackerView` rendered an extra orange banner when `serverStale` was true.

## Fixes

### Server (`services/ingest.py`)

- Added `_pick_stale_daily_symbol()` — finds tracked symbols with zero bars in the 30-day hot window.
- `run_cycle` priority after warm-up:
  1. **Stale daily backfill** (1 Massive call, ~12s) — new favorites fill within one tick
  2. Name resolution (existing queue)
  3. Secondary indicator/minute rotation

Still respects the 5 calls/min budget (one call per 12s tick).

### iOS

| File | Change |
|------|--------|
| `StockPulseViewModel.swift` | Removed stale-ticker `refreshError`; removed warming-up message; header shows `SERVER` when live data exists (no `SYNCING` badge) |
| `RippleTrackerView.swift` | Removed red error line and orange background-sync banner |
| `TickerTapeView.swift` | Dynamic per-item width from ticker + price + change text (min 150pt) to prevent overlap |

## Deploy

```bash
cd "stock market app"
rsync -avz --exclude '.venv' --exclude venv --exclude __pycache__ --exclude '*.pyc' --exclude '.env' \
  server/stockpulse-api/ mspclientpro:/opt/stockpulse-api/
ssh mspclientpro 'systemctl restart stockpulse-api'
```

Rebuild the iOS app in Xcode for UI changes.

## Expected behavior

- Users see no background-sync messaging; existing data loads normally.
- New favorites (e.g. `SPCX`) backfill on the next ingest tick (~12s) without blocking on name resync.
- Ticker tape spacing adapts to wide prices like `$488.48`.
