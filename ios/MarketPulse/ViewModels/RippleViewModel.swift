import Foundation
import Observation

@Observable
class RippleViewModel {

    // MARK: - State
    var histories: [String: [HistoryPoint]] = MockDataLoader.load()
    var rippleResults: [String: [RippleResult]] = [:]
    var isLoading = false
    var errorMessage: String?
    var lastRefreshed: Date?

    var catalysts: [Catalyst] = Catalyst.defaults
    var selectedCatalystIndex = 0
    var selectedCatalyst: Catalyst { catalysts[selectedCatalystIndex] }

    // AI
    var aiQuery = ""
    var aiResponse = ""
    var aiLoading = false

    var allTickers: [String] {
        let base = Catalyst.defaultWatchlist
        let rippleTickers = catalysts.flatMap { $0.ripples.map(\.rippleTicker) }
        return Array(Set(base + rippleTickers)).sorted()
    }

    // MARK: - Load

    @MainActor
    func loadAll() async {
        isLoading = true
        errorMessage = nil

        let rawKey = Bundle.main.object(forInfoDictionaryKey: "POLYGON_API_KEY") as? String ?? ""
        let apiKey = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            if apiKey.isEmpty {
                histories = try MockDataLoader.loadHistories()
            } else {
                histories = try await MarketDataService.shared.fetchHistories(tickers: allTickers, days: 30)
                let hasData = histories.values.contains { !$0.isEmpty }
                if !hasData {
                    histories = try MockDataLoader.loadHistories()
                    #if DEBUG
                    print("MarketDataService returned empty data (using mock)")
                    #endif
                }
            }
            computeAllVerdicts()
            lastRefreshed = Date()
        } catch {
            do {
                histories = try MockDataLoader.loadHistories()
                computeAllVerdicts()
                lastRefreshed = Date()
                #if DEBUG
                errorMessage = "Using mock data: \(error.localizedDescription)"
                #endif
            } catch {
                errorMessage = "Failed to load market data: \(error.localizedDescription)"
            }
        }

        isLoading = false
    }

    // MARK: - Compute verdicts for all catalysts

    private func computeAllVerdicts() {
        for catalyst in catalysts {
            rippleResults[catalyst.ticker] = RippleEngine.analyze(
                catalyst: catalyst,
                histories: histories
            )
        }
    }

    var currentRippleResults: [RippleResult] {
        rippleResults[selectedCatalyst.ticker] ?? []
    }

    func normalizedHistory(for ticker: String, from baseline: Date? = nil) -> [(date: Date, pctChange: Double)] {
        guard let history = histories[ticker] else { return [] }
        return RippleEngine.normalize(history: history, from: baseline)
    }

    func stats(for ticker: String) -> (price: Double, change1D: Double, change30D: Double) {
        let history = histories[ticker] ?? []
        let sorted = history.sorted { $0.date < $1.date }
        let price = sorted.last?.close ?? 0
        let prev = sorted.count >= 2 ? sorted[sorted.count - 2].close : price
        let first = sorted.first?.close ?? price
        let c1d = prev > 0 ? ((price - prev) / prev) * 100 : 0
        let c30d = first > 0 ? ((price - first) / first) * 100 : 0
        return (price, c1d, c30d)
    }

    func rippleBadges(for ticker: String) -> [(catalystTicker: String, verdict: RippleVerdict)] {
        catalysts.compactMap { catalyst in
            guard catalyst.ripples.contains(where: { $0.rippleTicker == ticker }) else { return nil }
            let verdict = rippleResults[catalyst.ticker]?
                .first(where: { $0.rippleTicker == ticker })?.verdict ?? .watching
            return (catalystTicker: catalyst.ticker, verdict: verdict)
        }
    }

    @MainActor
    func askAI() async {
        guard !aiQuery.isEmpty else { return }
        aiLoading = true
        aiResponse = ""
        do {
            let context = await AIAnalystService.shared.buildContext(
                histories: histories,
                rippleResults: rippleResults.values.flatMap { $0 },
                catalysts: catalysts
            )
            aiResponse = try await AIAnalystService.shared.query(prompt: aiQuery, context: context)
        } catch {
            aiResponse = "Error: \(error.localizedDescription)"
        }
        aiLoading = false
    }
}
