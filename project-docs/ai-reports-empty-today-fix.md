# AI Reports Empty for Today — Fix

**Date:** June 9, 2026

## Root causes

1. **UTC vs ET day buckets** — Server `/api/ai/digest` grouped reports by UTC date. iOS labeled days in US/Eastern. On June 9 evening ET, UTC can already be June 10, so the **1-day filter showed the wrong (empty) day**.

2. **Legacy report hidden** — The only June 9 report was a **3:41 AM** `pulse` from the old 30-min cron. iOS correctly hides off-hours legacy reports, so nothing appeared under session slots.

3. **No typed session reports yet** — `pulse_open`, `pulse_midday`, `pulse_close` only exist after the new server code is deployed and catch-up runs (needs `GROQ_API_KEY`).

## Fixes

### Server (`routers/ai.py`)
- Day keys now use **America/New_York** (matches iOS).
- Added `POST /api/ai/reports/catch-up` to generate missed slots for today without full restart.

### iOS
- `applyDigest` re-buckets all reports into **ET days** via `DigestBuilder.build`.
- **1-day view** always shows **ET today**, not UTC suffix.
- Today shows all **3 session slots** (Open / Midday / Close); empty slots say "Scheduled · not generated yet".

## After deploy

```bash
rsync -avz --exclude venv --exclude .venv --exclude __pycache__ server/stockpulse-api/ mspclientpro:/opt/stockpulse-api/
ssh mspclientpro 'systemctl restart stockpulse-api'
# Optional: force today's reports if restart catch-up didn't run
curl -X POST https://api.tryan.app/api/ai/reports/catch-up
```

Rebuild iOS app, pull to refresh AI tab. Expect Open + Midday reports if catch-up succeeds; Close at 4:00 PM ET.
