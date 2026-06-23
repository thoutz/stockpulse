# Admin Dashboard — Web App Monitoring Section

**Date:** June 20, 2026  
**Feature:** Password-protected admin section at `/admin` for monitoring StockPulse API, database, and symbol data.

---

## Overview

Added a hidden admin area to the web app (not linked from the main tab bar). Access via:

- **Local dev:** `http://localhost:5173/admin`
- **Production:** `https://tryan.app/admin`

Password is configured server-side via `ADMIN_PASSWORD` in `server/stockpulse-api/.env`.

---

## Backend Changes

### Config

- **`server/stockpulse-api/config.py`** — new `admin_password` setting (env: `ADMIN_PASSWORD`)

### New files

| File | Purpose |
|------|---------|
| `services/request_metrics.py` | In-memory API request counters (total, last hour, top paths) |
| `services/admin_stats.py` | Aggregates DB health/size, symbol inventory, provider health, Groq usage, scheduler state |
| `services/app_runtime.py` | Holds APScheduler reference to avoid circular imports |
| `routers/admin.py` | `POST /api/admin/login`, `GET /api/admin/dashboard` |

### Modified files

- **`main.py`** — `RequestMetricsMiddleware` records `/api/*` calls; registers admin router; sets scheduler in `app_runtime`
- **`.env.example`** — documents `ADMIN_PASSWORD`

### Auth pattern

- Login: `POST /api/admin/login` with `{ "password": "..." }`
- Protected routes: `X-Admin-Password` header (same value as `ADMIN_PASSWORD`)
- Returns 403 on invalid password, 503 if `ADMIN_PASSWORD` not set on server

### Dashboard payload sections

1. **api** — request counts since server start, last hour, top paths
2. **providers** — Finnhub/Massive health, stale quotes/bars, estimated external API calls/min
3. **database** — `SELECT 1` latency, `pg_database_size`, per-table row estimates and sizes
4. **symbols** — ticker/favorite counts, bar/snapshot/tick totals
5. **symbol_data** — per-symbol daily bar count, last bar date, hot-data flag
6. **groq** — daily token/chat budget usage
7. **scheduler** — job list, ingest warm-up status

---

## Frontend Changes

### Routing

- **`web/src/main.tsx`** — if pathname is `/admin`, renders `AdminView` instead of main `App` (no React Router added)

### New files

| File | Purpose |
|------|---------|
| `web/src/views/AdminView.tsx` | Login form + monitoring dashboard |
| `web/src/views/AdminView.css` | Admin-specific layout (uses existing design tokens) |
| `web/src/hooks/useAdminDashboard.ts` | Polls dashboard every 30s; stores password in `sessionStorage` |

### Modified files

- **`web/src/lib/api.ts`** — `adminLogin`, `adminDashboard` with `X-Admin-Password` header; TypeScript types for dashboard payload

### UI panels

- Summary stat cards (API requests, DB size, tracked symbols)
- Provider health with status badge and stale-symbol warnings
- Database health + table size breakdown
- Symbol inventory (config, favorites, bars, snapshots)
- Groq usage + scheduler status
- API traffic table (top paths last hour)
- Per-symbol data status table

### CSS

Uses existing tokens from `web/src/styles/tokens.css` (`--bg`, `--surface`, `--border`, `--blue`, etc.). No changes to main dashboard/tab bar styles.

---

## Environment Setup

Add to `server/stockpulse-api/.env`:

```env
ADMIN_PASSWORD=arlobicknell13
```

Restart the API server after changing this value.

For production deployment, set the same variable on the server hosting `api.tryan.app`.

---

## Deployment Notes

- **SPA routing:** `/admin` must serve `index.html` (same as other client routes). Ensure static host/nginx uses `try_files $uri /index.html` for the web app.
- **CORS:** Admin API calls use custom header `X-Admin-Password`; already allowed via `allow_headers=["*"]` on the API.
- **Security:** Admin is not in the public tab bar. Consider nginx IP allowlist for `/admin` in production if desired.

---

## How to Test

1. Set `ADMIN_PASSWORD` in API `.env` and restart API
2. Run web dev server: `cd web && npm run dev`
3. Open `http://localhost:5173/admin`
4. Sign in with the configured password
5. Confirm panels populate and refresh every 30 seconds

---

## Files Touched (summary)

**Backend:** `config.py`, `main.py`, `.env.example`, `routers/admin.py`, `services/admin_stats.py`, `services/request_metrics.py`, `services/app_runtime.py`

**Frontend:** `main.tsx`, `lib/api.ts`, `views/AdminView.tsx`, `views/AdminView.css`, `hooks/useAdminDashboard.ts`
