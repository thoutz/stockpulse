# Alerts 50-item sliding window

**Date:** June 10, 2026

## Behavior

- UI and API show at most **50 most recent** alerts (newest first).
- On each alert job cycle (~10 min), the server **deletes** older rows so the DB stays at 50.
- New alerts appear on sync; oldest visible alert drops off when count exceeds 50.

## Changes

- `config.py`: `alerts_retain_count = 50`
- `ai_jobs.py`: `prune_old_alerts()` after `run_movement_alerts`
- `routers/ai.py`: digest + `/api/ai/alerts` capped at 50
- iOS: `alertsDisplayLimit = 50` in `StockPulseViewModel` + `StockPulseAPIService`

## Deploy

Redeploy `stockpulse-api`; first movement-alerts run (or manual prune) clears ~1300 legacy rows down to 50.
