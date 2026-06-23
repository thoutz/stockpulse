import Foundation

enum MarketAnalysisEngine {

    static func indexSnapshots(histories: [String: [HistoryPoint]]) -> [IndexSnapshot] {
        IndustryCatalog.indices.compactMap { index in
            guard let history = histories[index.ticker]?.sorted(by: { $0.date < $1.date }),
                  !history.isEmpty else { return nil }
            let perf = performance(from: history, ticker: index.ticker)
            let series = normalizedSeries(history: history)
            return IndexSnapshot(
                id: index.id,
                index: index,
                currentPrice: perf.currentPrice,
                change1D: perf.change1D,
                change30D: perf.change30D,
                normalizedSeries: series
            )
        }
    }

    static func industrySnapshots(histories: [String: [HistoryPoint]]) -> [IndustrySnapshot] {
        IndustryCatalog.industries.compactMap { industry in
            let perfs = industry.tickers.compactMap { ticker -> TickerPerformance? in
                guard let history = histories[ticker]?.sorted(by: { $0.date < $1.date }),
                      !history.isEmpty else { return nil }
                let p = performance(from: history, ticker: ticker)
                return TickerPerformance(
                    id: ticker,
                    ticker: ticker,
                    change1D: p.change1D,
                    change30D: p.change30D,
                    currentPrice: p.currentPrice
                )
            }
            guard !perfs.isEmpty else { return nil }

            let avg1D = perfs.map(\.change1D).reduce(0, +) / Double(perfs.count)
            let avg30D = perfs.map(\.change30D).reduce(0, +) / Double(perfs.count)
            let upCount = perfs.filter { $0.change1D > 0 }.count
            let leader = perfs.max(by: { $0.change30D < $1.change30D })
            let laggard = perfs.min(by: { $0.change30D < $1.change30D })
            let series = industryNormalizedSeries(tickers: industry.tickers, histories: histories)

            return IndustrySnapshot(
                id: industry.id,
                industry: industry,
                avgChange1D: avg1D,
                avgChange30D: avg30D,
                breadthUp: upCount,
                breadthTotal: perfs.count,
                leader: leader,
                laggard: laggard,
                normalizedSeries: series,
                constituents: perfs.sorted { $0.change30D > $1.change30D }
            )
        }
    }

    // MARK: - Private

    private struct RawPerformance {
        let currentPrice: Double
        let change1D: Double
        let change30D: Double
    }

    private static func performance(from history: [HistoryPoint], ticker: String) -> RawPerformance {
        let last = history.last?.close ?? 0
        let prev = history.count >= 2 ? history[history.count - 2].close : last
        let first = history.first?.close ?? last
        let change1D = prev > 0 ? ((last - prev) / prev) * 100 : 0
        let change30D = first > 0 ? ((last - first) / first) * 100 : 0
        _ = ticker
        return RawPerformance(currentPrice: last, change1D: change1D, change30D: change30D)
    }

    private static func normalizedSeries(history: [HistoryPoint]) -> [(date: Date, pct: Double)] {
        guard let first = history.first?.close, first > 0 else { return [] }
        return history.map { (date: $0.date, pct: (($0.close - first) / first) * 100) }
    }

    /// Equal-weight average of constituent normalized series by date.
    private static func industryNormalizedSeries(
        tickers: [String],
        histories: [String: [HistoryPoint]]
    ) -> [(date: Date, pct: Double)] {
        var byDate: [Date: [Double]] = [:]
        for ticker in tickers {
            guard let history = histories[ticker]?.sorted(by: { $0.date < $1.date }),
                  let first = history.first?.close, first > 0 else { continue }
            for bar in history {
                let pct = ((bar.close - first) / first) * 100
                byDate[bar.date, default: []].append(pct)
            }
        }
        return byDate.keys.sorted().map { date in
            let values = byDate[date] ?? []
            let avg = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
            return (date: date, pct: avg)
        }
    }
}
