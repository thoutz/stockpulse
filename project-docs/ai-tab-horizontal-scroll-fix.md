# AI tab horizontal scroll / drift fix

**Date:** 2026-06-16

## Problem

On the AI tab, users could drag content left and right as if the screen scrolled horizontally. Other tabs only scroll vertically.

## Cause

Two layout issues combined:

1. **`FlowLayout` width bug** — When laying out suggestion chips, `placeSubviews` used `proposal.width ?? .infinity`. Inside a vertical `ScrollView`, that often meant **no width limit**, so all chips were placed in one long horizontal row wider than the screen. The scroll view then allowed horizontal panning/bounce.

2. **Missing width constraints** — AI feed text (`HighlightedReportText`, `StructuredReportBodyView`) and the root `VStack` did not pin to `maxWidth: .infinity`, so long report lines could also widen scroll content.

## Fix

### `FlowLayout` (`Utilities.swift`)

- Resolve max width from proposal **or** parent `bounds.width`.
- Wrap chips when width is finite; only use unbounded layout when width is truly unknown.

### `AIAnalystView.swift`

- `.frame(maxWidth: .infinity)` on root `VStack` and `FlowLayout`.
- `.scrollBounceBehavior(.basedOnSize, axes: .vertical)` — vertical bounce only.

### `AssistantFeedView.swift` + `ReportSyntaxHighlighter.swift`

- `.frame(maxWidth: .infinity, alignment: .leading)` on feed and report bodies.
- `HighlightedReportText` uses `.fixedSize(horizontal: false, vertical: true)` so text wraps instead of extending sideways.

## Verification

Rebuild and open AI tab — swipe left/right should no longer move content; vertical scroll unchanged.
