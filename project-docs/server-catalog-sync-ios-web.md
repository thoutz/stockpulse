# Server Catalog Sync — iOS and Web

**Date:** June 13, 2026

## Summary

iOS and web now load **sectors** and **catalysts** from the API (`/api/catalog/*`) on startup, with bundled local catalogs as offline fallbacks.

## API (unchanged surface, active filter default)

```
GET /api/catalog/sectors
GET /api/catalog/catalysts          → active only (default)
GET /api/catalog/catalysts?active=false
```

## iOS

### New

- [`ios/StockPulse/Services/AppCatalog.swift`](ios/StockPulse/Services/AppCatalog.swift) — `@Observable` singleton; syncs sectors + catalysts from server

### Updated

- [`CatalystCatalog.swift`](ios/StockPulse/Data/CatalystCatalog.swift) — `bundledCatalysts` fallback; computed `catalysts` / `watchlistTickers` / `allTickers` read from `AppCatalog.shared`
- [`IndustryCatalog.swift`](ios/StockPulse/Data/IndustryCatalog.swift) — `bundledIndustries`; computed `industries` from `AppCatalog.shared`; accent colors merge server `accent_hex`
- [`StockPulseAPIService.swift`](ios/StockPulse/Services/StockPulseAPIService.swift) — `fetchCatalogSectors()`, `fetchCatalogCatalysts()`
- [`StockPulseViewModel.swift`](ios/StockPulse/ViewModels/StockPulseViewModel.swift) — `AppCatalog.shared.syncFromServer()` on each `refresh()`; updates `catalysts` array

### Flow

1. App launch → `refresh()` → catalog sync → dashboard fetch
2. Offline / API error → bundled NVDA/RKLB catalysts + static industries remain

## Web

### New

- [`web/src/hooks/useCatalog.ts`](web/src/hooks/useCatalog.ts) — fetches catalog on mount; exposes `catalysts`, `industries`, `industryAccentHex`, `watchlistTickers`, `keyEvents`

### Updated

- [`App.tsx`](web/src/App.tsx) — `useCatalog()` wired into tab views
- [`data/catalysts.ts`](web/src/data/catalysts.ts) / [`data/industries.ts`](web/src/data/industries.ts) — `bundled*` exports + helper functions taking catalog arrays
- Views: `RippleView`, `TrendsView`, `MarketView`, `MarketTickerDetailCard`
- [`useDashboard.ts`](web/src/hooks/useDashboard.ts) — accepts `watchlistTickers` from catalog
- [`useTrendRangeData.ts`](web/src/hooks/useTrendRangeData.ts) — trend tickers derived from live catalyst list
- [`lib/api.ts`](web/src/lib/api.ts) — `catalogSectors`, `catalogCatalysts`

## Deploy

Redeploy API (if not already) + rebuild web + iOS app.

```bash
curl https://api.tryan.app/api/catalog/catalysts
curl https://api.tryan.app/api/catalog/sectors
```

After `discover_catalysts.py --apply` or manual DB edits, clients pick up changes on next refresh without app store release for catalog-only updates.
