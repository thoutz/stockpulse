# Session Intelligence Phase 2 — Catalog, Catalysts, Provider Health

**Date:** June 13, 2026

## Summary

Extended the Python automation layer with DB-backed catalyst catalogs, provider health monitoring, tier-priority news ingest, ops scripts, and pytest coverage.

## Catalyst catalog (DB-backed)

### New tables

| Table | Purpose |
|-------|---------|
| `catalyst_events` | Catalyst ticker, event name/date, confidence score, source |
| `catalyst_ripples` | Ripple pairs per event with backtest hit_rate / avg_post_pct |

### New module

[`services/catalyst_catalog.py`](server/stockpulse-api/services/catalyst_catalog.py)

- Seeds from built-in `CATALYSTS` on first startup
- `load_catalysts(session)` — used by pulse packets, dashboard, session intelligence
- `ripple_engine.analyze_ripples()` now accepts optional catalyst list

### API

```
GET /api/catalog/sectors
GET /api/catalog/catalysts
```

iOS/web can consume these instead of hardcoded catalogs over time.

### Scripts

| Script | Purpose |
|--------|---------|
| `scripts/seed_catalysts.py` | Manual seed from builtin |
| `scripts/backtest_ripple.py` | Compute confidence scores on historical bars |
| `scripts/discover_catalysts.py` | Propose events from AV earnings + sector peers (`--apply` to insert) |

## Provider health

[`services/provider_health.py`](server/stockpulse-api/services/provider_health.py)

- Tracks stale quotes by tier (HOT >2m, WARM >5m, COLD >10m)
- Estimates Finnhub calls/min vs Massive 5/min limit
- Counts quote ticks in last hour, stale daily bars

```
GET /api/health/providers
make provider-health   # CLI JSON report
```

APScheduler job every 30 min logs warnings when degraded.

## News ingest

[`news_ingest.py`](server/stockpulse-api/services/news_ingest.py) now rotates **HOT → WARM → COLD** symbols so focused-sector tickers get news first.

## Ops tooling

Root [`Makefile`](Makefile):

```bash
make test              # pytest
make check-env         # validate .env
make seed-catalysts
make backfill-quotes
make provider-health
make backtest
make discover          # dry run
make discover-apply    # insert earnings proposals
```

Added `pytest` + `pytest-asyncio` to `requirements.txt`.

Tests in `tests/` cover ripple verdicts, indicators, monitor tier resolution (11 tests).

## Deploy

```bash
rsync -avz --exclude venv --exclude __pycache__ server/stockpulse-api/ mspclientpro:/opt/stockpulse-api/
ssh mspclientpro 'cd /opt/stockpulse-api && ./venv/bin/pip install -r requirements.txt && systemctl restart stockpulse-api'
```

Verify:

```bash
curl https://api.tryan.app/api/catalog/catalysts
curl https://api.tryan.app/api/health/providers
```

Optional post-deploy:

```bash
make backtest   # on server, updates confidence_score on catalyst events
```

## Not in this phase

- APNs push dispatcher (`delivered_push` still false — no APNs keys in repo)
- iOS/web switching to `/api/catalog/*` (API ready, clients unchanged)
