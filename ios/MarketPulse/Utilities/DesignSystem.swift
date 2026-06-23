import SwiftUI

// MARK: - Layout constants

enum DesignSystem {
    static let horizontalPadding: CGFloat = 20
    static let tabBarClearance: CGFloat = 84

    static let watchlistTickerWidth: CGFloat = 90
    static let watchlistPriceWidth: CGFloat = 84
    static let watchlistSparklineWidth: CGFloat = 76
    static let watchlistChange30DWidth: CGFloat = 60

    static let cardCornerRadius: CGFloat = 16
    static let smallCornerRadius: CGFloat = 10
    static let cardPadding: CGFloat = 16
}

// MARK: - Colors
// Navy-midnight dark theme: surfaces have a blue tint so they read as
// "night mode" rather than plain black. Accent is vivid iOS blue.

extension Color {
    static let mpBackground      = Color(hex: "#080d18")
    static let mpSurface         = Color(hex: "#0d1628")
    static let mpSurfaceSelected = Color(hex: "#162031")
    static let mpBorder          = Color(hex: "#1d2d48")
    static let mpTextPrimary     = Color(hex: "#e8f1fc")
    static let mpTextSecondary   = Color(hex: "#6880a4")
    static let mpTextMuted       = Color(hex: "#374c66")
    static let mpAccent          = Color(hex: "#3d7eff")
    static let mpPositive        = Color(hex: "#00c97a")
    static let mpNegative        = Color(hex: "#ff3b5c")
    static let mpAmber           = Color(hex: "#f5a623")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8)  & 0xFF) / 255
            b = Double(int & 0xFF)          / 255
        default:
            r = 1; g = 1; b = 1
        }
        self.init(red: r, green: g, blue: b)
    }

    static func mpDelta(_ value: Double) -> Color {
        value >= 0 ? .mpPositive : .mpNegative
    }
}

// MARK: - Verdict colors

extension RippleVerdict {
    var swiftColor: Color { Color(hex: color) }
    var backgroundColor: Color { swiftColor.opacity(0.12) }
}

// MARK: - Fonts
// Rule: mpMono for tickers/prices/percentages (data).
//       mpBody for all prose, labels, descriptions.
//       mpDisplay for hero/headline numbers (rounded bold).

extension Font {
    static func mpMono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func mpDisplay(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func mpBody(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}

// MARK: - View modifiers

extension View {
    func mpScreenBackground() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ZStack {
                    Color.mpBackground
                    // Subtle accent glow from top for depth — barely visible,
                    // breaks the dead-black monotony.
                    RadialGradient(
                        colors: [Color.mpAccent.opacity(0.06), .clear],
                        center: .top,
                        startRadius: 0,
                        endRadius: 480
                    )
                }
                .ignoresSafeArea()
            )
    }

    func mpCard(padding amount: CGFloat = DesignSystem.cardPadding) -> some View {
        padding(amount)
            .background(Color.mpSurface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.cardCornerRadius)
                    .strokeBorder(Color.mpBorder, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.4), radius: 14, x: 0, y: 6)
    }

    func mpSectionLabel() -> some View {
        font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color.mpTextMuted)
            .tracking(0.8)
            .textCase(.uppercase)
    }

    func mpRowPadding() -> some View {
        padding(.vertical, 10)
            .padding(.horizontal, DesignSystem.horizontalPadding)
    }

    func mpDeltaColor(_ value: Double) -> some View {
        foregroundStyle(Color.mpDelta(value))
    }
}
