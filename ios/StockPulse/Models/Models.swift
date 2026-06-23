import Foundation

struct PricePoint: Identifiable {
    let id = UUID()
    let date: Date
    let close: Double
}

enum RippleVerdict: String {
    case confirmed = "CONFIRMED"
    case forming   = "FORMING"
    case failed    = "FAILED"
    case watching  = "WATCHING"

    var icon: String {
        switch self {
        case .confirmed: return "checkmark.circle.fill"
        case .forming:   return "circle.lefthalf.filled"
        case .failed:    return "xmark.circle.fill"
        case .watching:  return "eye.circle"
        }
    }
    var label: String { rawValue }
}

struct RippleStock: Identifiable {
    let id = UUID()
    let ticker: String
    let description: String
}

struct MarketEvent: Identifiable {
    let id = UUID()
    let date: Date
    let label: String
    let color: String
}

struct Catalyst: Identifiable {
    let id = UUID()
    let ticker: String
    let name: String
    let eventName: String
    let eventDate: Date
    let ripples: [RippleStock]
    let events: [MarketEvent]
}

struct RippleResult: Identifiable {
    let id = UUID()
    let catalystTicker: String
    let rippleTicker: String
    let rippleDescription: String
    let verdict: RippleVerdict
    let preEventPct: Double
    let postEventPct: Double

    var explanation: String {
        switch verdict {
        case .confirmed:
            return "\(rippleTicker) rose \(String(format: "%.1f", postEventPct))% after the \(catalystTicker) event. Ripple confirmed."
        case .forming:
            return "\(rippleTicker) showing +\(String(format: "%.1f", postEventPct))% drift. Not yet decisive — watch for acceleration."
        case .failed:
            return "\(rippleTicker) did not follow \(catalystTicker). Sector correlation broke down."
        case .watching:
            return "Catalyst still early. Pre-event move \(String(format: "%.1f", preEventPct))% suggests anticipation building."
        }
    }
}

struct WatchItem: Identifiable {
    let id = UUID()
    let ticker: String
    let history: [PricePoint]
    let rippleBadges: [(catalystTicker: String, verdict: RippleVerdict)]

    var currentPrice: Double  { history.last?.close ?? 0 }
    var previousPrice: Double { history.count >= 2 ? history[history.count - 2].close : currentPrice }
    var firstPrice: Double    { history.first?.close ?? currentPrice }

    var change1D: Double  { previousPrice > 0 ? ((currentPrice - previousPrice) / previousPrice) * 100 : 0 }
    var change30D: Double { firstPrice > 0 ? ((currentPrice - firstPrice) / firstPrice) * 100 : 0 }

    var normalizedHistory: [(date: Date, pct: Double)] {
        guard firstPrice > 0 else { return [] }
        return history.map { pt in
            (date: pt.date, pct: ((pt.close - firstPrice) / firstPrice) * 100)
        }
    }
}

/// Live API bar (Phase 2).
struct HistoryPoint: Identifiable {
    let id = UUID()
    let date: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Int64
}

// MARK: - Tab bar

enum AppTab: Int, CaseIterable, Hashable {
    case pulse = 0
    case watchlist = 1
    case analyst = 2
    case trade = 3
    case ai = 4

    var title: String {
        switch self {
        case .pulse: return "Pulse"
        case .watchlist: return "Monitor"
        case .analyst: return "Analyst"
        case .trade: return "Trade"
        case .ai: return "AI"
        }
    }

    var icon: String {
        switch self {
        case .pulse: return "waveform.path.ecg"
        case .watchlist: return "eye"
        case .analyst: return "chart.bar.doc.horizontal"
        case .trade: return "dollarsign.circle"
        case .ai: return "brain.head.profile"
        }
    }

    var selectedIcon: String {
        switch self {
        case .trade: return "dollarsign.circle.fill"
        default: return icon
        }
    }
}

struct Industry: Identifiable {
    let id: String
    let name: String
    let description: String
    let tickers: [String]
}

struct MarketIndex: Identifiable {
    let id: String
    let ticker: String
    let name: String
    let subtitle: String
}

struct TickerPerformance: Identifiable {
    let id: String
    let ticker: String
    let change1D: Double
    let change30D: Double
    let currentPrice: Double
}

struct IndustrySnapshot: Identifiable {
    let id: String
    let industry: Industry
    let avgChange1D: Double
    let avgChange30D: Double
    let breadthUp: Int
    let breadthTotal: Int
    let leader: TickerPerformance?
    let laggard: TickerPerformance?
    let normalizedSeries: [(date: Date, pct: Double)]
    let constituents: [TickerPerformance]
}

struct IndexSnapshot: Identifiable {
    let id: String
    let index: MarketIndex
    let currentPrice: Double
    let change1D: Double
    let change30D: Double
    let normalizedSeries: [(date: Date, pct: Double)]
}

struct MarketBrief {
    let text: String
    let generatedAt: Date
}

struct NewsArticle: Identifiable, Equatable {
    let id: String
    let symbol: String
    let headline: String
    let summary: String?
    let source: String?
    let url: URL
    let publishedAt: Date
    let sentimentScore: Double?

    var sentimentLabel: String? {
        guard let score = sentimentScore else { return nil }
        if score > 0.15 { return "Bullish" }
        if score < -0.15 { return "Bearish" }
        return "Neutral"
    }
}

enum MarketDetailSelection: Equatable {
    case ticker(String)
    case index(String)
}

// MARK: - Monitor tab

enum MonitorTier: String, CaseIterable {
    case hot
    case warm
    case cold

    var label: String {
        switch self {
        case .hot: return "Hot · Live (~30s)"
        case .warm: return "Warm · ~2 min"
        case .cold: return "Background · ~5 min"
        }
    }

    var icon: String {
        switch self {
        case .hot: return "flame.fill"
        case .warm: return "clock"
        case .cold: return "moon"
        }
    }
}

struct MonitorSymbolRow: Identifiable {
    let id: String
    let symbol: String
    let name: String
    let tier: MonitorTier
    let sectorId: String?
    let price: Double
    let change1D: Double
    let change5M: Double?
    let change30D: Double
    let lastUpdated: Date?
    let lagSeconds: Double?
    let isFavorite: Bool
}
