import SwiftUI

struct RootTabView: View {
    @State private var vm = RippleViewModel()
    @State private var selectedTab: AppTab = .ripple

    var body: some View {
        Group {
            switch selectedTab {
            case .ripple:
                RippleTrackerView()
            case .watchlist:
                WatchlistView()
            case .trends:
                TrendCompareView()
            case .ai:
                AIAnalystView()
            }
        }
        .mpScreenBackground()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AppTabBar(selection: $selectedTab)
        }
        .environment(vm)
        .preferredColorScheme(.dark)
        .tint(.mpAccent)
        .task { await vm.loadAll() }
        .onAppear {
            BackgroundReportScheduler.shared.schedule()
        }
    }
}
