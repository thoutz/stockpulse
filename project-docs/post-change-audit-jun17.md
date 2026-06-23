# Post-Change Audit — Jun 17, 2026

## Symptoms reported

1. **No AI analyst report at 10 AM** + TLS error in app
2. **Trade tab** — no visible paper cash; wanted auto paper trading

---

## Root causes (verified)

### AI reports — server OK, office network blocked fetch

- Production generated `pulse_open` at **10:00:02 ET** on Jun 17 (title: RDW surge / space sector; includes **SPCX** favorite).
- Groq budget healthy (~5k / 85k tokens used).
- **Office Wi-Fi (SonicWall)** blocks `api.tryan.app` TLS → iOS URLError -1200.
- **Cellular works** — report appeared immediately when Wi-Fi was off.

### Trade tab — three issues

| Issue | Fix |
|-------|-----|
| Same TLS block on office Wi-Fi | iOS network hint + resilient digest fetch |
| Alpaca paper account **$0** cash/equity | User must **reset paper account** at [app.alpaca.markets](https://app.alpaca.markets) (~$100k default) |
| `get_account_activities` missing on `TradingClient` | Fixed: REST `/account/activities` + orders fallback |

### Auto-trading — was not implemented

- `AUTO_TRADE_ENABLED` was env-only with no scheduler.
- Implemented `trading_jobs.py` + cron at 10:15 / 13:15 / 16:15 ET (paper only).

---

## Code changes

### Server (`stockpulse-api`)

| File | Change |
|------|--------|
| `services/alpaca_service.py` | `fetch_activities` via REST; `is_auto_trade_enabled()` in status |
| `services/trading_settings.py` | Runtime auto-trade toggle |
| `services/trading_jobs.py` | `run_auto_trade_cycle()` — WATCH proposals → auto execute |
| `routers/trading.py` | Isolated dashboard fetches; `POST /api/trading/auto` |
| `main.py` | Auto-trade cron jobs; fixed `news_ingest_interval_minutes` import |

### iOS

| File | Change |
|------|--------|
| `StockPulseViewModel.swift` | `syncAssistantFeed()` runs even if dashboard fails; TLS -1200 hint |
| `TradeDashboardView.swift` | Paper $0 banner; AUTO TRADE badge; paper-focused setup copy |

### Production deploy

- API rsynced to `mspclientpro:/opt/stockpulse-api/`
- `AUTO_TRADE_ENABLED=true` on VPS (paper only)
- Fixed startup crash from missing `news_ingest_interval_minutes` import

---

## User actions required

### 1. Office network (AI + Trade + all tabs)

Whitelist on SonicWall CFS:
- `api.tryan.app`
- `tryan.app`, `www.tryan.app`

Or use **cellular** when testing.

### 2. Alpaca paper balance

1. Log into Alpaca → **Paper Trading**
2. **Reset paper account** (or confirm ~$100,000 balance)
3. Verify on server:
   ```bash
   ssh mspclientpro 'cd /opt/stockpulse-api && ./venv/bin/python scripts/verify_alpaca.py'
   ```
4. Rebuild iOS app; open Trade tab on cellular — expect cash ~$100k

### 3. Rebuild iOS

Xcode → Clean Build Folder → Run (for TLS hint, resilient AI feed, Trade banners).

---

## Verification checklist

```bash
# From cellular or whitelisted network
curl -s https://api.tryan.app/api/health
curl -s https://api.tryan.app/api/trading/status
# Expect: connected=true, paper=true, auto_trade_enabled=true

curl -s "https://api.tryan.app/api/ai/digest?days=1" | jq '.days[-1].reports[] | select(.report_type=="pulse_open") | .title'

# After paper reset
curl -s https://api.tryan.app/api/trading/dashboard | jq '.account.cash'
```

**iOS on cellular:**
- AI tab → today's Open report visible
- Trade tab → paper cash > $0 after Alpaca reset
- AUTO TRADE badge when `auto_trade_enabled=true`

**Auto-trade:** runs at 10:15 / 13:15 / 16:15 ET on weekdays when market open, buying power ≥ default notional, and WATCH proposals pass risk engine.

---

## Integration status (Jun 16–17 work)

| Feature | Status |
|---------|--------|
| AI favorites in pulses | Working in prod |
| Research Watchlist | Working (fresh pulses) |
| Alpaca Trade tab | Connected; cash needs paper reset |
| Auto-trade scheduler | Deployed (`AUTO_TRADE_ENABLED=true`) |
| Office TLS | Environmental — whitelist or cellular |
| Web Monitor/Research | Co-deploy web if not already live |
