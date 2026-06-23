import Foundation

/// Server-backed catalog with bundled fallbacks. Sync on app launch / refresh.
@Observable
final class AppCatalog {
    static let shared = AppCatalog()

    private(set) var catalysts: [Catalyst] = CatalystCatalog.bundledCatalysts
    private(set) var industries: [Industry] = IndustryCatalog.bundledIndustries
    private(set) var industryAccentHex: [String: String] = IndustryCatalog.bundledIndustryAccentHex
    private(set) var lastSynced: Date?
    private(set) var usesServerCatalog = false

    private init() {}

    func syncFromServer() async {
        guard StockPulseAPIService.isConfigured else { return }
        do {
            async let sectorsTask = StockPulseAPIService.shared.fetchCatalogSectors()
            async let catalystsTask = StockPulseAPIService.shared.fetchCatalogCatalysts()
            let (sectors, apiCatalysts) = try await (sectorsTask, catalystsTask)
            apply(sectors: sectors, apiCatalysts: apiCatalysts)
            usesServerCatalog = true
            lastSynced = Date()
        } catch {
            // Keep bundled fallbacks when offline or API error.
        }
    }

    var watchlistTickers: [String] {
        let fromCatalysts = catalysts.flatMap { c in
            [c.ticker] + c.ripples.map(\.ticker)
        }
        return Array(Set(CatalystCatalog.bundledWatchlistTickers + fromCatalysts)).sorted()
    }

    var allTickers: [String] {
        Array(Set(
            watchlistTickers
            + catalysts.flatMap { [$0.ticker] + $0.ripples.map(\.ticker) }
            + IndustryCatalog.indexTickers
        )).sorted()
    }

    private func apply(sectors: APICatalogSectorsResponse, apiCatalysts: APICatalogCatalystsResponse) {
        if !sectors.sectors.isEmpty {
            industries = sectors.sectors.map {
                Industry(
                    id: $0.id,
                    name: $0.name,
                    description: $0.description,
                    tickers: $0.tickers
                )
            }
            var accents = IndustryCatalog.bundledIndustryAccentHex
            for sector in sectors.sectors {
                accents[sector.id] = sector.accentHex
            }
            industryAccentHex = accents
        }

        let mapped = apiCatalysts.catalysts
            .filter(\.active)
            .compactMap(mapCatalyst)
        if !mapped.isEmpty {
            catalysts = mapped
        }
    }

    private func mapCatalyst(_ row: APICatalogCatalyst) -> Catalyst? {
        guard let eventDate = Self.parseEventDate(row.eventDate) else { return nil }
        let ripples = row.ripples.map { RippleStock(ticker: $0.ticker, description: $0.description) }
        let eventLabel = row.eventName
        let events = [
            MarketEvent(
                date: eventDate,
                label: eventLabel,
                color: row.confidenceScore != nil && row.confidenceScore! >= 50 ? "22c55e" : "f59e0b"
            ),
        ]
        return Catalyst(
            ticker: row.ticker,
            name: row.name,
            eventName: row.eventName,
            eventDate: eventDate,
            ripples: ripples,
            events: events
        )
    }

    private static func parseEventDate(_ ymd: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        return formatter.date(from: ymd)
    }
}
