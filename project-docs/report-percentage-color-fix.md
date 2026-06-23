# Report Percentage Color Fix

**Date:** June 15, 2026

## Problem

Groq pulse reports sometimes wrote natural language like **"AMD drops 4%"** without a minus sign. The iOS syntax highlighter matched `4%` and colored it **green** because unsigned positive numbers defaulted to green — contradicting the loss language in the same sentence.

## Root cause

In `ios/StockPulse/Utilities/ReportSyntaxHighlighter.swift`, percentage coloring used sign-only logic:

- `-` prefix → red
- `+` prefix → green
- unsigned positive value → green (incorrect for "drops 4%")

Groq source data in `analysis_packet.py` already uses signed percentages (`+3.2%`, `-3.2%`), but the model sometimes omits the sign when paraphrasing.

## Fix

### iOS — context-aware highlighting (primary)

Updated `ReportSyntaxHighlighter` with:

1. **`percentageColor(match:in:at:)`** — resolves color from sign first, then nearby language
2. **`contextSentiment(before:in:)`** — scans ~45 characters before each `%` match for directional keywords
3. **Rightmost keyword wins** — e.g. "recovered from drop, now up 4%" → green
4. **Unsigned with no keyword → neutral** — no longer defaults to green

**Negative keywords:** drop, drops, dropped, decline, declined, fall, fell, loss, losses, down, lower, slide, slid, sink, retreat, weaken, underperform, selloff, sell-off, off

**Positive keywords:** gain, gains, gained, rose, rise, rally, climb, jump, surge, up, higher, beat, rebound, advance, bullish

Affected views (unchanged wiring, same highlighter):

- `AssistantFeedView.swift` — pulse reports
- `MarketView.swift` — market brief
- `AIAnalystView.swift` — chat responses

### Server — Groq prompt rules (secondary)

Added signed-percentage formatting rules so new reports are more consistent:

- `server/stockpulse-api/services/pulse_report.py` — `PULSE_USER_PROMPT`
- `server/stockpulse-api/services/analysis_packet.py` — `PULSE_SYSTEM_PROMPT` and `CHAT_SYSTEM_PROMPT`

Rule: always use `+4.2%` / `-4.2%`; never write "drops 4%" — use "drops -4%" or "-4%".

## Verification

Sample strings validated against expected colors:

| Text | Match | Expected | Result |
|------|-------|----------|--------|
| `NVDA drops 4% after earnings miss` | `4%` | red | pass |
| `AAPL gained 2.3% on strong iPhone data` | `2.3%` | green | pass |
| `SPY down 1.1% while QQQ holds +0.4%` | `1.1%` / `+0.4%` | red / green | pass |
| `AMD still +4% from open` | `+4%` | green | pass |
| `unchanged at 3%` | `3%` | neutral | pass |
| `recovered from drop, now up 4%` | `4%` | green | pass |
| `-4.2% on the day` | `-4.2%` | red | pass |

iOS fix applies immediately to existing feed entries. Server prompt change takes effect on next pulse/chat generation after deploy.

## Deploy (server prompts only)

```bash
rsync -avz --exclude venv --exclude .venv --exclude __pycache__ server/stockpulse-api/ mspclientpro:/opt/stockpulse-api/
ssh mspclientpro 'systemctl restart stockpulse-api'
```

## Color legend (updated behavior)

| Element | Color |
|---------|-------|
| Signed positive (`+4%`) | Green |
| Signed negative (`-4%`) | Red |
| Unsigned with loss language (`drops 4%`) | Red |
| Unsigned with gain language (`gained 2.3%`) | Green |
| Unsigned, no directional context (`unchanged at 3%`) | Neutral (textSecond) |
