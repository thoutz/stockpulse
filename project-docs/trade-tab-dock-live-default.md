# Trade tab dock order + live trading default

**Date:** June 9, 2026

## Tab bar order

Left → right:

Ripple · Monitor · Trends · Market · **Trade** · AI

`AppTab`: `trade = 4`, `ai = 5`  
`RootView.swift`: Trade tab inserted immediately before AI.

## Real money (live) default

Server defaults changed from paper to **live**:

- `config.py`: `alpaca_paper=False`
- `.env` / `.env.example`: `ALPACA_PAPER=false`

**Paper is simulated money.** Live uses your funded Alpaca brokerage account.

### To go live

1. Complete Alpaca **live** account application at [app.alpaca.markets](https://app.alpaca.markets)
2. Generate **Live** API keys (not Paper keys)
3. Set on server (`api.tryan.app` + local `.env`):
   ```env
   ALPACA_API_KEY=live_key_id
   ALPACA_SECRET_KEY=live_secret
   ALPACA_PAPER=false
   TRADING_ENABLED=true
   ```
4. Fund via ACH in Alpaca dashboard
5. Verify: `python scripts/verify_alpaca.py --live`

### Trade tab UI

- **Alpaca Live · real money** — green banner when connected live
- **Alpaca Paper · simulated** — orange warning if server still on paper keys
- Setup banner when not connected — guides live key + ACH setup

API status includes `account_mode`: `"live"` | `"paper"`.
