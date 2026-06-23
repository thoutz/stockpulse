# Monitor duplicate title fix

**Date:** 2026-06-20  
**Issue:** Expanding a symbol in the Monitor tab showed the ticker and company name twice — once in the row header and again in the inline detail panel. Tapping the lower (non-button) header did not collapse the row.

## Root cause

The accordion redesign kept `MonitorRow` as the tap target but moved the expanded price/header into `MonitorExpandedDetail` / `MonitorDetail` without removing symbol/name from the row. Both layers rendered the same title block.

## Fix (folder-style header)

The row **is** the folder tab — no merge of two views into one component, just a single header role:

- **Collapsed:** symbol, name, compact price, 5m, live dot, chevron down.
- **Expanded:** same row grows into the header — symbol/name on the left, large scrub-aware price + range % on the right, live dot, chevron up. Chart, stat boxes, and remove button render **below** the row only.

Scrubbing updates the row header in place (price/date/% change).

## Files changed

| Platform | File | Change |
|----------|------|--------|
| iOS | `ios/StockPulse/Views/Watchlist/WatchlistView.swift` | `MonitorRow` accepts `scrubDisplay` + `rangeChange`; expanded layout shows header price; removed duplicate header from `MonitorExpandedDetail` |
| Web | `web/src/views/WatchlistView.tsx` | Same pattern on `MonitorRow`; `MonitorDetail` is chart + stats only |
| Web | `web/src/views/WatchlistView.css` | Expanded row grid (`1fr auto 16px 16px`), `.monitor-row-expanded-price`, tighter detail top padding |

## Verification

1. Open Monitor → tap a symbol (e.g. LUNR).
2. Symbol/name appears **once** in the tappable row header.
3. Tap the header again → collapses.
4. Scrub the chart → header price/date updates without a second title row.
