# Market Tab — Enhanced Stock Detail Card

**Date:** June 16, 2026

## What changed

Clicking a symbol in the Market tab now opens a full detail card matching iOS `MarketTickerDetailCard`.

### Detail card includes

- **Company background** — static blurbs in `web/src/data/company-blurbs.ts`
- **Performance stats** — price, 1D/30D, group rank, vs group 30D, industry breadth
- **Technicals** — RSI (with overbought/oversold hint), SMA 20, 5m/15m moves, quote source
- **Enhanced chart** (`PriceChart.tsx`) — grid + Y-axis labels, area gradient, Price / % Change toggle, SMA 20 dashed line, 30D / 90D range
- **Industry context** — peer scroll row to switch symbols within the group
- **Ripple signals** — verdict badges from dashboard ripple results
- **Ripple network** — catalyst links from static catalog
- **News** — ticker headlines + industry pulse via `GET /api/news`

### New files

| File | Purpose |
|------|---------|
| `web/src/components/MarketTickerDetailCard.tsx` | Detail card UI |
| `web/src/components/PriceChart.tsx` | Full-width interactive chart |
| `web/src/lib/market-utils.ts` | Industry snapshot + ripple badge helpers |
| `web/src/data/company-blurbs.ts` | Company background copy |

### API additions (client)

- `api.news(symbol | symbols[], limit)`
- `api.indicators(symbol)` (ready for future use)

### Deploy

```bash
cd web && npm run build && rsync -avz --delete dist/ mspclientpro:/var/www/tryan.app/
```

Live at https://tryan.app → Market tab → click any industry ticker.
