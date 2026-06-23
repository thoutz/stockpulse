# StockPulse Web Frontend

**Date:** June 16, 2026

## Summary

Built and deployed a Vite + React + TypeScript web app at **https://tryan.app** that mirrors the iOS StockPulse UI (5 tabs, dark design system). The app reads live data from **https://api.tryan.app** and stores per-browser watchlist favorites via anonymous session cookies.

## What was built

### Frontend (`web/`)

| Area | Details |
|------|---------|
| Stack | Vite 5, React 18, TypeScript |
| Fonts | DM Sans + IBM Plex Mono (Google Fonts) |
| Design tokens | Ported from `ios/StockPulse/Utilities/DesignSystem.swift` → `web/src/styles/tokens.css` |
| Tabs | Ripple, Watchlist, Trends, Market, AI — matches `RootView.swift` |
| Data | `GET /api/dashboard` + 60s refresh via `useDashboard` hook |
| Static catalogs | `web/src/data/catalysts.ts`, `industries.ts` from iOS catalogs |

### Backend additions

| Change | File |
|--------|------|
| `session_favorites` table | `server/stockpulse-api/models/db_models.py` |
| Session favorites API | `server/stockpulse-api/routers/session.py` |
| Cookie helper | `server/stockpulse-api/services/session.py` |
| CORS for credentials | `server/stockpulse-api/main.py` — explicit origins for tryan.app |
| Bugfix (pre-existing) | `services/market_stats.py` — corrupted import/function line |

### Session favorites (no login)

- Cookie: `sp_session` (HttpOnly, Secure, SameSite=Lax, 1 year)
- Endpoints: `GET/POST/DELETE /api/session/favorites`
- iOS global `/api/favorites` unchanged
- Web client uses `credentials: "include"` for session routes

## Deployment

| Host | Path | Service |
|------|------|---------|
| `tryan.app` | `/var/www/tryan.app` | Nginx static SPA |
| `api.tryan.app` | `/opt/stockpulse-api` | FastAPI :8002 |

### Deploy commands

```bash
# Web
cd web && npm ci && npm run build
./deploy/deploy.sh

# API (after backend changes)
rsync -avz --exclude venv --exclude __pycache__ server/stockpulse-api/ mspclientpro:/opt/stockpulse-api/
ssh mspclientpro 'systemctl restart stockpulse-api'
```

### Nginx

- Config: `web/deploy/nginx-tryan.app.conf`
- TLS: Certbot cert for `tryan.app` + `www.tryan.app` (expires 2026-09-14)

### DNS (already correct — no CNAME needed)

- `@` A → `45.63.64.79`
- `www` CNAME → apex
- `api` A → `45.63.64.79`

## Dev workflow

```bash
cd web
npm install
npm run dev   # http://localhost:5173, proxies /api → api.tryan.app
```

Production build sets `API_BASE` to `https://api.tryan.app` automatically.

## CSS / color scheme

All colors match iOS `DesignSystem.swift`:

- Background: `#060a0f`
- Surface: `#0d1117`, `#111827`
- Accent blue: `#60a5fa`
- Green/orange/red for market direction and verdicts
- Chart palette: orange, green, blue, purple, coral, teal

Responsive: bottom tab bar on mobile, left sidebar on desktop (≥768px).

## AI tab (iOS parity — updated June 16, 2026)

Matches `AssistantFeedView.swift` + `AIAnalystView.swift`:

| Feature | Implementation |
|---------|----------------|
| Digest range picker | Dropdown: 1 day / 3 days / 7 days (default 1 day) |
| Section tabs | Reports \| Alerts (not a mixed flat feed) |
| Reports layout | Expandable days → session slots (Open 10am, Midday 1pm, Close 4pm ET) |
| Alerts layout | Expandable days → bell rows with symbol, %, message |
| Report body | `StructuredReportBody` — What's New + collapsible Context |
| Syntax highlighting | `HighlightedReportText` — tickers, verdicts, %, headings |
| Chat | Suggestion chips → textarea → Analysis card with highlighted response |
| Status label | "Server assistant + data" / "Waiting for market data" |
| Sync | Fetches `/api/ai/digest?days=7`, fallback to individual endpoints |

Files: `web/src/components/AssistantFeedView.tsx`, `HighlightedReportText.tsx`, `web/src/lib/digest.ts`


```bash
curl -s https://tryan.app/ | head
curl -s https://api.tryan.app/api/health
curl -s https://api.tryan.app/api/session/favorites
```

## Notes

- API restart triggers a ~30–40s Massive warm-up before `/api/health` responds.
- Session cookies require cross-origin CORS with credentials from `tryan.app` → `api.tryan.app`.
- Web favorites are per-browser session; they do not sync with iOS global favorites.
