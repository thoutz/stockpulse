# Unified Monitor Universe + Smarter Auto-Trader

**Date:** June 9, 2026

## Goal

One list drives everything: **Monitor = analyze + pulse + trade**. Retire HOT/WARM/COLD as gates. Paper trader acts on all data with clear rejection reasons.

## Changes

### 1. Monitor universe (`services/monitor_universe.py`)

- `monitored_symbols()` = `TICKERS` env seed + user **favorites** (same as quote ingest)
- Used by **buying_signals** and **micro_trading** — AMD and all config tickers included

### 2. Research signals (`buying_signals.py`)

- Candidates = **all monitored symbols** (+ catalyst ripples)
- Tier labels kept for scoring tags only, not eligibility

### 3. Micro trader (`micro_trading.py`)

**Entry** (any Monitor symbol, skip AVOID):
- WATCH score
- Intraday mover intel
- 5m momentum (+0.25% … +2.5%)
- 15m momentum (+0.35%+)
- Slow grind: green day + 5m ≥ +0.10%
- Favorite on green day

**Pre-flight:** Alpaca **fractionable** check before submit (skips SPCX-style rejects)

**Exit:**
- Take profit / stop loss (unchanged)
- **Momentum flip:** sell when 5m ≤ −0.15%
- EOD flat 3:55 PM

### 4. Rejection logging (`trade_execution.py`)

- Trade log stores `REJECTED: reason` in **rationale**
- iOS Trade tab shows rationale under each log row (red for rejected/failed)

### 5. Config additions

```env
MICRO_MIN_MOMENTUM_15M_PCT=0.35
MICRO_SLOW_GRIND_5M_PCT=0.10
MICRO_MOMENTUM_FLIP_5M_PCT=-0.15
```

## Files

| File | Change |
|------|--------|
| `services/monitor_universe.py` | New — single universe |
| `services/buying_signals.py` | All monitored candidates |
| `services/micro_trading.py` | Smarter enter/exit |
| `services/trade_execution.py` | Rejection rationale |
| `services/micro_trading_jobs.py` | Flip exits + logging |
| `services/trading_jobs.py` | Rejection logging |
| `ios/.../TradeDashboardView.swift` | Trade log rationale |

## Verify

```bash
curl -s https://api.tryan.app/api/trading/status
# trading_universe: all_monitor_symbols (via micro config payload)

ssh mspclientpro 'cd /opt/stockpulse-api && ./venv/bin/python scripts/run_micro_trade.py'
```

Rebuild iOS for trade log detail + updated micro copy.

## Next (optional)

- Groq structured BUY/HOLD/SELL per symbol
- Position sizing from confidence (not fixed notional)
- Paper performance stats (win rate, weekly P/L)
