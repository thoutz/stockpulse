import Foundation

enum TrendChartRange: String, CaseIterable, Hashable {
    case oneDay = "1D"
    case oneWeek = "1W"
    case thirtyDays = "30D"
    case oneYear = "1Y"

    var label: String { rawValue }

    var dayCount: Int? {
        switch self {
        case .oneDay: return nil
        case .oneWeek: return 7
        case .thirtyDays: return 30
        case .oneYear: return 365
        }
    }

    var needsRemoteFetch: Bool {
        self == .oneDay || self == .oneYear
    }

    var isIntraday: Bool {
        self == .oneDay
    }

    static var allTrendTickers: [String] {
        Array(
            Set(
                CatalystCatalog.catalysts.flatMap { catalyst in
                    [catalyst.ticker] + catalyst.ripples.map(\.ticker)
                }
            )
        ).sorted()
    }
}

enum TrendRangeHelper {

    private static let et = TimeZone(identifier: "America/New_York") ?? .current
    private static let rthOpen = 9 * 60 + 30
    private static let rthClose = 16 * 60

    static func sliceDaily(_ history: [HistoryPoint], days: Int) -> [HistoryPoint] {
        guard !history.isEmpty else { return [] }
        let sorted = history.sorted { $0.date < $1.date }

        if days <= 7 {
            return Array(sorted.suffix(max(days, 2)))
        }

        var cal = Calendar.current
        cal.timeZone = et
        let cutoff = cal.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let filtered = sorted.filter { $0.date >= cutoff }
        if filtered.count >= 2 { return filtered }
        return Array(sorted.suffix(min(days + 5, sorted.count)))
    }

    static func sliceMinuteSession(_ history: [HistoryPoint]) -> [HistoryPoint] {
        guard !history.isEmpty else { return [] }
        let sorted = history.sorted { $0.date < $1.date }
        guard let last = sorted.last else { return [] }

        let lastSession = sessionDate(for: last.date)
        let session = sorted.filter { sessionDate(for: $0.date) == lastSession }
        let rth = session.filter {
            let mins = minutesSinceMidnight(for: $0.date)
            return mins >= rthOpen && mins <= rthClose
        }
        if rth.count >= 2 { return rth }
        if session.count >= 2 { return session }

        let cutoff = last.date.addingTimeInterval(-6.5 * 3600)
        let recent = sorted.filter { $0.date >= cutoff }
        if recent.count >= 2 { return recent }
        return Array(sorted.suffix(min(120, sorted.count)))
    }

    static func align(
        tickers: [String],
        barsByTicker: [String: [HistoryPoint]]
    ) -> [String: [HistoryPoint]] {
        var sortedMap: [String: [HistoryPoint]] = [:]
        for ticker in tickers {
            sortedMap[ticker] = (barsByTicker[ticker] ?? []).sorted { $0.date < $1.date }
        }

        let lengths = tickers.compactMap { sortedMap[$0]?.count }.filter { $0 >= 2 }
        guard let n = lengths.min() else { return sortedMap }

        var aligned: [String: [HistoryPoint]] = [:]
        for ticker in tickers {
            aligned[ticker] = Array(sortedMap[ticker]?.suffix(n) ?? [])
        }
        return aligned
    }

    static func bars(
        ticker: String,
        range: TrendChartRange,
        liveHistories: [String: [HistoryPoint]],
        fetchedHistories: [String: [HistoryPoint]]
    ) -> [HistoryPoint] {
        switch range {
        case .oneDay:
            let minute = fetchedHistories[ticker] ?? []
            if !minute.isEmpty {
                let session = sliceMinuteSession(minute)
                if session.count >= 2 { return session }
            }
            if let daily = liveHistories[ticker] {
                return sliceDaily(daily, days: 2)
            }
            return []
        case .oneYear:
            if let extended = fetchedHistories[ticker], extended.count >= 2 {
                return sliceDaily(extended.sorted { $0.date < $1.date }, days: range.dayCount ?? 365)
            }
            if let daily = liveHistories[ticker] {
                return sliceDaily(daily, days: range.dayCount ?? 365)
            }
            return []
        case .oneWeek, .thirtyDays:
            guard let history = liveHistories[ticker], let days = range.dayCount else { return [] }
            return sliceDaily(history, days: days)
        }
    }

    private static func sessionDate(for date: Date) -> String {
        var cal = Calendar.current
        cal.timeZone = et
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }

    private static func minutesSinceMidnight(for date: Date) -> Int {
        var cal = Calendar.current
        cal.timeZone = et
        let comps = cal.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }
}

/// Monitor symbol price charts — always slice from a full daily history cache + optional minute bars.
enum MonitorChartHelper {

    static func bars(
        range: TrendChartRange,
        dailyHistory: [HistoryPoint]?,
        minuteHistory: [HistoryPoint]?
    ) -> [HistoryPoint] {
        switch range {
        case .oneDay:
            if let minute = minuteHistory, !minute.isEmpty {
                let session = TrendRangeHelper.sliceMinuteSession(minute)
                if session.count >= 2 { return session }
            }
            if let daily = dailyHistory {
                return TrendRangeHelper.sliceDaily(daily, days: 2)
            }
            return []
        case .oneWeek:
            guard let daily = dailyHistory else { return [] }
            return TrendRangeHelper.sliceDaily(daily, days: 7)
        case .thirtyDays:
            guard let daily = dailyHistory else { return [] }
            return TrendRangeHelper.sliceDaily(daily, days: 30)
        case .oneYear:
            guard let daily = dailyHistory else { return [] }
            return TrendRangeHelper.sliceDaily(daily, days: 365)
        }
    }
}
