import SwiftUI
import UIKit

enum DS {
    enum Color {
        static let bg           = SwiftUI.Color(hex: "060a0f")
        static let surface      = SwiftUI.Color(hex: "0d1117")
        static let surface2     = SwiftUI.Color(hex: "111827")
        static let border       = SwiftUI.Color(hex: "1e2535")
        static let border2      = SwiftUI.Color(hex: "374151")

        static let textPrimary  = SwiftUI.Color(hex: "e2e8f0")
        static let textSecond   = SwiftUI.Color(hex: "9ca3af")
        static let textMuted    = SwiftUI.Color(hex: "6b7280")
        static let textDim      = SwiftUI.Color(hex: "4b5563")

        static let blue         = SwiftUI.Color(hex: "60a5fa")
        static let blueDark     = SwiftUI.Color(hex: "2563eb")
        static let green        = SwiftUI.Color(hex: "22c55e")
        static let orange       = SwiftUI.Color(hex: "f59e0b")
        static let orangeAlt    = SwiftUI.Color(hex: "f97316")
        static let red          = SwiftUI.Color(hex: "ef4444")
        static let purple       = SwiftUI.Color(hex: "a78bfa")
        static let teal         = SwiftUI.Color(hex: "34d399")

        static let chartLines: [SwiftUI.Color] = [
            SwiftUI.Color(hex: "f59e0b"),
            SwiftUI.Color(hex: "22c55e"),
            SwiftUI.Color(hex: "60a5fa"),
            SwiftUI.Color(hex: "a78bfa"),
            SwiftUI.Color(hex: "fb923c"),
            SwiftUI.Color(hex: "34d399"),
        ]

        static func verdict(_ v: RippleVerdict) -> SwiftUI.Color {
            switch v {
            case .confirmed: return green
            case .forming:   return orange
            case .failed:    return red
            case .watching:  return blue
            }
        }
    }

    enum Font {
        static func mono(_ size: CGFloat, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            let name = weight == .bold ? "IBMPlexMono-Bold" : "IBMPlexMono-Regular"
            if UIFont(name: name, size: size) != nil {
                return .custom(name, size: size)
            }
            return .system(size: size, weight: weight, design: .monospaced)
        }

        static func sans(_ size: CGFloat, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            let name: String
            switch weight {
            case .bold:     name = "DMSans-Bold"
            case .semibold: name = "DMSans-SemiBold"
            case .medium:   name = "DMSans-Medium"
            default:        name = "DMSans-Regular"
            }
            if UIFont(name: name, size: size) != nil {
                return .custom(name, size: size)
            }
            return .system(size: size, weight: weight)
        }
    }

    enum Space {
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 12
        static let lg:  CGFloat = 16
        static let xl:  CGFloat = 20
        static let xxl: CGFloat = 24
    }

    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 10
        static let xl: CGFloat = 12
    }
}

extension View {
    /// Full-screen background; content stays in safe area unless a child ignores it.
    func spScreenBackground() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                DS.Color.bg.ignoresSafeArea()
            }
    }

    /// Pins tab scroll content to screen width so children don't enable horizontal pan on the parent ScrollView.
    func spScrollContentWidth() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Vertical-only bounce for main tab scroll views.
    func spVerticalScrollAxes() -> some View {
        scrollBounceBehavior(.basedOnSize, axes: .vertical)
    }

    /// Keeps nested horizontal `ScrollView` content from widening the parent vertical scroll.
    func spContainedHorizontalScroll() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension SwiftUI.Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int & 0xFF)          / 255
        self.init(red: r, green: g, blue: b)
    }
}
