# AI Tab Report Schedule + Collapsible Sessions

**Date:** June 9, 2026 (updated)

## Report schedule (ET, weekdays only)

| Session | Time | `report_type` |
|---------|------|---------------|
| Market Open | **10:00 AM** | `pulse_open` |
| Midday | **1:00 PM** | `pulse_midday` |
| Market Close | **4:00 PM** | `pulse_close` |

On server startup, **catch-up** runs any missed slots for today (e.g. deploy at 2 PM generates open + midday if missing).

## Legacy 3:41 AM reports

Old every-30-min cron produced off-hours reports. iOS now **hides** legacy `pulse` reports outside 9:30 AM–4:00 PM ET. They will no longer appear mislabeled as "Market Close."

## UI

- **Day** sections: collapsible (today expanded by default)
- **Session** reports (Open / Midday / Close): **expanded by default**, user can collapse individually

## June 9 data

There is **no midday report in the DB yet** — only the old off-hours pulse. After server deploy + catch-up, you should see Open and Midday reports generated for today; Close runs at 4:00 PM ET (or on catch-up if deploy is after 4 PM).
