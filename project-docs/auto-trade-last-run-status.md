# Auto-Trade Last Run Status on Trade Tab

**Date:** June 20, 2026

## Problem

User could not tell whether paper auto-trade had run, skipped, or submitted orders without SSH to the server.

## Solution

### Backend

- New `services/auto_trade_state.py`:
  - Persists each cycle result to `data/last_auto_trade_run.json`
  - Computes `next_auto_trade_run_at` (10:15 / 13:15 / 16:15 ET)
- `run_auto_trade_cycle()` records outcome after every cron/manual run
- `GET /api/trading/status` adds:
  - `last_auto_trade_run` — `{ at, status, reason, executed, skipped_symbols }`
  - `next_auto_trade_run_at`
  - `auto_trade_schedule_et`

### iOS

- `APIAutoTradeLastRun` model in `StockPulseAPIService.swift`
- **Auto-trade status** card on `TradeDashboardView` when auto-trade is on:
  - Green = orders submitted
  - Orange = skipped (market closed, no WATCH signals, etc.)
  - Red = failed
  - Shows last run time and next scheduled slot

### Tests

- `tests/test_auto_trade_state.py`

## Deploy

Rsync + `systemctl restart stockpulse-api`. Seed with:

```bash
./venv/bin/python scripts/run_auto_trade.py
```

## Example status payload

```json
"last_auto_trade_run": {
  "at": "2026-06-19T23:49:04-04:00",
  "status": "skipped",
  "reason": "market_closed",
  "executed": 0,
  "skipped_symbols": []
},
"next_auto_trade_run_at": "2026-06-22T10:15:00-04:00"
```

Rebuild iOS app to see the new card on the Trade tab.
