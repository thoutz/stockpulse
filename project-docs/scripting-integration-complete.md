# Scripting Integration — Completion Runbook

**Date:** June 13, 2026

## Summary

This document is the operational guide for the **Python scripting integration** project: persisted session intelligence feeding the three daily Groq pulses, catalog/health APIs, and ops scripts.

**Definition of done:** Production runs the full pipeline; intelligence is inspectable via API and CLI; ops scripts are documented; one trading day validates three pre-pulse builds + three pulse reports.

---

## Architecture (target state)

```
Finnhub quotes → quote_ticks + snapshots (5m/15m)
Monitor tiers (HOT/WARM/COLD) → quote priority, news rotation, alerts
Pre-pulse job (09:55 / 12:55 / 15:55 ET) → session_intelligence table
build_pulse_analysis_packet → Groq → ai_reports (10:00 / 13:00 / 16:00 ET)
GET /api/intelligence/session/{date} → future reporting
```

---

## Deploy

### API (stockpulse-api)

```bash
rsync -avz --exclude venv --exclude __pycache__ --exclude .env \
  server/stockpulse-api/ mspclientpro:/opt/stockpulse-api/

ssh mspclientpro 'cd /opt/stockpulse-api && ./venv/bin/pip install -r requirements.txt && systemctl restart stockpulse-api'
```

Tables auto-create via `init_db()` on startup.

### Web (tryan.app)

Deploy together with API when catalog or intelligence routes changed (avoids partial-deploy 404s):

```bash
cd web && ./deploy/deploy.sh
```

### iOS

Rebuild when catalog sync or API client changes. Catalog updates alone can ship server-side without App Store if bundled fallbacks remain.

---

## Post-deploy (run once on server)

```bash
ssh mspclientpro
cd /opt/stockpulse-api

./venv/bin/python scripts/backfill_quote_windows.py   # restore 5m/15m after restart
./venv/bin/python scripts/seed_catalysts.py             # if catalyst_events empty
./venv/bin/python scripts/backtest_ripple.py           # optional: confidence_score on catalysts
./venv/bin/python scripts/provider_health.py           # Finnhub/Massive freshness
```

---

## Daily / weekly ops

| When | Command | Purpose |
|------|---------|---------|
| After each API deploy | `backfill_quote_windows.py` | Recompute snapshot 5m/15m from quote_ticks |
| Manual / catch-up | `make run-intelligence SLOT=open` | Force intelligence build for a slot |
| Manual / catch-up | `make run-intelligence SLOT=midday DATE=2026-06-13` | Specific date |
| Any time | `make provider-health` | JSON report of stale quotes by tier |
| After market close (optional) | `make backtest` | Refresh catalyst ripple confidence |
| Weekly (optional) | `make discover-apply` | Insert earnings proposals from AV calendar |

### Intelligence CLI

```bash
# Local or on server (requires DATABASE_URL)
make run-intelligence SLOT=open
make run-intelligence SLOT=midday DATE=2026-06-13

# Direct
cd server/stockpulse-api
.venv/bin/python scripts/run_session_intelligence.py --slot close --date 2026-06-13
```

Pre-pulse cron (automatic, ET):

| Job | Time | Slot |
|-----|------|------|
| `intel_open` | 09:55 | open |
| `intel_midday` | 12:55 | midday |
| `intel_close` | 15:55 | close |

If a pulse runs without pre-computed rows, `ai_jobs.py` builds intelligence on the fly before Groq.

---

## Verification

### Smoke test (from dev machine)

```bash
make verify-prod
# or
STOCKPULSE_API_BASE=https://api.tryan.app bash scripts/verify_production.sh
```

Expected: HTTP 200 on health, catalog, provider health, intelligence session endpoints.

### Manual curls

```bash
TODAY=$(TZ=America/New_York date +%Y-%m-%d)

curl -s https://api.tryan.app/api/health
curl -s "https://api.tryan.app/api/intelligence/session/${TODAY}/open" | head -c 500
curl -s https://api.tryan.app/api/health/providers | head -c 500
curl -s https://api.tryan.app/api/catalog/sectors | head -c 200
```

### One trading day checklist

| Time (ET) | Check |
|-----------|-------|
| ~10:00 | `GET .../intelligence/session/{today}/open` → `count > 0` |
| ~13:00 | Midday intelligence + `pulse_midday` report in `/api/ai/reports` |
| ~16:00 | Close intelligence + close pulse; close slot may include `data_quality` |
| Any | HOT snapshots have non-null `change_5m_pct` during market hours |

---

## Troubleshooting

### Movement alerts failing (`NameError: get_settings`)

Fixed in `services/ai_jobs.py` — missing `from config import get_settings`. Redeploy API if alerts stop firing.

### Intelligence count is 0

1. Confirm API deployed: `curl .../api/intelligence/session/{today}` not 404.
2. Run manual build: `make run-intelligence SLOT=open` on server.
3. Check quote data: `make provider-health` — HOT quotes stale >2m block reliable movers.
4. Confirm market day and snapshots exist: `/api/dashboard`.

### Catalog 404 on tryan.app

API not redeployed. Run API rsync + restart; web uses bundled fallbacks but Trends needs matching hook args.

### 5m/15m null after restart

Run `make backfill-quotes` on server (needs quote_ticks from prior hour).

### Local dev DB errors

Local `.env` may point at Postgres role `stockpulse` that does not exist. Use production server for ops scripts or fix local Postgres.

---

## Tests

```bash
make test              # pytest: ripple, indicators, monitor tiers, session intelligence
make check-env         # FINNHUB / GROQ / DATABASE warnings
```

---

## API reference

```
GET /api/intelligence/session/{YYYY-MM-DD}
GET /api/intelligence/session/{YYYY-MM-DD}/{open|midday|close}
GET /api/catalog/sectors
GET /api/catalog/catalysts
GET /api/health/providers
```

---

## Deferred (not required for scripting integration complete)

| Item | Notes |
|------|-------|
| `services/scoring.py` | Z-score alerts; alerts remain rule-based in `ai_jobs.py` |
| `GET /api/intelligence/movers` | Planned; use session rows or `/api/monitor` for now |
| APNs push | No keys; `delivered_push` stays false |
| Alembic / GitHub Actions CI | Optional hygiene |
| Research notebook | Threshold tuning only |

---

## Related docs

- `project-docs/session-intelligence-pipeline.md` — Phase 1 pipeline
- `project-docs/session-intelligence-phase-2.md` — Catalysts, provider health
- `project-docs/server-catalog-sync-ios-web.md` — Client catalog sync
- `project-docs/web-trends-flatmap-production-deploy.md` — Partial deploy fix

---

## Files added for completion

| File | Role |
|------|------|
| `server/stockpulse-api/scripts/run_session_intelligence.py` | Manual intelligence build |
| `server/stockpulse-api/tests/test_session_intelligence.py` | Unit tests |
| `scripts/verify_production.sh` | Production smoke checks |
| `Makefile` | `run-intelligence`, `verify-prod` targets |
