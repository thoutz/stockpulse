# AI Reports Include Favorited Symbols

**Date:** June 16, 2026

## Problem

Scheduled AI tab pulse reports (open / midday / close) were biased toward the bundled config watchlist (`TICKERS` env + catalyst ripples). User favorited symbols from `/api/favorites` were partially wired (WARM tier, ingest) but not explicitly surfaced in Groq context or report scoring — so favorites rarely appeared in **What's New**, **Research Watchlist**, or Market Brief sections.

The original `stock-search-and-favorites.md` doc described a `=== USER FAVORITES ===` packet section that was never implemented in `analysis_packet.py`.

## Solution

Server-side pulse generation now treats user favorites as first-class symbols in context assembly, scoring, and Groq prompts. No iOS/web client changes were required — all tabs render the same server-generated report bodies.

---

## Backend changes

### `services/analysis_packet.py`

| Change | Detail |
|--------|--------|
| `USER FAVORITES` section | New `_format_user_favorites_section()` inserted after Monitor Focus; lists each favorite with tier, snapshot, or pending-data note |
| Symbol universe | Replaced `list(snapshots.keys())` with `get_tracked_symbols()` ∪ snapshots for 30-day trends, intraday stats, and ripple analysis |
| `PULSE_SYSTEM_PROMPT` | Rules to include USER FAVORITES in What's New and Context when they have material moves |
| `build_chat_context` | Same favorites section; ripple histories expanded from `ticker_list[:10]` to tracked symbols (cap 20) |

### `services/buying_signals.py`

| Change | Detail |
|--------|--------|
| Candidate union | All favorites explicitly added to research signal candidates |
| Scoring bonus | `user_favorite: +8` per slot; tag `"user favorite (WARM tier)"` |
| Reserved WATCH slot | If no favorite in top 3 WATCH, promote highest-scoring favorite with score ≥ 10 |

### `services/pulse_report.py`

| Change | Detail |
|--------|--------|
| `PULSE_USER_PROMPT` | What's New and Context sections may reference USER FAVORITES |
| `SESSION_PROMPTS` | Open/midday/close notes instruct Groq to include favorites with notable session activity |

---

## Data flow

```
POST /api/favorites
  → favorites table
  → get_tracked_symbols() (config TICKERS + favorites)
  → ingest loop → snapshots + bars
  → build_pulse_analysis_packet
       ├── USER FAVORITES section
       ├── tracked symbol union (trends/stats/ripples)
       └── build_buying_signals (favorite boost + reserved slot)
  → Groq → AIReport (pulse_open | pulse_midday | pulse_close)
  → GET /api/ai/digest
  → Market Brief (What's New) + Research Watchlist + AI tab feed
```

---

## Tests added

- `tests/test_buying_signals.py` — favorite bonus, reserved WATCH slot
- `tests/test_analysis_packet_favorites.py` — `_format_user_favorites_section` with/without snapshots

Run:

```bash
cd server/stockpulse-api
.venv/bin/python -m pytest tests/test_buying_signals.py tests/test_analysis_packet_favorites.py -v
```

---

## Verification

1. Add a ticker **not** in config `TICKERS` (e.g. `AAPL`) via Monitor → search → favorite
2. Wait for ingest (~12s) or confirm snapshot via `/api/monitor`
3. Trigger next pulse or `POST /api/ai/reports/catch-up`
4. Check:
   - **Market tab → What's New** — favorite mentioned if it moved materially
   - **Market tab → Research Watchlist** — favorite can appear with boosted score
   - **AI tab → full report** — same content with favorites in appropriate sections
5. Remove favorite → next pulse stops prioritizing it

---

## Out of scope

- Web `session_favorites` (cookie-based) — not wired to pulse pipeline
- Client UI / parsing changes — existing section parsers unchanged
- Dashboard design/style changes — none
