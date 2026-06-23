import Foundation

/// Snapshot of all in-app data passed to Groq for analyst questions.
struct AIAppContext {
    let histories: [String: [HistoryPoint]]
    let watchItems: [WatchItem]
    let catalysts: [Catalyst]
    let rippleResultsByCatalyst: [String: [RippleResult]]
    let selectedCatalystIndex: Int
    let lastRefreshed: Date?
    let futureTickers: [String]
}

enum AIContextBuilder {

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "America/New_York")
        return f
    }()

    static func build(from ctx: AIAppContext) -> String {
        var lines: [String] = []

        lines.append("""
        You are StockPulse AI Analyst. You have the COMPLETE live state of the StockPulse iOS app below.
        Data source: Massive.com daily OHLCV bars (end-of-day, US equities).
        The app tracks catalyst events (earnings, etc.) and "ripple" stocks that historically move with the catalyst.
        Verdicts: CONFIRMED, FORMING, FAILED, WATCHING — computed from pre/post-event % moves vs the catalyst.

        Rules:
        - Answer using ONLY the data below. If asked about a ticker not listed, say it is not in the app dataset.
        - You may compare any tickers, catalysts, ripples, watchlist names, or price paths in the data.
        - Be direct and actionable. Use 2–8 sentences; longer if comparing multiple stocks.
        - Cite tickers and % moves when relevant.
        """)

        if let refreshed = ctx.lastRefreshed {
            lines.append("\n[Data freshness] Last Massive refresh: \(dateFormatter.string(from: refreshed)) (device local time).")
        }

        if !ctx.futureTickers.isEmpty {
            lines.append("[Future] Not yet in live data: \(ctx.futureTickers.joined(separator: ", ")) (enable when listed).")
        }

        lines.append("\n=== WATCHLIST (\(ctx.watchItems.count) tickers) ===")
        for item in ctx.watchItems.sorted(by: { $0.ticker < $1.ticker }) {
            var row = "\(item.ticker): $\(fmt(item.currentPrice)), 1D \(fmtPct(item.change1D)), 30D \(fmtPct(item.change30D))"
            if !item.rippleBadges.isEmpty {
                let badges = item.rippleBadges.map { "\($0.catalystTicker)=\($0.verdict.rawValue)" }.joined(separator: "; ")
                row += " | ripple badges: \(badges)"
            }
            lines.append(row)
        }

        lines.append("\n=== DAILY PRICE HISTORY (Massive closes, most recent last) ===")
        for ticker in ctx.histories.keys.sorted() {
            guard let bars = ctx.histories[ticker], !bars.isEmpty else { continue }
            lines.append(formatTickerHistory(ticker: ticker, bars: bars))
        }

        lines.append("\n=== CATALYSTS & RIPPLE NETWORKS ===")
        for (idx, catalyst) in ctx.catalysts.enumerated() {
            let selected = idx == ctx.selectedCatalystIndex ? " [USER SELECTED ON RIPPLE TAB]" : ""
            lines.append("\n--- \(catalyst.ticker) (\(catalyst.name))\(selected) ---")
            lines.append("Event: \(catalyst.eventName) on \(dateFormatter.string(from: catalyst.eventDate))")
            if let catHist = ctx.histories[catalyst.ticker] {
                let post = RippleEngine.postEventChange(history: catHist, eventDate: catalyst.eventDate)
                lines.append("Catalyst post-event move: \(fmtPct(post))")
            }
            if !catalyst.events.isEmpty {
                let ev = catalyst.events.map { "\(dateFormatter.string(from: $0.date)) \($0.label)" }.joined(separator: "; ")
                lines.append("Chart markers: \(ev)")
            }
            lines.append("Tracked ripples:")
            for rip in catalyst.ripples {
                lines.append("  - \(rip.ticker): \(rip.description)")
            }
            let results = ctx.rippleResultsByCatalyst[catalyst.ticker] ?? []
            if results.isEmpty {
                lines.append("Ripple verification: (no results — data may still be loading)")
            } else {
                lines.append("Ripple verification:")
                for r in results {
                    lines.append("  \(r.rippleTicker): \(r.verdict.rawValue), pre \(fmtPct(r.preEventPct)), post \(fmtPct(r.postEventPct)) — \(r.rippleDescription)")
                }
            }
        }

        lines.append("\n=== ALL TICKERS IN APP ===")
        lines.append(ctx.histories.keys.sorted().joined(separator: ", "))

        return lines.joined(separator: "\n")
    }

    private static func formatTickerHistory(ticker: String, bars: [HistoryPoint]) -> String {
        let sorted = bars.sorted { $0.date < $1.date }
        let recent = sorted.suffix(30)
        let series = recent.map { "\(dateFormatter.string(from: $0.date)):\(fmt($0.close))" }.joined(separator: ", ")
        let first = sorted.first?.close ?? 0
        let last = sorted.last?.close ?? 0
        let periodPct = first > 0 ? ((last - first) / first) * 100 : 0
        var line = "\(ticker) (\(recent.count)d closes, period \(fmtPct(periodPct))): \(series)"
        if sorted.count > 30 {
            line += " … (older bars omitted)"
        }
        return line
    }

    private static func fmt(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private static func fmtPct(_ value: Double) -> String {
        String(format: "%+.1f%%", value)
    }
}
