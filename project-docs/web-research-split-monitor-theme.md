# Web Research Split View & Monitor Theme Fix

**Date:** June 17, 2026

## Summary

Added a desktop **Research** tab that shows Market brief + Research Watchlist beside the AI Analyst in a split layout. Aligned Monitor tab colors with design tokens and iOS Monitor accent (orange live state).

## Research split (wide screens)

- New tab **`research`** appears in the sidebar when viewport ≥ **1100px**
- **`ResearchSplitView`** — left pane: Market (`Market Brief`, `Research Watchlist` from pulse reports); right pane: AI Analyst feed + chat
- On narrow screens the Research tab is hidden; selecting it falls back to Market
- Individual **Market** and **AI** tabs unchanged for mobile / single-panel use

### Files

| File | Change |
|------|--------|
| `web/src/views/ResearchSplitView.tsx` | Split layout shell |
| `web/src/views/ResearchSplitView.css` | Column stack mobile; 50/50 row at ≥1100px |
| `web/src/hooks/useMediaQuery.ts` | Viewport hook for tab visibility |
| `web/src/App.tsx` | `research` tab routing |
| `web/src/components/TabBar.tsx` | Research tab (desktop only) |
| `web/src/lib/api.ts` | `AppTab` includes `"research"` |
| `web/src/views/MarketView.tsx` | Optional `pane` prop (compact header) |
| `web/src/views/AIAnalystView.tsx` | Optional `pane` prop |
| `web/src/styles/global.css` | Shared `.pane-header` styles |

## Monitor theme fixes

Replaced hardcoded Tailwind rgba blues/oranges with token-based mixes:

| Token | Use |
|-------|-----|
| `--blue-muted` | Focus btn, row hover, mover hover |
| `--orange-muted` | Limit banner, live dots, Monitor header |
| `--red-muted` | Error banner |
| `--purple-muted` | Market brief card |

Monitor-specific:

- Live indicator + quote dots → **orange** (matches iOS Monitor header)
- Hot tier label → orange accent
- Selected row → orange left inset bar
- Limit banner → orange border + muted fill using `--orange`

### Files

- `web/src/styles/tokens.css` — muted color tokens
- `web/src/views/WatchlistView.css` — monitor hub styles
- `web/src/views/WatchlistView.tsx` — `data-tier` on tier sections
- `web/src/views/MarketView.css` — research/brief card backgrounds

## Deploy

```bash
cd web && npm run build && rsync -avz --delete dist/ mspclientpro:/var/www/tryan.app/
```

## Usage

1. Open https://tryan.app on a wide browser (≥1100px)
2. Click **Research** in the left sidebar
3. Market pulse + Research Watchlist on the left; AI digest/chat on the right
