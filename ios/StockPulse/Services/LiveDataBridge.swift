import Foundation

enum LiveDataBridge {

    static func normalizedSeries(
        tickers: [String],
        histories: [String: [HistoryPoint]]
    ) -> [(ticker: String, points: [(date: Date, pct: Double)])] {
        tickers.compactMap { ticker in
            guard let history = histories[ticker]?.sorted(by: { $0.date < $1.date }),
                  let first = history.first?.close, first > 0 else { return nil }
            let points = history.map { (date: $0.date, pct: (($0.close - first) / first) * 100) }
            return (ticker: ticker, points: points)
        }
    }

    static func periodChangePct(ticker: String, histories: [String: [HistoryPoint]]) -> Double? {
        guard let history = histories[ticker]?.sorted(by: { $0.date < $1.date }),
              let first = history.first?.close,
              let last = history.last?.close,
              first > 0 else { return nil }
        return ((last - first) / first) * 100
    }

    static func changePct(from first: Double, to last: Double) -> Double? {
        guard first > 0 else { return nil }
        return ((last - first) / first) * 100
    }

    static func nearestBar(to date: Date, in bars: [HistoryPoint]) -> HistoryPoint? {
        guard !bars.isEmpty else { return nil }
        return bars.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
    }

    static func sparklinePoints(
        ticker: String,
        histories: [String: [HistoryPoint]]
    ) -> [(date: Date, pct: Double)] {
        guard let history = histories[ticker]?.sorted(by: { $0.date < $1.date }),
              let first = history.first?.close,
              first > 0 else { return [] }
        return history.map { (date: $0.date, pct: (($0.close - first) / first) * 100) }
    }

    static func watchItems(
        tickers: [String],
        histories: [String: [HistoryPoint]],
        catalysts: [Catalyst]
    ) -> [WatchItem] {
        tickers.map { ticker in
            let history = (histories[ticker] ?? [])
                .sorted { $0.date < $1.date }
                .map { PricePoint(date: $0.date, close: $0.close) }
            let badges: [(String, RippleVerdict)] = catalysts
                .filter { $0.ripples.contains(where: { $0.ticker == ticker }) }
                .map { catalyst in
                    let verdict = RippleEngine.analyze(catalyst: catalyst, histories: histories)
                        .first(where: { $0.rippleTicker == ticker })?.verdict ?? .watching
                    return (catalyst.ticker, verdict)
                }
            return WatchItem(ticker: ticker, history: history, rippleBadges: badges)
        }
    }
}
