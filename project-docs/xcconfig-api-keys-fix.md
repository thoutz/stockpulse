# Config.xcconfig linkage fix

**Date:** June 3, 2026

## Problem

StockPulse showed `Add MASSIVE_API_KEY in ios/Config.xcconfig` even when the key was present in `ios/Config.xcconfig`. The built app’s `Info.plist` had an empty `MASSIVE_API_KEY` because Xcode never applied the xcconfig at build time.

## Root cause

`project.yml` used a list form for `configFiles` that XcodeGen did not wire into `project.pbxproj`:

```yaml
# Broken (no baseConfigurationReference generated)
configFiles:
  Debug:
    - Config.xcconfig
```

`StockPulse.xcodeproj` had no `baseConfigurationReference` to `Config.xcconfig`, so `$(MASSIVE_API_KEY)` in Info.plist was not substituted.

## Fix

1. Project-level config (scalar form):

```yaml
configFiles:
  Debug: Config.xcconfig
  Release: Config.xcconfig
```

2. Target-level config (so StockPulse target inherits keys for `INFOPLIST_KEY_*`):

```yaml
targets:
  StockPulse:
    configFiles:
      Debug: Config.xcconfig
      Release: Config.xcconfig
```

3. Regenerate: `cd ios && xcodegen generate`

4. Clean build in Xcode (Shift+Cmd+K) and run again.

## Verify

After build, `StockPulse.app/Info.plist` should have non-empty `MASSIVE_API_KEY` and `GROQ_API_KEY` (not `$(MASSIVE_API_KEY)` literal).

## User steps

1. Save `ios/Config.xcconfig` with keys.
2. Open `ios/StockPulse.xcodeproj` (not MarketPulse).
3. Clean build folder → Run.
