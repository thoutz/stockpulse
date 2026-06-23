# MarketPulse — Xcode Project Setup

**Date:** June 2026  
**Bundle ID:** `com.marketpulse.app`  
**Background task ID:** `com.marketpulse.morningreport`

---

## What was done

1. Reorganized flat `ios/*.swift` into `ios/MarketPulse/` (App, Models, Services, ViewModels, Views, Resources).
2. Renamed app entry to `MarketPulseApp.swift` with SwiftData `modelContainer`, background scheduler register/schedule.
3. Added missing `TrendCompareView.swift`, `MockDataLoader.swift`, `RippleViewModel+Preview.swift`.
4. Wired `RippleViewModel.loadAll()` to use mock data when `POLYGON_API_KEY` is empty or API fails.
5. Generated `MarketPulse.xcodeproj` via XcodeGen (`project.yml`).
6. Fixed Swift Charts compile issues (explicit `FloatingPointFormatStyle` for percent axis; `Color.blue` vs `.secondary`).

---

## Open in Xcode

```bash
open "/Users/tristan/Documents/App Projects/stock market app/ios/MarketPulse.xcodeproj"
```

1. Select scheme **MarketPulse**.
2. Choose any **iOS 17+** simulator.
3. Build (⌘B) / Run (⌘R). Signing is preconfigured — you should **not** need to re-select a team after `xcodegen generate`.

Phase 1 runs entirely on `MockData.json` with no API keys.

---

## Folder layout

```
ios/
├── MarketPulse.xcodeproj
├── project.yml              # Regenerate project after file changes
├── Config.xcconfig.example    # Committed template
├── Config.xcconfig            # Local secrets (gitignored)
├── .gitignore
└── MarketPulse/
    ├── App/
    ├── Models/
    ├── Services/
    ├── ViewModels/
    ├── Views/
    └── Resources/
        ├── MockData.json
        ├── Info.plist
        └── Assets.xcassets
```

---

## API keys (Phase 2)

```bash
cp ios/Config.xcconfig.example ios/Config.xcconfig
```

Edit `ios/Config.xcconfig`:

```
POLYGON_API_KEY = your_massive_polygon_key
GROQ_API_KEY = your_groq_key
ANTHROPIC_API_KEY = your_anthropic_key
```

Keys flow: `Config.xcconfig` → `Info.plist` (`$(POLYGON_API_KEY)`) → `Bundle.main` at runtime.

---

## Regenerate Xcode project

After adding/moving Swift files:

```bash
cd ios && xcodegen generate
```

---

## Code signing (persistent)

Signing is **hardcoded in** [`ios/project.yml`](ios/project.yml), not chosen manually in Xcode each time:

| Setting | Value |
|---------|--------|
| `DEVELOPMENT_TEAM` | `3U49743Z3T` (TRISTAN JAMES HOUTZ) |
| `CODE_SIGN_STYLE` | `Automatic` |
| `PRODUCT_BUNDLE_IDENTIFIER` | `com.marketpulse.app` |

`xcodegen generate` writes these into `project.pbxproj`, including `TargetAttributes.DevelopmentTeam`, so the **Signing & Capabilities** team dropdown stays set.

**To change team:** edit `DEVELOPMENT_TEAM` and `attributes.DevelopmentTeam` in `project.yml`, then run `xcodegen generate` again.

**API keys only** use gitignored [`ios/Config.xcconfig`](ios/Config.xcconfig). `Signing.xcconfig` is optional legacy; signing no longer depends on it.

---

## Mock data flow

- `MockDataLoader.loadHistories()` reads `MarketPulse/Resources/MockData.json`.
- Builds `[String: [HistoryPoint]]` from `dates` + `prices` arrays.
- `RippleViewModel.loadAll()` uses mock when API key is empty; falls back on network error.

---

## Previews

`RippleViewModel.preview` loads mock data with no network. Used in `#Preview` for Ripple, Watchlist, and Trends tabs.

---

## CLI build

```bash
cd ios
xcodebuild -project MarketPulse.xcodeproj -scheme MarketPulse \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build
```

**Status:** BUILD SUCCEEDED (verified June 2026).

---

## Next steps (from product plan)

| Phase | Work |
|-------|------|
| 2 | Live Massive/Polygon data with `POLYGON_API_KEY` |
| 3 | Groq AI, notification permissions, 6AM background report |
| 4 | WidgetKit, custom catalysts, TestFlight |
