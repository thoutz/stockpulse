import Foundation
import SwiftUI

/// Static industry groupings for the Market tab. Massive supplies prices at runtime.
enum IndustryCatalog {

    static let indexTickers = ["SPY", "QQQ"]

    static let companyNames: [String: String] = [
        "SPY": "SPDR S&P 500 ETF",
        "QQQ": "Invesco QQQ Trust",
        "NVDA": "NVIDIA",
        "AMD": "AMD",
        "AVGO": "Broadcom",
        "RKLB": "Rocket Lab",
        "ASTS": "AST SpaceMobile",
        "LUNR": "Intuitive Machines",
        "RDW": "Redwire",
        "HWM": "Howmet Aerospace",
        "TSLA": "Tesla",
    ]

    static let indexBlurbs: [String: String] = [
        "spy": "Tracks the S&P 500 — 500 large-cap US companies across every major sector.",
        "qqq": "Tracks the Nasdaq-100 — mega-cap tech and growth names that drive risk appetite.",
    ]

    static let bundledIndustryAccentHex: [String: String] = [
        "semiconductors": "a78bfa",
        "space": "60a5fa",
        "ev": "f59e0b",
    ]

    static let indexAccentHex: [String: String] = [
        "spy": "34d399",
        "qqq": "60a5fa",
    ]

    static let indices: [MarketIndex] = [
        MarketIndex(
            id: "spy",
            ticker: "SPY",
            name: "S&P 500",
            subtitle: "SPY ETF proxy"
        ),
        MarketIndex(
            id: "qqq",
            ticker: "QQQ",
            name: "Nasdaq",
            subtitle: "QQQ ETF proxy"
        ),
    ]

    static let bundledIndustries: [Industry] = [
        Industry(
            id: "semiconductors",
            name: "Semiconductors",
            description: "AI chips, networking, and compute",
            tickers: ["NVDA", "AMD", "AVGO"]
        ),
        Industry(
            id: "space",
            name: "Space & Aerospace",
            description: "Launch, satellites, and defense components",
            tickers: ["RKLB", "ASTS", "LUNR", "RDW", "HWM"]
        ),
        Industry(
            id: "ev",
            name: "EV & Auto",
            description: "Electric vehicles and mobility",
            tickers: ["TSLA"]
        ),
    ]

    static var industries: [Industry] { AppCatalog.shared.industries }

    /// All tickers needed for market analysis (indices + industry constituents).
    static var allMarketTickers: [String] {
        Array(Set(
            indexTickers
            + industries.flatMap(\.tickers)
        )).sorted()
    }

    static func industry(for ticker: String) -> Industry? {
        industries.first { $0.tickers.contains(ticker.uppercased()) }
    }

    static func displayName(for ticker: String) -> String {
        companyNames[ticker.uppercased()] ?? ticker.uppercased()
    }

    static func accentColor(for industryId: String) -> Color {
        let hex = AppCatalog.shared.industryAccentHex[industryId]
            ?? bundledIndustryAccentHex[industryId]
            ?? "34d399"
        return Color(hex: hex)
    }

    static func indexAccentColor(for indexId: String) -> Color {
        let hex = indexAccentHex[indexId] ?? "34d399"
        return Color(hex: hex)
    }

    static func catalystLinks(for ticker: String) -> [(catalystTicker: String, role: String)] {
        let sym = ticker.uppercased()
        var links: [(String, String)] = []
        for catalyst in CatalystCatalog.catalysts {
            if catalyst.ticker == sym {
                links.append((catalyst.ticker, "Catalyst"))
            }
            if let rip = catalyst.ripples.first(where: { $0.ticker == sym }) {
                links.append((catalyst.ticker, rip.description))
            }
        }
        return links
    }
}
