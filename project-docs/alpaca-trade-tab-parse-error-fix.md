# Alpaca Trade tab parse error fix

**Date:** June 17, 2026

## Symptom

Trade tab showed **"Could not parse server response"** while Alpaca was actually connected.

## Root cause

`/api/trading/dashboard` returned cash-flow activities with **date-only** timestamps from Alpaca:

```json
"transaction_time": "2026-06-17"
```

iOS `JSONDecoder` only accepted full ISO8601 datetimes, so decoding `APITradeActivity.transactionTime` failed.

Alpaca keys on the server were fine (`configured: true`, `connected: true`, $1000 paper equity).

## Fix

1. **`services/alpaca_service.py`** — `_normalize_activity_time()` converts date-only strings to `YYYY-MM-DDT12:00:00Z` before API response.
2. **`StockPulseAPIService.swift`** — date decoder also accepts `yyyy-MM-dd` as fallback.

## Deploy

```bash
rsync ... alpaca_service.py → mspclientpro
systemctl restart stockpulse-api
```

Rebuild iOS app for client-side date fallback.
