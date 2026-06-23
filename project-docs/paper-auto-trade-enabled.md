# Paper Auto-Trade Enabled + Proposal Guard

**Date:** June 17, 2026

## Changes

### Auto-trade ON (paper)
- `AUTO_TRADE_ENABLED=true` on server via `push_alpaca_env_to_vps.sh`
- Scheduled runs: **10:15, 13:15, 16:15 ET** (after each pulse)
- Up to **3 positions** per cycle (fills empty slots from WATCH list)

### Smaller default orders
- `DEFAULT_TRADE_NOTIONAL=5` (Alpaca fractional minimum remains $1 via `MIN_FRACTIONAL_NOTIONAL`)

### WATCH → proposal confidence fix
- Score 15 (WATCH threshold) now maps to **0.75** confidence (passes `min_confidence`)
- Previously score 15 → 0.5 and proposals were silently rejected

### Proposal deduplication
- New `services/trading_proposal_guard.py`
- Skips symbols with `proposed` / `submitted` / `filled` in last **4h** (`PROPOSE_COOLDOWN_HOURS`)
- Applies to **Scan WATCH** and **auto-trade** — prevents duplicate DB rows from repeated taps

### iOS Trade tab
- **Scan WATCH** hidden when `autoTradeEnabled` is true
- Copy explains auto schedule (10:15 / 1:15 / 4:15 ET)

### Scripts
- `scripts/run_auto_trade.py` — manual one-shot cycle on server
- `push_alpaca_env_to_vps.sh` now syncs `AUTO_TRADE_ENABLED` from local `.env` (no longer hardcoded false)

## How it works

1. Pulse reports generate Research Watchlist (Groq + `buying_signals`)
2. Auto-trade job reads WATCH candidates → fractional **$5** market buys on Alpaca Paper
3. Positions / cash flow appear on Trade tab after fills

## Market hours

Auto-trade **only runs 9:30 AM–4:05 PM ET** on weekdays. Outside that window, `run_auto_trade.py` returns `market_closed`.

## Verify

```bash
curl -s https://api.tryan.app/api/trading/status
# auto_trade_enabled: true, paper: true
# last_auto_trade_run: { at, status, reason, executed, skipped_symbols }
# next_auto_trade_run_at: ISO timestamp (10:15 / 13:15 / 16:15 ET)

ssh mspclientpro 'cd /opt/stockpulse-api && ./venv/bin/python scripts/run_auto_trade.py'
```

## Trade tab — last run status (Jun 17)

`GET /api/trading/status` includes:
- `last_auto_trade_run` — persisted after each cron/manual cycle
- `next_auto_trade_run_at` — next 10:15 / 13:15 / 16:15 ET slot
- iOS **Auto-trade status** card on Trade tab when auto-trade is on

## Note on results

Paper auto-trade executes research-backed WATCH signals — it does not guarantee positive P/L. Monitor Positions and Today P/L on the Trade tab after the next market session.
