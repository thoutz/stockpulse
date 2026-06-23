import Foundation

enum DateFormatting {

    private static let absolute: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy · h:mm a"
        f.timeZone = .current
        return f
    }()

    /// e.g. "Jun 9, 2026 · 10:15 AM (2h ago)"
    static func aiStamp(_ date: Date) -> String {
        let absolute = absolute.string(from: date)
        let relative = relativePhrase(since: date)
        return "\(absolute) (\(relative))"
    }

    private static let dayKeyParser: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "America/New_York")
        return f
    }()

    private static let chipShort: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        f.timeZone = TimeZone(identifier: "America/New_York")
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        f.timeZone = .current
        return f
    }()

    /// Section header for expandable day groups, e.g. "Today · Jun 9"
    static func daySectionLabel(for dayKey: String) -> String {
        guard let date = dayKeyParser.date(from: dayKey) else { return dayKey }
        let cal = Calendar.current
        let short = {
            let f = DateFormatter()
            f.dateFormat = "MMM d"
            f.timeZone = TimeZone(identifier: "America/New_York")
            return f.string(from: date)
        }()
        if cal.isDateInToday(date) { return "Today · \(short)" }
        if cal.isDateInYesterday(date) { return "Yesterday · \(short)" }
        let weekday = chipShort.string(from: date)
        return "\(weekday) · \(short)"
    }

    /// Day picker chip: "Today", "Yesterday", or "Mon"
    static func dayChipLabel(for dayKey: String) -> String {
        guard let date = dayKeyParser.date(from: dayKey) else { return dayKey }
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        return chipShort.string(from: date)
    }

    /// Time only for digest rows, e.g. "10:15 AM"
    static func timeOnly(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    /// e.g. "2h ago"
    static func relativePhrase(since date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        if interval < 604800 { return "\(Int(interval / 86400))d ago" }
        return absolute.string(from: date)
    }
}
