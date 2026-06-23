// Services/RippleEngine.swift
import Foundation

// MARK: - RippleEngine

struct RippleEngine {

    // MARK: - Core Verdict Logic

    /// Compute ripple verdict by comparing post-event performance
    /// of catalyst vs. ripple stock.
    static func verdict(
        catalystHistory: [HistoryPoint],
        rippleHistory: [HistoryPoint],
        eventDate: Date
    ) -> RippleVerdict {
        let catPost = postEventChange(history: catalystHistory, eventDate: eventDate)
        let ripPost = postEventChange(history: rippleHistory, eventDate: eventDate)
        let ripPre  = preEventChange(history: rippleHistory, eventDate: eventDate)

        switch (catPost, ripPost) {
        case let (c, r) where c > 3.0 && r > 2.0:
            return .confirmed
        case let (c, r) where c > 3.0 && r > 0.5:
            return .forming
        case let (c, r) where c > 3.0 && r <= 0:
            return .failed
        default:
            return .watching
        }
    }

    // MARK: - Full Ripple Analysis

    static func analyze(
        catalyst: Catalyst,
        histories: [String: [HistoryPoint]]
    ) -> [RippleResult] {
        guard let catHistory = histories[catalyst.ticker] else { return [] }

        return catalyst.ripples.compactMap { relation in
            guard let ripHistory = histories[relation.rippleTicker] else { return nil }

            let v = verdict(
                catalystHistory: catHistory,
                rippleHistory: ripHistory,
                eventDate: catalyst.eventDate
            )
            return RippleResult(
                catalystTicker: catalyst.ticker,
                rippleTicker: relation.rippleTicker,
                rippleDescription: relation.description,
                verdict: v,
                preEventChange: preEventChange(history: ripHistory, eventDate: catalyst.eventDate),
                postEventChange: postEventChange(history: ripHistory, eventDate: catalyst.eventDate),
                catalystPostChange: postEventChange(history: catHistory, eventDate: catalyst.eventDate)
            )
        }
    }

    // MARK: - Normalized History (for charts)

    /// Returns % change from baseline date for chart plotting.
    static func normalize(
        history: [HistoryPoint],
        from baseline: Date? = nil
    ) -> [(date: Date, pctChange: Double)] {
        let sorted = history.sorted { $0.date < $1.date }
        let basePoint: Double
        if let baseline {
            basePoint = sorted.first(where: { $0.date >= baseline })?.close ?? sorted.first?.close ?? 1
        } else {
            basePoint = sorted.first?.close ?? 1
        }
        guard basePoint > 0 else { return [] }
        return sorted.map { pt in
            (date: pt.date, pctChange: ((pt.close - basePoint) / basePoint) * 100)
        }
    }

    // MARK: - Correlation Coefficient (Pearson)

    /// Measures how tightly ripple follows catalyst over a time window.
    /// Returns value in [-1, 1]. >0.7 = strong correlation.
    static func pearsonCorrelation(
        catalystHistory: [HistoryPoint],
        rippleHistory: [HistoryPoint]
    ) -> Double {
        // Align by date
        let catMap = Dictionary(uniqueKeysWithValues: catalystHistory.map {
            (Calendar.current.startOfDay(for: $0.date), $0.close)
        })
        let ripMap = Dictionary(uniqueKeysWithValues: rippleHistory.map {
            (Calendar.current.startOfDay(for: $0.date), $0.close)
        })
        let commonDates = Set(catMap.keys).intersection(Set(ripMap.keys)).sorted()
        guard commonDates.count >= 5 else { return 0 }

        let catVals = commonDates.compactMap { catMap[$0] }
        let ripVals = commonDates.compactMap { ripMap[$0] }

        let n = Double(catVals.count)
        let catMean = catVals.reduce(0, +) / n
        let ripMean = ripVals.reduce(0, +) / n

        let numerator = zip(catVals, ripVals).reduce(0.0) { acc, pair in
            acc + (pair.0 - catMean) * (pair.1 - ripMean)
        }
        let catVariance = catVals.reduce(0.0) { $0 + pow($1 - catMean, 2) }
        let ripVariance = ripVals.reduce(0.0) { $0 + pow($1 - ripMean, 2) }
        let denominator = sqrt(catVariance * ripVariance)
        guard denominator > 0 else { return 0 }
        return numerator / denominator
    }

    // MARK: - Private helpers

    static func postEventChange(history: [HistoryPoint], eventDate: Date) -> Double {
        let sorted = history.sorted { $0.date < $1.date }
        guard let eventIdx = sorted.firstIndex(where: { Calendar.current.startOfDay(for: $0.date) >= Calendar.current.startOfDay(for: eventDate) }),
              let last = sorted.last else { return 0 }
        let eventPrice = sorted[eventIdx].close
        guard eventPrice > 0 else { return 0 }
        return ((last.close - eventPrice) / eventPrice) * 100
    }

    static func preEventChange(history: [HistoryPoint], eventDate: Date) -> Double {
        let sorted = history.sorted { $0.date < $1.date }
        guard let first = sorted.first,
              let eventIdx = sorted.firstIndex(where: { Calendar.current.startOfDay(for: $0.date) >= Calendar.current.startOfDay(for: eventDate) }),
              first.close > 0 else { return 0 }
        let eventPrice = sorted[eventIdx].close
        return ((eventPrice - first.close) / first.close) * 100
    }
}
