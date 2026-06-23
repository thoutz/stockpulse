# Trade tab separated from AI — custom tab bar fix

**Date:** 2026-06-16

## Problem

After adding the Trade tab, rebuilding in Xcode still showed Trade grouped with AI Analyst. `RootView.swift` already declared six separate `TabView` children, but **iOS only shows four tabs plus a "More" overflow on iPhone** when using the system tab bar. Trade and AI were both pushed into that More list.

## Fix

Replaced system `TabView` with a custom bottom tab bar that renders all six tabs:

Ripple · Monitor · Trends · Market · **Trade** · AI

### Files changed

| File | Change |
|------|--------|
| `ios/StockPulse/App/RootView.swift` | `switch selectedTab` content + `safeAreaInset` custom bar |
| `ios/StockPulse/Views/Components/StockPulseTabBar.swift` | New compact 6-tab bar |
| `ios/StockPulse/Models/Models.swift` | `AppTab` title/icon helpers |

### Implementation notes

- `StockPulseTabBar` mirrors the MarketPulse custom bar pattern but supports six items with slightly smaller labels (9pt).
- Trade uses `dollarsign.circle` / `dollarsign.circle.fill` when selected.
- Ran `xcodegen generate` so the new Swift file is in the Xcode target.

## Verification

```bash
cd ios && xcodegen generate
xcodebuild -project StockPulse.xcodeproj -scheme StockPulse \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Rebuild in Xcode — Trade should appear as its own dock icon between Market and AI.
