import Foundation

struct RippleEngine {

    static func verdict(
        catalystHistory: [HistoryPoint],
        rippleHistory: [HistoryPoint],
        eventDate: Date
    ) -> RippleVerdict {
        let catPost = postEventChange(history: catalystHistory, eventDate: eventDate)
        let ripPost = postEventChange(history: rippleHistory, eventDate: eventDate)

        if catPost > 3.0 && ripPost > 2.0 { return .confirmed }
        if catPost > 3.0 && ripPost > 0.5 { return .forming }
        if catPost > 3.0 && ripPost <= 0 { return .failed }
        return .watching
    }

    static func analyze(
        catalyst: Catalyst,
        histories: [String: [HistoryPoint]]
    ) -> [RippleResult] {
        guard let catHistory = histories[catalyst.ticker], !catHistory.isEmpty else { return [] }
        let eventDate = catalyst.eventDate

        return catalyst.ripples.compactMap { ripple in
            guard let ripHistory = histories[ripple.ticker] else { return nil }
            let v = verdict(catalystHistory: catHistory, rippleHistory: ripHistory, eventDate: eventDate)
            return RippleResult(
                catalystTicker: catalyst.ticker,
                rippleTicker: ripple.ticker,
                rippleDescription: ripple.description,
                verdict: v,
                preEventPct: preEventChange(history: ripHistory, eventDate: eventDate),
                postEventPct: postEventChange(history: ripHistory, eventDate: eventDate)
            )
        }
    }

    static func postEventChange(history: [HistoryPoint], eventDate: Date) -> Double {
        let sorted = history.sorted { $0.date < $1.date }
        guard let eventIdx = sorted.firstIndex(where: {
            Calendar.current.startOfDay(for: $0.date) >= Calendar.current.startOfDay(for: eventDate)
        }),
              let last = sorted.last else { return 0 }
        let eventPrice = sorted[eventIdx].close
        guard eventPrice > 0 else { return 0 }
        return ((last.close - eventPrice) / eventPrice) * 100
    }

    static func preEventChange(history: [HistoryPoint], eventDate: Date) -> Double {
        let sorted = history.sorted { $0.date < $1.date }
        guard let first = sorted.first,
              let eventIdx = sorted.firstIndex(where: {
                  Calendar.current.startOfDay(for: $0.date) >= Calendar.current.startOfDay(for: eventDate)
              }),
              first.close > 0 else { return 0 }
        let eventPrice = sorted[eventIdx].close
        return ((eventPrice - first.close) / first.close) * 100
    }
}
