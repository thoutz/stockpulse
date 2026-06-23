import SwiftUI
import SwiftData
import UIKit

@main
struct MarketPulseApp: App {
    init() {
        BackgroundReportScheduler.shared.register()
        configureTabBarAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .background(Color(.systemBackground))
        }
        .modelContainer(for: [Stock.self, HistoryPoint.self])
    }

    /// Ensures any system TabView/UINavigation chrome uses standard bottom placement if introduced later.
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
