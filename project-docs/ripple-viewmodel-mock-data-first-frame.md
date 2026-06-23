# RippleViewModel mock data on first frame

## Problem
`RippleViewModel.histories` started as `[:]`, so every tab showed "No Market Data" until `loadAll()` finished. Mock data existed in `MockDataLoader` but only ran inside the async `loadAll()` path.

## Fix (data initialization timing only)

### `MockDataLoader.swift`
- Added non-throwing `static func load() -> [String: [HistoryPoint]]` that wraps `loadHistories()` for use in property initializers (cannot `try` at declaration site).

### `RippleViewModel.swift`
- Changed `histories` default from `[:]` to `MockDataLoader.load()` so mock bundle data is present before any view body runs.
### `RootTabView.swift`
- No change required: already uses `@State private var vm = RippleViewModel()` (not inside `.task` / `.onAppear`).

### `MarketPulseApp.swift`
- No ViewModel instantiation; app entry is `RootTabView()`.

## Behavior after fix
1. `RippleViewModel()` initializes with mock histories synchronously.
2. First render has chart data on all tabs.
3. `.task { await vm.loadAll() }` in `RootTabView` still runs and replaces mock data with live API data when available.

## Files touched
- `ios/MarketPulse/Services/MockDataLoader.swift`
- `ios/MarketPulse/ViewModels/RippleViewModel.swift`
