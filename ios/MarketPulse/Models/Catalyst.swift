// Models/Catalyst.swift
import Foundation

// MARK: - RippleVerdict

enum RippleVerdict: String, CaseIterable {
    case confirmed = "CONFIRMED"
    case forming   = "FORMING"
    case failed    = "FAILED"
    case watching  = "WATCHING"

    var color: String {
        switch self {
        case .confirmed: return "#22c55e"
        case .forming:   return "#f59e0b"
        case .failed:    return "#ef4444"
        case .watching:  return "#60a5fa"
        }
    }
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

// MARK: - RippleRelation

struct RippleRelation: Identifiable, Codable {
    let id: UUID
    let rippleTicker: String
    let description: String       // "Primary proxy — launch competitor"

    init(ticker: String, description: String) {
        self.id = UUID()
        self.rippleTicker = ticker
        self.description = description
    }
}

// MARK: - MarketEvent

struct MarketEvent: Identifiable, Codable {
    let id: UUID
    let date: Date
    let label: String
    let color: String             // hex

    init(date: Date, label: String, color: String) {
        self.id = UUID()
        self.date = date
        self.label = label
        self.color = color
    }
}

// MARK: - Catalyst

struct Catalyst: Identifiable, Codable {
    let id: UUID
    let ticker: String
    let name: String
    let eventName: String         // "IPO Filing + Roadshow"
    let eventDate: Date
    var ripples: [RippleRelation]
    var events: [MarketEvent]     // additional events in the chain

    init(ticker: String, name: String, eventName: String, eventDate: Date,
         ripples: [RippleRelation], events: [MarketEvent] = []) {
        self.id = UUID()
        self.ticker = ticker
        self.name = name
        self.eventName = eventName
        self.eventDate = eventDate
        self.ripples = ripples
        self.events = events
    }
}

// MARK: - RippleResult (computed, not stored)

struct RippleResult: Identifiable {
    let id = UUID()
    let catalystTicker: String
    let rippleTicker: String
    let rippleDescription: String
    let verdict: RippleVerdict
    let preEventChange: Double    // % change before event
    let postEventChange: Double   // % change after event
    let catalystPostChange: Double

    var verdictExplanation: String {
        switch verdict {
        case .confirmed:
            return "\(rippleTicker) rose \(String(format: "%.1f", postEventChange))% after the \(catalystTicker) event. Ripple effect validated."
        case .forming:
            return "\(rippleTicker) showing positive drift (+\(String(format: "%.1f", postEventChange))%) but not yet decisive. Watch for acceleration."
        case .failed:
            return "\(rippleTicker) failed to follow \(catalystTicker) despite the catalyst. Sector correlation broke down."
        case .watching:
            return "Catalyst still early. Pre-event movement (\(String(format: "%.1f", preEventChange))%) suggests anticipation. Monitor post-event response."
        }
    }
}

// MARK: - Default Catalysts

extension Catalyst {
    static let defaults: [Catalyst] = [
        Catalyst(
            ticker: "SPCX",
            name: "SpaceX",
            eventName: "IPO Filing + Roadshow",
            eventDate: Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 24))!,
            ripples: [
                RippleRelation(ticker: "RKLB", description: "Primary proxy — launch competitor"),
                RippleRelation(ticker: "ASTS", description: "Satellite connectivity play"),
                RippleRelation(ticker: "LUNR", description: "Lunar infrastructure"),
                RippleRelation(ticker: "HWM",  description: "Aerospace components"),
                RippleRelation(ticker: "RDW",  description: "Spacecraft components"),
            ],
            events: [
                MarketEvent(date: Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 24))!, label: "SPCX IPO Filing", color: "#f59e0b"),
                MarketEvent(date: Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 29))!, label: "SPCX Roadshow", color: "#f97316"),
            ]
        ),
        Catalyst(
            ticker: "NVDA",
            name: "NVIDIA",
            eventName: "Q1 Earnings Beat",
            eventDate: Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 14))!,
            ripples: [
                RippleRelation(ticker: "AMD",  description: "Chip sector peer"),
                RippleRelation(ticker: "AVGO", description: "AI networking"),
            ],
            events: [
                MarketEvent(date: Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 14))!, label: "NVDA Earnings", color: "#22c55e"),
            ]
        ),
    ]

    static let defaultWatchlist = ["SPCX","RKLB","TSLA","NVDA","ASTS","LUNR","HWM","RDW","AMD","AVGO"]
}
