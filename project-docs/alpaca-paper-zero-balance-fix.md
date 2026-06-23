# Alpaca Paper $0 Balance — Trade Tab Fix

**Date:** June 17, 2026

## Symptom

Trade tab shows **$0.00** cash/portfolio even though user expects ~$100,000 paper money.

## Diagnosis

Production API returns real Alpaca data — not an app display bug:

```
Account PA3U8O5MYTQG — equity $0, cash $0, buying_power $0
Created: 2026-06-17T02:40:07Z (late Jun 16 ET)
Orders: 0 | Positions: 0 | last_equity: $0
```

Same result from local `verify_alpaca.py` with the same API keys. The linked **paper account was created with $0** and has never held simulated cash — money did not drain from trades.

**Likely what happened:** Alpaca’s default paper account often starts with ~$100k. Last night a **new** paper account (`PA3U8O5MYTQG`) was opened and new API keys were linked to the server, but the new account was funded at **$0** (or the old funded account was switched away from). The app and server now point at the empty account.

Check the **account switcher** (top left in Alpaca Paper dashboard) for other paper accounts — one may still show ~$100k while API keys point at `PA3U8O5MYTQG`.

## Fix (user steps)

1. Go to [app.alpaca.markets](https://app.alpaca.markets) → switch to **Paper Trading**
2. Click **account number** (top left) → **Open New Paper Account**
3. Set starting balance to **$100,000**
4. **API Keys** → generate **new Paper** keys (old keys stop working if you delete the old paper account)
5. Update `server/stockpulse-api/.env`:
   ```env
   ALPACA_API_KEY=PK...
   ALPACA_SECRET_KEY=...
   ALPACA_PAPER=true
   ```
6. Push to VPS:
   ```bash
   cd server/stockpulse-api
   bash scripts/push_alpaca_env_to_vps.sh
   ```
7. Verify:
   ```bash
   ssh mspclientpro 'cd /opt/stockpulse-api && ./venv/bin/python scripts/verify_alpaca.py'
   ```
   Expect **Cash: $100,000.00**
8. Rebuild iOS, open Trade tab on **cellular** (office Wi-Fi may block API)

## App changes

| File | Change |
|------|--------|
| `alpaca_service.py` | `account_number`, `needs_paper_funding` on account summary |
| `routers/trading.py` | Status message when paper account needs funding |
| `StockPulseAPIService.swift` | Decode new fields |
| `TradeDashboardView.swift` | Step-by-step funding banner with account number |

## Note

If cash cards show **$0.00** with an orange banner, the app is working — Alpaca account needs funding via dashboard.

If Trade tab shows **SSL error** or no data at all, use cellular or whitelist `api.tryan.app` on office firewall.

---

## Resolution — Jun 17, 2026 (new keys)

User created new paper account and updated `server/stockpulse-api/.env` lines 20–21.

Ran `bash scripts/push_alpaca_env_to_vps.sh` → production verified:

| Field | Value |
|-------|-------|
| Account | `PA3W6EDPCJBO` |
| Cash / equity | **$1,000.00** |
| `needs_paper_funding` | `false` |
| Production `/api/trading/status` | Connected, paper, trading enabled |

Note: starting balance was **$1,000** (not $100k). For $100k, open another paper account in Alpaca with that starting amount and repeat key update + push.

`push_alpaca_env_to_vps.sh` sets `AUTO_TRADE_ENABLED=false` on VPS; re-enable in `.env` + push if auto paper trading is desired.
