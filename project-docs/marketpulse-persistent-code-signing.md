# MarketPulse — Persistent Code Signing

**Date:** June 3, 2026

## Problem

After code changes or `xcodegen generate`, Xcode **Signing & Capabilities** showed an empty Team dropdown and required re-selecting **TRISTAN JAMES HOUTZ** manually.

## Root cause

1. [`ios/project.yml`](ios/project.yml) used `DEVELOPMENT_TEAM: $(DEVELOPMENT_TEAM)` — variables XcodeGen did not map to `TargetAttributes.DevelopmentTeam`.
2. Team lived only in gitignored [`ios/Signing.xcconfig`](ios/Signing.xcconfig).
3. Regenerated `project.pbxproj` lacked `DevelopmentTeam` in `TargetAttributes`.

## Fix

Updated [`ios/project.yml`](ios/project.yml):

- Project and target `settings.base`: literal `DEVELOPMENT_TEAM: 3U49743Z3T`, `CODE_SIGN_STYLE: Automatic`, `CODE_SIGN_IDENTITY: Apple Development`
- Target `attributes.DevelopmentTeam: 3U49743Z3T`
- Removed `Signing.xcconfig` from `configFiles` (API keys stay in `Config.xcconfig` only)

Regenerated project:

```bash
cd ios && xcodegen generate
```

## Verification

`project.pbxproj` after regen:

- `TargetAttributes` → `DevelopmentTeam = 3U49743Z3T`
- Target Debug/Release → `DEVELOPMENT_TEAM = 3U49743Z3T`, `CODE_SIGN_STYLE = Automatic`
- `xcodebuild` → **BUILD SUCCEEDED**

## Maintenance

If you switch Apple ID / team, update **only** `ios/project.yml` (both `DEVELOPMENT_TEAM` and `attributes.DevelopmentTeam`), then `xcodegen generate`. Do not rely on manual Xcode team selection — it will be overwritten on the next regen.
