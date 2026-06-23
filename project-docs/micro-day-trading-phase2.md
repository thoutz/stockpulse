# Micro Day-Trading Phase 2

**Date:** June 9, 2026

## Goal

Hands-off **intraday micro trading** on Alpaca Paper: scan for short-term momentum, enter with larger notional, auto **take-profit** / **stop-loss**, flat before the close. Runs alongside pulse WATCH auto-trade.

## Behavior

| Feature | Default |
|---------|---------|
| Scan interval | Every **5 min** (market hours) |
| Entry size | **$50** fractional (`MICRO_TRADE_NOTIONAL`) |
| Take profit | **+0.75%** unrealized (`MICRO_TAKE_PROFIT_PCT`) |
| Stop loss | **−0.50%** (`MICRO_STOP_LOSS_PCT`) |
| Daily profit cap | **+$50** — no new entries after hit |
| Entry cutoff | **3:45 PM ET** — no new buys |
| EOD flat | **3:55 PM ET** — sell all open positions |
| Re-entry cooldown | **30 min** per symbol |
| Max positions | **3** (shared with pulse auto-trade) |

## Entry logic (`services/micro_trading.py`)

Universe: **HOT / WARM** monitor tiers + favorites.

Requires:
- 5m change between **+0.25%** and **+2.5%** (not chasing extended spikes)
- 15m not strongly negative
- Not on **AVOID** list from `buying_signals`
- **WATCH** bonus score
- Passes risk engine + Alpaca fractionable check

## Exit logic

Every scan (before entries):
1. **Take profit** if position unrealized P/L % ≥ TP
2. **Stop loss** if ≤ −SL
3. **EOD flat** at 3:55 PM — closes all longs

## Files added

| File | Purpose |
|------|---------|
| `services/micro_trading.py` | Scanner + exit evaluation |
| `services/micro_trading_jobs.py` | Scheduled cycle (buy + sell) |
| `services/micro_trade_state.py` | Last run JSON for API / iOS |
| `scripts/run_micro_trade.py` | Manual one-shot on VPS |
| `tests/test_micro_trading.py` | TP/SL/cap unit tests |

## Scheduler

`main.py` — `run_micro_trade_cycle` every `MICRO_SCAN_INTERVAL_MINUTES` (default 5).

Requires: `MICRO_TRADE_ENABLED=true`, `AUTO_TRADE_ENABLED=true`, `TRADING_ENABLED=true`, `ALPACA_PAPER=true`.

## API / iOS

`GET /api/trading/status` adds:
- `micro_trade_enabled`, `micro_trade_notional`, TP/SL, cap
- `last_micro_trade_run` — `{ entries, exits, status, reason }`

Trade tab: **MICRO DAY-TRADE** card (blue border) below auto-trade status.

Positions from micro buys show **AUTO** badge (signal `micro_momentum`).

## Env (paper)

```env
MICRO_TRADE_ENABLED=true
MICRO_SCAN_INTERVAL_MINUTES=5
MICRO_TRADE_NOTIONAL=50
MICRO_TAKE_PROFIT_PCT=0.75
MICRO_STOP_LOSS_PCT=0.50
MICRO_DAILY_PROFIT_CAP_USD=50
```

## Deploy

```bash
rsync -avz --exclude venv --exclude __pycache__ --exclude .env \
  server/stockpulse-api/ mspclientpro:/opt/stockpulse-api/
./server/stockpulse-api/scripts/push_alpaca_env_to_vps.sh
ssh mspclientpro 'systemctl restart stockpulse-api'
```

## Verify

```bash
curl -s https://api.tryan.app/api/trading/status | python3 -m json.tool
ssh mspclientpro 'cd /opt/stockpulse-api && ./venv/bin/python scripts/run_micro_trade.py'
```

During market hours with momentum on HOT tickers, expect `entries: 1` or `exits: 1` in last run.

## iOS

Rebuild app to see **MICRO DAY-TRADE** card. Server runs micro trading without app open.

## Paper → live

Only after several weeks of positive paper stats. Live requires `ALPACA_PAPER=false` and separate keys — micro jobs are **paper-only** today (same guard as pulse auto-trade).
