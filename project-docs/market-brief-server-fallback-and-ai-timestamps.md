# Market Brief Server Fallback & AI Timestamps

**Date:** June 9, 2026  
**Issue:** Market tab showed Groq key error while app uses `STOCKPULSE_API_BASE_URL`; AI findings lacked date/time stamps.

---

## Root cause

`Config.xcconfig` has `STOCKPULSE_API_BASE_URL` set but `GROQ_API_KEY` is empty. The Market tab always called local `AIAnalystService`, which requires a device-side Groq key. The AI Analyst tab already used server chat when the API URL is configured — Market brief did not.

A failed brief was also cached in `UserDefaults`, so the error persisted across launches.

---

## Fixes

### 1. Server fallback for market brief

`generateMarketBrief()` in `StockPulseViewModel` now:
- Uses `StockPulseAPIService.chat()` when `usesServerAPI` is true
- Falls back to latest server `pulse` report from `aiReports` if chat fails or report is fresh (< 4h)
- Uses local Groq only when no server API is configured
- Does not persist error briefs to `MarketBriefStore`

`BackgroundReportTask` uses the same server/local split for morning reports.

### 2. Pulse report sync

`syncAssistantFeed()` calls `applyPulseReportToMarketBriefIfNewer()` so server-generated pulse reports populate the Market tab automatically.

### 3. AI timestamps

Added `DateFormatting.aiStamp(_:)` → e.g. `Jun 9, 2026 · 10:15 AM (2h ago)`

Shown on:
- AI Analyst chat responses (`aiResponseGeneratedAt`)
- Assistant Feed alerts, reports, suggestions (`createdAt`)
- Market Brief footer (`generatedAt`)

---

## Files changed

- `ios/StockPulse/Utilities/DateFormatting.swift` (new)
- `ios/StockPulse/ViewModels/StockPulseViewModel.swift`
- `ios/StockPulse/Services/MarketBriefContext.swift`
- `ios/StockPulse/Services/AIAnalystService.swift`
- `ios/StockPulse/Services/BackgroundReportTask.swift`
- `ios/StockPulse/Views/AI/AIAnalystView.swift`
- `ios/StockPulse/Views/AI/AssistantFeedView.swift`
- `ios/StockPulse/Views/Market/MarketView.swift`

---

## User action

Rebuild the app. On Market tab, tap **Refresh** — brief should load via server AI. Cached Groq error is ignored on load.
