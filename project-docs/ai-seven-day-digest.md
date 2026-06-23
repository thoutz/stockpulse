# AI 7-Day Digest & 6-Month Data Retention

**Date:** June 9, 2026

## Summary

Concise upgrade to how users browse server AI analytics: a **7-day day picker** on the AI tab replaces the flat truncated feed. Server retains **180 days** (~6 months) of daily bars for richer AI context over time.

---

## Server

### Retention (`config.py`)
- `full_days`: `90` → `180` (~6 months daily bar retention before prune)

### New endpoint
`GET /api/ai/digest?days=7` (max 7)

Returns reports, alerts, and suggestions grouped by calendar day (UTC):

```json
{
  "days": [
    { "date": "2026-06-03", "reports": [], "alerts": [], "suggestions": [] },
    ...
  ]
}
```

File: `server/stockpulse-api/routers/ai.py`

---

## iOS

### API client
- `StockPulseAPIService.digest(days: 7)` → `APIDigest`

### ViewModel
- `aiDigestDays`, `selectedDigestDayKey`
- `syncAssistantFeed()` prefers digest API; falls back to individual list endpoints + client-side grouping (`DigestBuilder`)

### UI (`AssistantFeedView`)
- Renamed section: **7-Day Digest**
- Horizontal day chips: Today / Yesterday / weekday
- Unified timeline per day: REPORT · ALERT · SUGGESTION rows sorted by time
- No changes to other tabs or navigation

### New files
- `ios/StockPulse/Services/DigestBuilder.swift`

---

## Deploy note

Restart/redeploy `stockpulse-api` so `/api/ai/digest` is live. iOS falls back gracefully if the endpoint is missing.
