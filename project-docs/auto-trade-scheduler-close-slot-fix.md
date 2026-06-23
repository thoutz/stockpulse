# Auto-Trade Scheduler — Close Slot Fix

**Date:** June 9, 2026

## Problem

The close auto-trade cron ran at **16:15 ET**, but regular market hours end at **16:00 ET** (auto-trade guard allows until 16:05). Every close-slot run returned `market_closed` and never submitted orders.

Production evidence (`GET /api/trading/status`):

```json
"last_auto_trade_run": {
  "status": "skipped",
  "reason": "market_closed"
}
```

## Fix

1. **Chain auto-trade after each pulse** — `run_pulse_report()` now calls `run_auto_trade_cycle()` immediately after the pulse report is committed (open / midday / close). Close pulse at 16:00 typically finishes while the market is still open.
2. **Close backup cron → 16:05 ET** — last in-market minute instead of 16:15.
3. **Status API schedule** — `auto_trade_schedule_et` now lists `after each pulse`, `10:15`, `13:15`, `16:05`.

## Files changed

| File | Change |
|------|--------|
| `services/ai_jobs.py` | `_maybe_run_auto_trade_after_pulse()` after pulse commit |
| `main.py` | Close cron `16:15` → `16:05` |
| `services/auto_trade_state.py` | Schedule metadata updated |

## How auto-trade runs (paper)

Guards (all must pass):

- `AUTO_TRADE_ENABLED=true` (env or runtime toggle via `POST /api/trading/auto`)
- `TRADING_ENABLED=true`, `ALPACA_PAPER=true`
- Weekday, 9:30–16:05 ET
- WATCH candidates from `buying_signals` → risk engine → fractional buy ($5 default)

Dedup: `trading_proposal_guard.py` skips symbols with recent `proposed`/`submitted`/`filled` within `PROPOSE_COOLDOWN_HOURS` (4h).

## Verify

```bash
curl -s https://api.tryan.app/api/trading/status | python3 -m json.tool
ssh mspclientpro 'cd /opt/stockpulse-api && ./venv/bin/python scripts/run_auto_trade.py'
```

During market hours with WATCH signals, expect `status: ok` and `executed: N`.
