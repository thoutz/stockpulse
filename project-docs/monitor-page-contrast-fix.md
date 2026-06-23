# Monitor Page Contrast Fix

**Date:** June 20, 2026

## Problem

The web Monitor tab (`WatchlistView`) looked washed out and unreadable — ticker symbols, prices, and company names appeared as dark grey/maroon text on a dark background. The page title and sidebar still rendered correctly.

## Root cause

Monitor rows are implemented as `<button>` elements (`.monitor-row`, `.monitor-mover-chip`). Global button styles reset `background` and `border` but did **not** set `color: inherit` or disable native button appearance. Browsers apply system default button text colors (dark in light color-scheme), which clash with the app’s dark theme.

Other tabs mostly use `<div>` / card components, so they inherited `body { color: var(--text-primary) }` correctly.

## Fix

### `web/src/styles/global.css`

- Added `color-scheme: dark` on `html` so form controls and native UI match the dark theme.
- Updated `button` reset to include `color: inherit`, `-webkit-appearance: none`, and `appearance: none`.

### `web/src/views/WatchlistView.css`

- Set explicit `color: var(--text-primary)` on `.monitor-row`, `.monitor-row-ticker`, `.monitor-row-price`, `.monitor-row-5m`, and `.monitor-mover-chip`.
- Bumped secondary labels (`.monitor-row-name`, `.monitor-fav-count`, `.monitor-5m-label`) from `--text-muted` to `--text-second` for better legibility on dark backgrounds.

## Verification

1. Open the web app and navigate to **Monitor**.
2. Confirm ticker symbols and prices are light (`#e2e8f0`).
3. Confirm green/red change percentages are clearly visible.
4. Confirm company names under tickers are readable grey (`#9ca3af`).

## Deploy

Deployed to production on June 20, 2026:

```bash
cd web && npm run build && rsync -avz --delete dist/ mspclientpro:/var/www/tryan.app/
```

Previous production bundle (`index-DZW6fGBK.css`) did not include the button/color fixes — only local source had them until this deploy.
