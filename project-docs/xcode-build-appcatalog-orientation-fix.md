# Xcode build fix — AppCatalog missing + orientation validation

**Date:** 2026-06-16  
**Issue:** StockPulse failed to build in Xcode with `Cannot find 'AppCatalog' in scope` and iPad orientation validation warning.

## Root causes

1. **`AppCatalog.swift` not in Xcode target** — The file existed at `ios/StockPulse/Services/AppCatalog.swift` but was never added to `StockPulse.xcodeproj`. `CatalystCatalog` and `IndustryCatalog` reference `AppCatalog.shared`, so the compiler could not resolve the type.

2. **Swift concurrency isolation** — After adding the file, build failed because `AppCatalog` was marked `@MainActor` while static accessors in `CatalystCatalog` / `IndustryCatalog` (and background tasks) read it from nonisolated contexts.

3. **iPad orientation validation** — App targets iPhone + iPad (`TARGETED_DEVICE_FAMILY: "1,2"`) but `Info.plist` had no `UISupportedInterfaceOrientations` keys. Apple requires all orientations on iPad unless the app opts into full screen only.

## Fixes applied

### 1. Regenerate Xcode project (XcodeGen)

```bash
cd ios && xcodegen generate
```

`project.yml` already includes all files under `StockPulse/`; running XcodeGen picked up `AppCatalog.swift` and added it to the compile sources.

### 2. Remove `@MainActor` from `AppCatalog`

**File:** `ios/StockPulse/Services/AppCatalog.swift`

Removed `@MainActor` from the class. The catalog is a shared data cache read from view models, static catalog enums, and background report tasks — it does not need main-actor isolation. `@Observable` remains for future UI binding if needed.

### 3. Add supported interface orientations

**File:** `ios/project.yml` — added under `targets.StockPulse.info.properties`:

- `UISupportedInterfaceOrientations` (iPhone): portrait, landscape left/right
- `UISupportedInterfaceOrientations~ipad`: all four orientations

Then ran `xcodegen generate` again to merge into `Info.plist`.

## Verification

```bash
cd ios
xcodegen generate
xcodebuild -project StockPulse.xcodeproj -scheme StockPulse \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

**Result:** `BUILD SUCCEEDED`

## Notes for future changes

- When adding new Swift files under `ios/StockPulse/`, run `xcodegen generate` from the `ios/` folder so `StockPulse.xcodeproj` stays in sync (unless you add files manually in Xcode).
- The “Update to recommended settings” prompt in Xcode is informational; accept it in Xcode if desired — it does not block builds.
