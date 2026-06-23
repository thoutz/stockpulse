import Foundation

struct APIDigestDay: Decodable, Identifiable {
    var id: String { date }
    let date: String
    let reports: [APIReport]
    let alerts: [APIAlert]
    let suggestions: [APISuggestion]
}

struct APIDigest: Decodable {
    let days: [APIDigestDay]
}

enum DigestTimelineItem: Identifiable {
    case report(APIReport)
    case alert(APIAlert)
    case suggestion(APISuggestion)

    var id: String {
        switch self {
        case .report(let r): return "r-\(r.id)"
        case .alert(let a): return "a-\(a.id)"
        case .suggestion(let s): return "s-\(s.id)"
        }
    }

    var createdAt: Date {
        switch self {
        case .report(let r): return r.createdAt
        case .alert(let a): return a.createdAt
        case .suggestion(let s): return s.createdAt
        }
    }

    var kind: String {
        switch self {
        case .report: return "REPORT"
        case .alert: return "ALERT"
        case .suggestion: return "SUGGESTION"
        }
    }
}

enum AIDigestRange: Int, CaseIterable, Hashable {
    case oneDay = 1
    case threeDays = 3
    case sevenDays = 7

    var label: String {
        switch self {
        case .oneDay: return "1 day"
        case .threeDays: return "3 days"
        case .sevenDays: return "7 days"
        }
    }
}

enum AIAnalysisSection: String, CaseIterable, Hashable {
    case reports = "Reports"
    case alerts = "Alerts"
}

enum ReportSessionSlot: String, CaseIterable, Hashable, Identifiable {
    case open = "pulse_open"
    case midday = "pulse_midday"
    case close = "pulse_close"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .open: return "Market Open"
        case .midday: return "Midday"
        case .close: return "Market Close"
        }
    }

    var subtitle: String {
        switch self {
        case .open: return "10:00 AM ET · 30 min after open"
        case .midday: return "1:00 PM ET · midday check-in"
        case .close: return "4:00 PM ET · end of day"
        }
    }

    var sortOrder: Int {
        switch self {
        case .open: return 0
        case .midday: return 1
        case .close: return 2
        }
    }

    static func isPulseReport(_ report: APIReport) -> Bool {
        report.reportType.hasPrefix("pulse")
    }

    /// Hides legacy off-hours reports (e.g. 3:41 AM from the old 30-min cron).
    static func isDisplayable(_ report: APIReport) -> Bool {
        if report.reportType == "pulse_open"
            || report.reportType == "pulse_midday"
            || report.reportType == "pulse_close" {
            return true
        }
        if report.reportType == "pulse" {
            return isDuringMarketSession(report.createdAt)
        }
        return false
    }

    private static var eastern: TimeZone {
        TimeZone(identifier: "America/New_York") ?? .current
    }

    private static func isDuringMarketSession(_ date: Date) -> Bool {
        var calendar = Calendar.current
        calendar.timeZone = eastern
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let minutes = hour * 60 + minute
        return minutes >= (9 * 60 + 30) && minutes <= (16 * 60)
    }

    static func resolve(for report: APIReport) -> ReportSessionSlot? {
        if let slot = ReportSessionSlot(rawValue: report.reportType) {
            return slot
        }
        guard report.reportType == "pulse", isDuringMarketSession(report.createdAt) else {
            return nil
        }
        return inferLegacySlot(from: report.createdAt)
    }

    private static func inferLegacySlot(from date: Date) -> ReportSessionSlot {
        var calendar = Calendar.current
        calendar.timeZone = eastern
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let minutes = hour * 60 + minute
        if minutes < 11 * 60 + 30 { return .open }
        if minutes < 14 * 60 + 30 { return .midday }
        return .close
    }
}

struct ReportSessionGroup: Identifiable {
    var id: String { "\(dayKey):\(slot.rawValue)" }
    let dayKey: String
    let slot: ReportSessionSlot
    let reports: [APIReport]
}

enum DigestBuilder {

    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "America/New_York")
        return f
    }()

    static func todayKey() -> String {
        keyFormatter.string(from: Date())
    }

    static func lastNDayKeys(count: Int) -> [String] {
        let n = min(max(count, 1), 7)
        var calendar = Calendar.current
        calendar.timeZone = keyFormatter.timeZone
        let today = calendar.startOfDay(for: Date())
        return (0..<n).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return keyFormatter.string(from: day)
        }
    }

    static func last7DayKeys() -> [String] { lastNDayKeys(count: 7) }

    static func build(
        reports: [APIReport],
        alerts: [APIAlert],
        suggestions: [APISuggestion],
        days: Int = 7
    ) -> [APIDigestDay] {
        let keys = lastNDayKeys(count: days)
        var byDay: [String: (reports: [APIReport], alerts: [APIAlert], suggestions: [APISuggestion])] = [:]
        for key in keys {
            byDay[key] = ([], [], [])
        }
        for r in reports where byDay[key(for: r.createdAt)] != nil {
            let k = key(for: r.createdAt)
            byDay[k]?.reports.append(r)
        }
        for a in alerts where byDay[key(for: a.createdAt)] != nil {
            let k = key(for: a.createdAt)
            byDay[k]?.alerts.append(a)
        }
        for s in suggestions where byDay[key(for: s.createdAt)] != nil {
            let k = key(for: s.createdAt)
            byDay[k]?.suggestions.append(s)
        }
        return keys.map { k in
            let bucket = byDay[k] ?? ([], [], [])
            return APIDigestDay(
                date: k,
                reports: bucket.reports.sorted { $0.createdAt > $1.createdAt },
                alerts: bucket.alerts.sorted { $0.createdAt > $1.createdAt },
                suggestions: bucket.suggestions.sorted { $0.createdAt > $1.createdAt }
            )
        }
    }

    static func timeline(for day: APIDigestDay) -> [DigestTimelineItem] {
        var items: [DigestTimelineItem] = []
        items += day.reports.map { .report($0) }
        items += day.alerts.map { .alert($0) }
        items += day.suggestions.map { .suggestion($0) }
        return items.sorted { $0.createdAt > $1.createdAt }
    }

    static func sessionGroups(for day: APIDigestDay, showPendingForToday: Bool = true) -> [ReportSessionGroup] {
        var bySlot: [ReportSessionSlot: [APIReport]] = [:]
        for report in day.reports where ReportSessionSlot.isDisplayable(report) {
            guard let slot = ReportSessionSlot.resolve(for: report) else { continue }
            bySlot[slot, default: []].append(report)
        }
        let includeEmpty = showPendingForToday && day.date == todayKey()
        return ReportSessionSlot.allCases.compactMap { slot in
            let reports = (bySlot[slot] ?? []).sorted { $0.createdAt > $1.createdAt }
            guard !reports.isEmpty || includeEmpty else { return nil }
            return ReportSessionGroup(
                dayKey: day.date,
                slot: slot,
                reports: reports
            )
        }
        .sorted { $0.slot.sortOrder < $1.slot.sortOrder }
    }

    static func sessionGroups(for days: [APIDigestDay]) -> [ReportSessionGroup] {
        days
            .reversed()
            .flatMap { sessionGroups(for: $0) }
    }

    private static func key(for date: Date) -> String {
        keyFormatter.string(from: date)
    }
}
