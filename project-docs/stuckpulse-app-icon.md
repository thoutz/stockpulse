# StuckPulse App Icon

**Date:** June 9, 2026

## Summary

Created a simple, elegant app icon for StuckPulse aligned with the existing dark fintech design system. The icon uses the catalyst + ripple metaphor from the app: a glowing amber center dot with concentric pulse rings in blue and green on a deep navy background.

## Design Concept

| Element | Meaning | Color |
|---------|---------|-------|
| Center dot | Market catalyst — the event that starts a move | `#f59e0b` (amber) |
| Inner ring | Primary ripple wave | `#60a5fa` (blue) |
| Middle ring | Confirmed ripple follow-through | `#22c55e` (green) |
| Outer ring | Subtle propagation | Blue at reduced opacity |
| Background | App dark theme | `#060a0f` → `#0d1628` gradient |

No text or letterforms — the symbol reads clearly at 60pt home-screen size.

## Files

| Path | Purpose |
|------|---------|
| `ios/StockPulse/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` | 1024×1024 PNG wired into Xcode |
| `ios/StockPulse/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` | Asset catalog manifest (`filename: AppIcon.png`) |
| `.cursor/.../assets/stuckpulse-app-icon-1024.png` | Original generated source (1536×1024, cropped to square) |

## Implementation Steps

1. Generated icon via image generation using brand palette from `DesignSystem.swift`.
2. Copied PNG into `AppIcon.appiconset/`.
3. Center-cropped to **1024×1024** with `sips -c 1024 1024` (iOS universal icon requirement).
4. Updated `Contents.json` to reference `AppIcon.png`.

## Xcode Project Wiring

The icon is **not** set in `Info.plist` manually. Modern iOS uses the asset catalog:

| Setting | Value |
|---------|-------|
| `ASSETCATALOG_COMPILER_APPICON_NAME` | `AppIcon` (in `project.pbxproj` / `project.yml`) |
| Asset catalog | `StockPulse/Resources/Assets.xcassets/AppIcon.appiconset/` |

At build time, Xcode merges icon metadata into the final `Info.plist` automatically (`CFBundleIcons`).

### Permanent fix (June 12, 2026)

**Root cause:** `project.yml` excluded `Resources/Assets.xcassets` from the source scan *and* listed it under `resources`, but XcodeGen 2.45 ignored the explicit `resources` entry when the exclude was present. Regenerating the project (`xcodegen generate`) dropped `Assets.xcassets` from **Copy Bundle Resources**, so the icon never shipped in the app bundle.

**Fix:** In `ios/project.yml`, removed `Resources/Assets.xcassets` from `sources.excludes`. Only `Resources/Info.plist` is excluded now. XcodeGen auto-includes the asset catalog from the source tree; fonts stay on the explicit `resources` list.

Do **not** add `Resources/Assets.xcassets` back to `excludes` — that breaks icon bundling on the next `xcodegen generate`.

## How to Preview

1. Open `StockPulse.xcodeproj` in Xcode.
2. Select **StockPulse** target → **General** → **App Icons and Launch Screen** — **AppIcon** should show the ripple design.
3. **Product → Clean Build Folder** (⇧⌘K), then build.
4. **Delete the app** from simulator/device if reinstalling (iOS caches icons).
5. Build and run — icon appears on home screen after install.

## Optional Variations

If you want tweaks, common directions:

- **More minimal** — single pulse line instead of rings
- **Monogram** — stylized "S" with integrated heartbeat
- **Stronger catalyst** — larger amber dot, fewer rings
- **Alternate accent** — swap blue primary for `#3d7eff` (MarketPulse navy theme)

Ask for a revision and we can regenerate and swap the asset.
