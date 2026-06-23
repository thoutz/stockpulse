import SwiftUI

struct RootView: View {
    @Environment(StockPulseViewModel.self) private var vm

    var body: some View {
        @Bindable var bindVm = vm
        TabView(selection: $bindVm.selectedTab) {
            PulseView()
                .tag(AppTab.pulse)
            WatchlistView()
                .tag(AppTab.watchlist)
            AnalystView()
                .tag(AppTab.analyst)
            TradeDashboardView()
                .tag(AppTab.trade)
            AIAnalystView()
                .tag(AppTab.ai)
        }
        .toolbar(.hidden, for: .tabBar)
        .tint(DS.Color.blue)
        .animation(.none, value: bindVm.selectedTab)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            StockPulseTabBar(selection: $bindVm.selectedTab)
        }
        .onAppear {
            vm.loadFromCacheIfAvailable()
        }
        .task {
            vm.loadFromCacheIfAvailable()
            await vm.refresh()
        }
        .task {
            await autoRefreshLoop()
        }
        .onAppear {
            ScreenBackgroundConfigurator.applyToKeyWindow()
            BackgroundReportScheduler.shared.schedule()
        }
    }

    private func autoRefreshLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(60))
            await vm.lightRefresh()
        }
    }
}
