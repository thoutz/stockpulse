import Foundation

/// Bundled catalog fallbacks; runtime values come from AppCatalog (server sync).
enum CatalystCatalog {

    static let futureTickers = ["SPCX"]

    static let bundledWatchlistTickers = [
        "RKLB", "TSLA", "NVDA", "ASTS", "LUNR", "HWM", "RDW", "AMD", "AVGO",
    ]

    static let bundledCatalysts: [Catalyst] = [
        Catalyst(
            ticker: "NVDA",
            name: "NVIDIA",
            eventName: "Q1 FY2026 Earnings Beat",
            eventDate: marketDate("2026-05-28"),
            ripples: [
                RippleStock(ticker: "AMD", description: "Chip sector peer"),
                RippleStock(ticker: "AVGO", description: "AI networking"),
            ],
            events: [
                MarketEvent(date: marketDate("2026-05-28"), label: "NVDA Earnings", color: "22c55e"),
            ]
        ),
        Catalyst(
            ticker: "RKLB",
            name: "Rocket Lab",
            eventName: "Q1 Earnings + Neutron Update",
            eventDate: marketDate("2026-05-14"),
            ripples: [
                RippleStock(ticker: "ASTS", description: "Satellite connectivity play"),
                RippleStock(ticker: "LUNR", description: "Lunar infrastructure"),
                RippleStock(ticker: "HWM", description: "Aerospace components"),
                RippleStock(ticker: "RDW", description: "Spacecraft components"),
            ],
            events: [
                MarketEvent(date: marketDate("2026-05-28"), label: "NVDA Earnings", color: "22c55e"),
                MarketEvent(date: marketDate("2026-05-14"), label: "RKLB Earnings", color: "f59e0b"),
            ]
        ),
    ]

    static var catalysts: [Catalyst] { AppCatalog.shared.catalysts }
    static var watchlistTickers: [String] { AppCatalog.shared.watchlistTickers }
    static var allTickers: [String] { AppCatalog.shared.allTickers }

    /// Enable when SpaceX lists; add `SPCX` to watchlist and server catalog.
    static let spacexPlaceholder: Catalyst = Catalyst(
        ticker: "SPCX",
        name: "SpaceX",
        eventName: "IPO / Listing",
        eventDate: marketDate("2026-01-01"),
        ripples: [
            RippleStock(ticker: "RKLB", description: "Primary proxy — launch competitor"),
            RippleStock(ticker: "ASTS", description: "Satellite connectivity play"),
            RippleStock(ticker: "LUNR", description: "Lunar infrastructure"),
            RippleStock(ticker: "HWM", description: "Aerospace components"),
            RippleStock(ticker: "RDW", description: "Spacecraft components"),
        ],
        events: []
    )

    private static func marketDate(_ ymd: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        return formatter.date(from: ymd) ?? Date()
    }
}
