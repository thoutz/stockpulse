import Foundation

struct MarketBriefInput {
    let industrySnapshots: [IndustrySnapshot]
    let indexSnapshots: [IndexSnapshot]
    let lastRefreshed: Date?
    let rippleResultsByCatalyst: [String: [RippleResult]]
}

enum MarketBriefContextBuilder {

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "America/New_York")
        return f
    }()

    static let defaultPrompt = """
    Write a concise broader-market brief (4–8 sentences) covering:
    1) How tracked industries are performing vs SPY and QQQ
    2) Which industry is leading or lagging and why (based on the data)
    3) Notable divergences or rotations between sectors
    4) Where trends appear to be heading and which tickers merit drill-down in Ripple/Watchlist
    Be direct and actionable. Cite tickers and % moves.
    """

    static func build(from input: MarketBriefInput) -> String {
        var lines: [String] = []

        lines.append("""
        You are StockPulse Market Analyst. You have industry and index snapshot data from the StockPulse iOS app.
        Data source: Massive.com daily OHLCV bars (end-of-day, US equities).
        SPY and QQQ are ETF proxies for S&P 500 and Nasdaq — not official index levels.
        Industries are hand-curated groupings of tickers the app tracks.

        Rules:
        - Answer using ONLY the data below.
        - Identify sector rotation, breadth, and divergences vs the broad market.
        - Suggest which tickers the user should explore in Ripple or Watchlist tabs.
        - Be direct. Use 4–8 sentences unless comparing many sectors.
        - Cite tickers and % moves when relevant.
        """)

        if let refreshed = input.lastRefreshed {
            lines.append("\n[Data freshness] Last refresh: \(dateFormatter.string(from: refreshed)).")
        }

        lines.append("\n=== BROAD MARKET INDICES ===")
        if input.indexSnapshots.isEmpty {
            lines.append("(No index data — SPY/QQQ may still be loading)")
        } else {
            for snap in input.indexSnapshots {
                lines.append("\(snap.index.name) (\(snap.index.ticker), \(snap.index.subtitle)): $\(fmt(snap.currentPrice)), 1D \(fmtPct(snap.change1D)), 30D \(fmtPct(snap.change30D))")
            }
        }

        lines.append("\n=== INDUSTRY SNAPSHOTS ===")
        if input.industrySnapshots.isEmpty {
            lines.append("(No industry data loaded)")
        } else {
            for snap in input.industrySnapshots {
                lines.append("\n--- \(snap.industry.name) ---")
                lines.append("Description: \(snap.industry.description)")
                lines.append("Avg 1D: \(fmtPct(snap.avgChange1D)), Avg 30D: \(fmtPct(snap.avgChange30D))")
                lines.append("Breadth: \(snap.breadthUp)/\(snap.breadthTotal) up today")
                if let leader = snap.leader {
                    lines.append("Leader: \(leader.ticker) 30D \(fmtPct(leader.change30D))")
                }
                if let laggard = snap.laggard {
                    lines.append("Laggard: \(laggard.ticker) 30D \(fmtPct(laggard.change30D))")
                }
                lines.append("Constituents:")
                for c in snap.constituents {
                    lines.append("  \(c.ticker): $\(fmt(c.currentPrice)), 1D \(fmtPct(c.change1D)), 30D \(fmtPct(c.change30D))")
                }
            }
        }

        lines.append("\n=== RIPPLE NETWORK CONTEXT ===")
        for catalyst in CatalystCatalog.catalysts {
            let results = input.rippleResultsByCatalyst[catalyst.ticker] ?? []
            if results.isEmpty { continue }
            lines.append("\(catalyst.ticker) ripples:")
            for r in results {
                lines.append("  \(r.rippleTicker): \(r.verdict.rawValue), post \(fmtPct(r.postEventPct))")
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func fmt(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private static func fmtPct(_ value: Double) -> String {
        String(format: "%+.1f%%", value)
    }
}

enum MarketBriefStore {
    private static let textKey = "stockpulse.marketBrief.text"
    private static let dateKey = "stockpulse.marketBrief.generatedAt"

    static func save(_ brief: MarketBrief) {
        UserDefaults.standard.set(brief.text, forKey: textKey)
        UserDefaults.standard.set(brief.generatedAt.timeIntervalSince1970, forKey: dateKey)
    }

    static func isErrorBrief(_ text: String) -> Bool {
        text.hasPrefix("Could not generate market brief")
    }

    static func load() -> MarketBrief? {
        guard let text = UserDefaults.standard.string(forKey: textKey),
              !text.isEmpty,
              !isErrorBrief(text) else { return nil }
        let interval = UserDefaults.standard.double(forKey: dateKey)
        let date = interval > 0 ? Date(timeIntervalSince1970: interval) : Date.distantPast
        return MarketBrief(text: text, generatedAt: date)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: textKey)
        UserDefaults.standard.removeObject(forKey: dateKey)
    }
}
