# Ripple blank on initial load fix

**Date:** 2026-06-16

## Problem

On app launch, the Ripple tab showed a blank screen until the user switched to another tab (and often back to Ripple).

## Cause

`TabHost` in `RootView.swift` only rendered tab content when `loaded == true`. The initial tab relied on `onAppear` to set `loaded`, but that callback does not fire reliably for the default tab inside a `ZStack` + `safeAreaInset` layout. `onChange(of: selected)` never runs for the initial selection.

## Fix

Render content when the tab is active **or** has been visited before:

```swift
if loaded || isActive {
    content()
}
```

- **Launch:** Ripple is active → renders immediately on frame 1.
- **First visit to another tab:** `isActive` mounts it; `onChange` sets `loaded = true`.
- **Return to visited tabs:** `loaded` keeps the view alive → no black flash.

## File changed

- `ios/StockPulse/App/RootView.swift` — `TabHost` render condition

## Verification

Clean build, launch app — Ripple should show header, ticker tape, and catalyst content without switching tabs first.
