# Finnhub API Key Duplication Fix

**Date:** June 16, 2026

## Issue

Monitor tab live quotes and 5m move columns were not updating. Server logs showed **401 Unauthorized** on every Finnhub quote request.

Root cause: `FINNHUB_API_KEY` in `server/stockpulse-api/.env` was **duplicated** — the same 40-character token appeared twice concatenated (80 characters total). Finnhub rejected the invalid token on every call (~5,000+ failed attempts during the Jun 16 market session).

## Fix

1. Detected duplication: `val[:half] == val[half:]` on both local and production `.env`
2. Truncated to the correct 40-character single token
3. Redeployed `.env` to `mspclientpro:/opt/stockpulse-api/.env`
4. Restarted `stockpulse-api` service
5. Verified with direct quote test: `RKLB` returned a live price successfully

## Prevention

When editing `.env`, ensure `FINNHUB_API_KEY=` has exactly one token with no quotes or spaces. After saving, confirm length is ~40 chars (not ~80).

## Expected behavior after fix

- Quote scheduler (every 30s during market hours) updates snapshots with `quote_source: "finnhub"`
- Hot/Warm/Cold tiers populate `change_5m_pct` and `change_15m_pct`
- Monitor tab shows live dot and 5m column during market hours
