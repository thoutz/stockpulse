import UIKit

enum ScreenBackgroundConfigurator {
    private static let backgroundUIColor = UIColor(
        red: 6 / 255,
        green: 10 / 255,
        blue: 15 / 255,
        alpha: 1
    )

    static func applyToKeyWindow() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first else { return }
        for window in scene.windows {
            window.backgroundColor = backgroundUIColor
        }
    }
}
