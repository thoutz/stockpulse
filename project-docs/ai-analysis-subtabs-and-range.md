# AI Analysis Sub-Tabs & Date Range

**Date:** June 9, 2026

## Changes

Reorganized the AI tab analytics section without touching other tabs or chat.

### Layout (top → bottom)
1. **Range dropdown** — `1 day` · `3 days` · `7 days` (filters digest client-side from 7-day server payload)
2. **Sub-tabs** — `Alerts` | `Reports`
3. **Alerts tab** — expandable `DisclosureGroup` per day (newest first), count badge per day
4. **Reports tab** — flat list of all reports in the selected range, newest first
5. **Removed** pull-to-refresh on the AI tab (sync still runs on app launch / background refresh loop)

### ViewModel
- `digestRange: AIDigestRange` (1 / 3 / 7)
- `aiAnalysisSection: AIAnalysisSection` (alerts / reports)
- `digestDaysInRange`, `reportsInRange`, `alertDaysInRange` computed from `aiDigestDays`

### Files
- `AssistantFeedView.swift` — full rewrite
- `AIAnalystView.swift` — removed `.refreshable`
- `DigestBuilder.swift` — `AIDigestRange`, `AIAnalysisSection`, `lastNDayKeys`
- `StockPulseViewModel.swift` — range/section state
- `DateFormatting.swift` — `daySectionLabel` for alert day headers

Chat, suggestion chips, and on-demand Q&A unchanged below the analytics block.
