import SwiftUI
import UIKit

@main
struct StockPulseApp: App {
    @State private var vm = StockPulseViewModel()

    init() {
        BackgroundReportScheduler.shared.register()
        BackgroundReportScheduler.shared.requestNotificationPermission()
        configureChrome()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                DS.Color.bg.ignoresSafeArea()
                RootView()
                    .environment(vm)
                    .preferredColorScheme(.dark)
            }
            .onAppear { ScreenBackgroundConfigurator.applyToKeyWindow() }
        }
    }

    private func configureChrome() {
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithTransparentBackground()
        tabAppearance.backgroundColor = .clear
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
}
