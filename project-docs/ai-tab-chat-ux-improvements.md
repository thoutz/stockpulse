# AI tab chat UX improvements

**Date:** 2026-06-16

## Summary

Improved the AI tab chat experience: keyboard dismissal, clear chat control, auto-clear input on send, and a two-mode layout (centered empty state vs. active conversation).

## Changes

### ViewModel — `StockPulseViewModel.swift`

- **`askAI()`** — Snapshots `aiQuery` into `prompt`, clears the text field immediately, then calls server/local AI with the snapshot.
- **`clearAIChat()`** — Resets `aiQuery`, `aiResponse`, and `aiResponseGeneratedAt`.

### View — `AIAnalystView.swift`

**Two layout modes:**

| Mode | When | Layout |
|------|------|--------|
| Empty | No response and not loading | Centered hero (brain icon + subtitle), suggestion chips, composer vertically centered |
| Active | Loading or has response | ScrollView for analysis card; composer pinned in `safeAreaInset` bottom bar |

**Keyboard & submit:**

- `submitChat()` — Validates input, sets `focused = false`, calls `askAI()`.
- TextField `.submitLabel(.send)` + `.onSubmit { submitChat() }`.
- Send button and suggestion chips use `submitChat()`.
- Active scroll: `.scrollDismissesKeyboard(.interactively)`.

**Clear chat:**

- `xmark.circle.fill` in header when response or draft text exists.
- Disabled while `aiLoading`; dismisses keyboard and calls `clearAIChat()`.

**UI (existing `DS` tokens):**

- Blue circle hero icon on empty state.
- Composer: `surface2` background, blue border when focused.
- Response card unchanged (blue accent bar + `HighlightedReportText`).

## Verification

1. AI tab launch — centered composer and suggestions when empty.
2. Send or Return — field clears, keyboard hides, loading then response.
3. Suggestion chip — sends without leaving text in field.
4. Clear (×) — resets to empty centered layout.
5. Build succeeded on iPhone 17 simulator.

## Update — inline send button (2026-06-16)

- Send button moved **inside** the prompt bar (trailing edge of the same rounded container).
- Bar uses `frame(maxWidth: .infinity)` with shared `surface2` background and border stroke on the outer `HStack`.
- Horizontal padding reduced to `DS.Space.md` so the bar extends closer to screen edges.
