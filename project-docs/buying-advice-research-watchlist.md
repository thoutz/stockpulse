# Research Watchlist + Market/Trends Tab Restructure

**Date:** June 16, 2026

## Summary

Added research-backed **WATCH/AVOID** signals to all three daily pulse reports (open, midday, close), driven by a deterministic Python scorer. Restructured iOS and web tabs: **Market** shows What's New + Research Watchlist; **Trends** absorbs Broad Market / Industries charts.

---

## Backend

### New: `services/buying_signals.py`

Session-weighted scoring using existing algorithms:

- Ripple verdicts (CONFIRMED/FORMING/FAILED) + backtest `confidence_score`
- HOT/WARM tier + intraday movers
- Focus-sector breadth
- RSI overbought/oversold
- Rule-based `AISuggestion` bias (last 4h)
- Midday: held morning move bonus
- Close: AV fundamentals mention bonus

Returns top 3 **WATCH** (score ≥ 15) and up to 2 **AVOID** (score ≤ −10).

### Wired into pipeline

| File | Change |
|------|--------|
| `session_intelligence.py` | Persists `buying_signal` rows per slot |
| `analysis_packet.py` | `RESEARCH SIGNALS` + `RULE-BASED BIAS` sections; updated system prompt |
| `pulse_report.py` | `## Research Watchlist` in user prompt; session notes; `max_tokens=950` |
| `ai_jobs.py` | `max_tokens=950` sync |
| `tests/test_buying_signals.py` | Unit tests |

### Groq output shape

```markdown
## Research Watchlist
- **AMD (WATCH):** FORMING ripple … (85% backtest confidence) …
(Research context — not financial advice.)
```

---

## iOS

### Tab layout

**Market tab** (`MarketView.swift`):
- Market Brief → What's New only (`pulse_open`)
- Research Watchlist → latest `pulse_*` report

**Trends tab** (`TrendsView.swift`):
- Broad Market + Industries (`MarketChartSections.swift`)
- Compare Trends (unchanged catalyst charts)
- Ticker/index detail drill-down

### ViewModel

`StockPulseViewModel`:
- `marketWhatsNewBrief` — from `latestPulseOpenReport()`
- `marketResearchBrief` — from `latestPulseReport()` (updates at midday/close)

### Parsing

`ReportSyntaxHighlighter.swift`:
- Parses `## Research Watchlist` section
- `StructuredReportBodyView` — full report (AI tab)
- `MarketTabReportView` — Market tab only (What's New or Research modes)
- Highlights `WATCH` / `AVOID` keywords

---

## Web

| File | Change |
|------|--------|
| `hooks/useMarketBriefs.ts` | Fetches pulse reports for Market tab |
| `MarketView.tsx` | Brief + Research only |
| `MarketChartSections.tsx` | Charts moved from Market |
| `TrendsView.tsx` | Charts + Compare Trends |
| `HighlightedReportText.tsx` | Research section parsing + `MarketTabReportBody` |

---

## Deploy notes

1. Deploy server (`stockpulse-api`) so new prompts and scoring run at next pulse.
2. Optional: `make backtest` on server for fresh `confidence_score` values.
3. Rebuild iOS / web clients for tab layout and parsing.

Existing reports in DB will not have Research Watchlist until the next pulse generates with the new prompt.
