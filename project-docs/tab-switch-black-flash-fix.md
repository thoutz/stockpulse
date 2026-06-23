# Tab switch black flash fix

**Date:** 2026-06-16

## Problem

After switching to the custom 6-tab dock, moving between tabs (Trends → Market → AI, etc.) showed a brief black screen between each section.

## Cause

`RootView` used a `switch selectedTab` to pick the active screen. SwiftUI **destroys the old tab view and builds the new one** on every switch. For one frame the content area is empty, exposing the window background (black flash).

The tab bar also wrapped selection changes in `withAnimation(.spring(...))`, which could exaggerate the empty frame during the transition.

## Fix

### 1. `TabHost` — keep visited tabs alive

Replaced `switch` with a `ZStack` of `TabHost` wrappers:

- Each tab loads on **first visit** (lazy — avoids firing all `.task` handlers at launch).
- After first visit, the view stays mounted but hidden via `opacity(0)` + `allowsHitTesting(false)`.
- Switching back is instant — no teardown, no black frame.

### 2. Persistent root background

`DS.Color.bg.ignoresSafeArea()` sits behind all tab hosts so any sub-frame gap matches the app background instead of pure black.

### 3. Instant tab selection

Removed `withAnimation` from `StockPulseTabBar` button taps. Added `.animation(.none, value: selectedTab)` on the root container.

## Files changed

| File | Change |
|------|--------|
| `ios/StockPulse/App/RootView.swift` | `ZStack` + `TabHost` pattern |
| `ios/StockPulse/Views/Components/StockPulseTabBar.swift` | Instant selection, no spring animation |

## Verification

Rebuild in Xcode and switch rapidly between Trends, Market, Trade, and AI — transitions should be immediate with no black flash after each tab has been opened once.
