# Web Trends flatMap Crash — Production Deploy Fix

**Date:** June 16, 2026

## Problem

On https://tryan.app, opening **Trends** (or clicking a range pill) crashed with:

```
TypeError: can't access property "flatMap", e is undefined
```

Concurrent 404s on startup:

- `GET /api/catalog/sectors`
- `GET /api/catalog/catalysts`

## Root cause (aligned with catalog-sync plan)

Partial deploy during **Session Intelligence Phase 2** + **server catalog sync** work:

| Layer | Repo state | Production (before fix) |
|-------|------------|-------------------------|
| `useTrendRangeData` | Requires `(dashboard, catalysts)` | Deployed — expects 2nd arg |
| `TrendsView` | Passes `catalysts` from `useCatalog()` | Stale bundle — called hook with dashboard only |
| `/api/catalog/*` | In `routers/catalog.py` | API not redeployed → 404 |

404s alone are handled by `useCatalog()` try/catch (bundled fallbacks). The white-screen was the TrendsView / hook mismatch.

## Fix (minimal — no plan changes)

1. **Web:** Redeploy current `web/` build (TrendsView already passes `catalog.catalysts` in source).
2. **Defensive guard:** `trendTickersFrom(catalystList ?? [])` so a future partial deploy cannot crash the app.
3. **API:** Redeploy `stockpulse-api` per `session-intelligence-phase-2.md` so catalog endpoints return JSON instead of 404.

No changes to iOS, dashboard design, session intelligence scripts, or DB schema.

## Deploy commands

```bash
# Web
cd web && ./deploy/deploy.sh

# API (catalog routes)
rsync -avz --exclude venv --exclude __pycache__ server/stockpulse-api/ mspclientpro:/opt/stockpulse-api/
ssh mspclientpro 'cd /opt/stockpulse-api && ./venv/bin/pip install -r requirements.txt && systemctl restart stockpulse-api'

# Verify
curl https://api.tryan.app/api/catalog/sectors
curl https://api.tryan.app/api/catalog/catalysts
```

## Files touched

- `web/src/lib/trendRange.ts` — null-safe `trendTickersFrom`
