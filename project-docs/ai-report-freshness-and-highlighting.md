# AI Report Freshness + Syntax Highlighting

**Date:** June 9, 2026

## Problem

Pulse reports in the AI tab often opened with the same AMD +4% line every 30 minutes. The rest of each report was unique, but the repeated lead made reports feel identical.

## Root cause

1. **Server prompt** asked to "highlight top movers" without distinguishing new vs unchanged data.
2. **Same snapshot data** (AMD still +4%) was fed to Groq every cycle.
3. **Plain text UI** — no visual hierarchy between fresh insights and background stats.

## Server changes

### New file: `services/pulse_report.py`

- Fetches the previous pulse report and passes it with explicit dedupe instructions.
- Builds a **CHANGES SINCE LAST PULSE** section from new alerts and suggestions since the last report timestamp.
- Requires structured output:

```
TITLE: <newest headline only>

## What's New
- bullets of changes only

## Context
- optional stable background (0-2 bullets)
```

### Updated: `services/ai_jobs.py`

- `run_pulse_report()` uses `generate_pulse_report()`.
- `run_ai_insight_alert()` uses the same What's New / Context structure.

## iOS changes

### New file: `Utilities/ReportSyntaxHighlighter.swift`

- **`ReportBodyParser`** — splits body into What's New, Context, and remainder.
- **`ReportSyntaxHighlighter`** — code-editor-style coloring:
  - Section headers → blue bold
  - Tickers (`AAPL`, `AMD`) → orange mono bold
  - Percentages → green (+) / red (-) mono bold
  - Verdicts (`CONFIRMED`, `FORMING`, etc.) → verdict colors
  - Keywords (`bullish`, `RSI`, `breakout`) → purple semibold
- **`StructuredReportBodyView`** — What's New shown prominently; Context collapsed under "Background context".
- **`HighlightedReportText`** — reusable highlighted text view.

### Updated views

| File | Change |
|------|--------|
| `AssistantFeedView.swift` | Reports use `StructuredReportBodyView` (removed 8-line limit) |
| `AIAnalystView.swift` | Chat analysis uses `HighlightedReportText` |
| `MarketView.swift` | Market brief uses `StructuredReportBodyView` |

## Deploy

```bash
rsync -avz --exclude venv --exclude .venv --exclude __pycache__ server/stockpulse-api/ mspclientpro:/opt/stockpulse-api/
ssh mspclientpro 'systemctl restart stockpulse-api'
```

New report structure applies on the next scheduled pulse (every 30 min). Existing reports in the feed still render with syntax highlighting; section parsing activates once new structured reports arrive.

## Color legend (reports)

| Element | Color |
|---------|-------|
| Section headers | Blue |
| Tickers | Orange |
| Positive % | Green |
| Negative % | Red |
| CONFIRMED / FORMING / FAILED / WATCHING | Green / Orange / Red / Blue |
| RSI, bullish, bearish, etc. | Purple |
