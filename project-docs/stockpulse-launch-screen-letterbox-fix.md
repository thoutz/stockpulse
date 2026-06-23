# StockPulse launch screen letterbox fix

## Symptom
App appeared as a small centered card with large black bars top and bottom on modern iPhones.

## Root cause (runtime evidence)
Console logs showed `screenW: 320`, `screenH: 480` and `infoPlistHasLaunchScreen: false`. iOS ran StockPulse in legacy 3.5-inch compatibility mode because no launch screen was declared.

## Fix
1. Added `LaunchBackground.colorset` (#060a0f) in `Assets.xcassets`
2. Added `UILaunchScreen` → `UIColorName: LaunchBackground` in `Info.plist`
3. Pinned `UILaunchScreen` in `ios/project.yml` for XcodeGen

## Verification (iPhone 17 simulator)
- Before: 320×480, `infoPlistHasLaunchScreen: false`
- After: 402×874, `infoPlistHasLaunchScreen: true`

## Cleanup
Removed temporary `DebugLayoutLogger` / `LayoutDebugOverlay` instrumentation.
