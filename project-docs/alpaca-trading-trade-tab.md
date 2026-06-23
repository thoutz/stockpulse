# Alpaca Trading Integration + Trade Tab

**Date:** June 9, 2026

## Summary

Integrated Alpaca Trading API (paper/live) into `stockpulse-api` and added a **Trade** tab on iOS for portfolio monitoring, cash flow, WATCH-based proposals, and manual execution.

---

## Setup (you do this once)

### 1. Alpaca account + API keys

1. Sign up at [app.alpaca.markets](https://app.alpaca.markets)
2. Generate **Paper** API keys first (dashboard → API Keys)
3. For live money later: separate **Live** keys + ACH deposit in dashboard

### 2. Server `.env`

Add to `server/stockpulse-api/.env`:

```env
ALPACA_API_KEY=your_key_id
ALPACA_SECRET_KEY=your_secret
ALPACA_PAPER=true
TRADING_ENABLED=false
TRADING_API_SECRET=generate-a-long-random-string
AUTO_TRADE_ENABLED=false
DEFAULT_TRADE_NOTIONAL=12
```

Set `TRADING_ENABLED=true` only when ready to execute real/paper orders.

### 3. Verify connection (prints X-Request-ID)

```bash
cd server/stockpulse-api
.venv/bin/python scripts/verify_alpaca.py
# Live keys:
.venv/bin/python scripts/verify_alpaca.py --live
```

### 4. iOS `Config.xcconfig`

```xcconfig
TRADING_API_SECRET = same-as-server-TRADING_API_SECRET
```

Rebuild after adding. Required for Scan WATCH / Execute / Close.

### 5. Deploy

Deploy updated API to `api.tryan.app` with Alpaca env vars.

---

## Backend

| File | Purpose |
|------|---------|
| `config.py` | Alpaca + trading safety settings |
| `services/alpaca_client.py` | `TradingClient` wrapper |
| `services/alpaca_service.py` | Account, positions, orders, activities |
| `services/risk_engine.py` | Pre-trade validation |
| `services/trading_decision.py` | Proposals from `buying_signals` WATCH list |
| `routers/trading.py` | `/api/trading/*` |
| `models/db_models.py` | `TradeDecisionLog` audit table |
| `scripts/verify_alpaca.py` | Key verification + X-Request-ID |

### Endpoints

| Method | Path | Auth |
|--------|------|------|
| GET | `/api/trading/dashboard` | — |
| GET | `/api/trading/status` | — |
| GET | `/api/trading/account` | — |
| POST | `/api/trading/propose` | `X-Trading-Secret` |
| POST | `/api/trading/execute/{id}` | secret + `TRADING_ENABLED` |
| POST | `/api/trading/close/{symbol}` | secret + `TRADING_ENABLED` |

### Dependencies

- `alpaca-py>=0.39.0` in `requirements.txt`

---

## iOS

| File | Change |
|------|--------|
| `AppTab.trade` | New 6th tab |
| `Views/Trade/TradeDashboardView.swift` | Dashboard UI |
| `StockPulseAPIService.swift` | Trading API models + methods |
| `StockPulseViewModel.swift` | Trade state, refresh, execute |
| `RootView.swift` | Trade tab |
| `project.yml` / `Info.plist` | `TRADING_API_SECRET` |

### Trade tab sections

- Connection banner (paper/live, trading on/off)
- Portfolio / today P&L / cash / buying power
- Positions (AUTO badge for bot-tagged symbols)
- Proposals from WATCH signals → Execute
- Cash flow ledger (deposits, fills)
- Trade log

---

## Flow

1. Pulse + `buying_signals.py` produce WATCH tickers
2. **Scan WATCH** → `POST /propose` → `TradeDecisionLog` rows
3. **Execute** → risk engine → Alpaca notional market order
4. Activities + positions refresh on Trade tab

---

## Fractional trading ([Alpaca docs](https://docs.alpaca.markets/us/docs/fractional-trading))

All buys use **market DAY notional orders** (dollar amount, min $1). Sells use **fractional qty** or `close_position`.

| Rule | Implementation |
|------|----------------|
| Buy as little as $1 | `MIN_FRACTIONAL_NOTIONAL=1`, `normalize_notional()` |
| Notional **or** qty, never both | `submit_fractional_buy` / `submit_fractional_sell_qty` |
| Market orders only | `MarketOrderRequest` + `TimeInForce.DAY` |
| Check `fractionable=true` | `fetch_asset_eligibility()` before propose + execute |
| No fractional short | Long-only sells via position qty |
| Proposals skip non-fractionable tickers | `trading_decision.py` |

Module: `services/fractional_trading.py`  
Endpoint: `GET /api/trading/assets/{symbol}`

---

## Safety defaults

- `TRADING_ENABLED=false` until you opt in
- `ALPACA_PAPER=true` for testing
- Max 10% equity per trade, 3 positions, 75% min confidence
- Daily loss limit 5% blocks new buys

---

## Not included (future)

- Scheduled auto-trade job (`trading_jobs.py`)
- Groq structured trade JSON (uses rule-based WATCH for v1)
- Alpaca MCP (dev tool only — see prior plan)
