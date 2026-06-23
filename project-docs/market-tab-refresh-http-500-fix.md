# Market Tab Refresh HTTP 500 Fix

**Date:** June 9, 2026

## Symptom

Manual refresh on the Market tab showed `Could not generate market brief: Server error (HTTP 500)` — especially noticeable off Wi‑Fi (cellular).

## Cause

Market refresh calls `POST /api/ai/chat` to regenerate the brief. The server had no error handling around Groq/context failures, so exceptions surfaced as **HTTP 500**. The app then replaced the market brief with that raw error.

## Fixes

### Server (`routers/ai.py`)
- Wrapped `/api/ai/chat` in try/except
- Returns **503** with a clear `detail` message instead of an unhandled 500

### iOS
- **`applyMarketBriefFallback`**: on chat failure → latest server pulse report → cached brief → friendly connection message (does not persist error text)
- **`refreshMarketTab`**: if dashboard refresh fails, still attempts `syncAssistantFeed()` so pulse reports are available for fallback
- **`StockPulseAPIError`**: parses FastAPI `detail` JSON; user-friendly copy for 500/502/503

## User expectation after rebuild

- Prices may still refresh even if live AI brief fails
- Market brief falls back to the latest **pulse report** from the server when chat is unavailable
- Error copy mentions connection instead of raw HTTP codes

## Server deploy

Redeploy `stockpulse-api` for the 503 handling. iOS fallback works even before deploy.
