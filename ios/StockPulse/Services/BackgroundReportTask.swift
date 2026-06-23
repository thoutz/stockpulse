import BackgroundTasks
import UserNotifications
import Foundation

final class BackgroundReportScheduler {
    static let shared = BackgroundReportScheduler()
    private let taskIdentifier = "com.marketpulse.app.morning-report"

    private init() {}

    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            self.handleMorningReport(task: task as! BGAppRefreshTask)
        }
    }

    func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = nextSixAM()
        try? BGTaskScheduler.shared.submit(request)
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func handleMorningReport(task: BGAppRefreshTask) {
        schedule()
        let work = Task {
            do {
                var results: [RippleResult] = []
                var histories: [String: [HistoryPoint]] = [:]
                if StockPulseAPIService.isConfigured {
                    let raw = try await StockPulseAPIService.shared.fetchDashboardRaw()
                    let dashboard = try StockPulseAPIService.shared.decodeDashboard(raw)
                    for (ticker, bars) in dashboard.histories {
                        histories[ticker] = StockPulseAPIService.historyPoints(from: bars)
                    }
                    for (ticker, bars) in dashboard.historiesExtended {
                        histories[ticker] = StockPulseAPIService.historyPoints(from: bars)
                    }
                    results = CatalystCatalog.catalysts.flatMap {
                        RippleEngine.analyze(catalyst: $0, histories: histories)
                    }
                } else {
                    let rawKey = Bundle.main.object(forInfoDictionaryKey: "MASSIVE_API_KEY") as? String ?? ""
                    guard !rawKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        task.setTaskCompleted(success: false)
                        return
                    }
                    let tickers = CatalystCatalog.allTickers
                    histories = try await MarketDataService.shared.fetchHistories(tickers: tickers, days: 90)
                    results = CatalystCatalog.catalysts.flatMap {
                        RippleEngine.analyze(catalyst: $0, histories: histories)
                    }
                }
                let serverAlerts = await fetchServerAlertLines()
                let marketLine = await fetchServerPulseBriefLine()
                await sendReportNotification(
                    results: results,
                    serverAlertLines: serverAlerts,
                    marketBriefLine: marketLine
                )
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
        task.expirationHandler = { work.cancel() }
    }

    private func fetchServerAlertLines() async -> [String] {
        guard StockPulseAPIService.isConfigured else { return [] }
        do {
            let alerts = try await StockPulseAPIService.shared.alerts(limit: 5)
            return alerts.map {
                "\($0.symbol) \($0.changePct >= 0 ? "+" : "")\(String(format: "%.1f", $0.changePct))% — \($0.message)"
            }
        } catch {
            return []
        }
    }

    /// Uses server pulse_open report — no Groq call.
    private func fetchServerPulseBriefLine() async -> String? {
        guard StockPulseAPIService.isConfigured else { return nil }
        do {
            let reports = try await StockPulseAPIService.shared.reports(limit: 10)
            let pulse = reports.first(where: { $0.reportType == "pulse_open" })
                ?? reports.first(where: { $0.reportType.hasPrefix("pulse") })
            guard let pulse else { return nil }
            let text = pulse.title.isEmpty ? pulse.body : "\(pulse.title)\n\(pulse.body)"
            let brief = MarketBrief(text: text, generatedAt: pulse.createdAt)
            MarketBriefStore.save(brief)
            let snippet = text
                .replacingOccurrences(of: "\n", with: " ")
                .prefix(120)
            return "Market: \(snippet)\(text.count > 120 ? "…" : "")"
        } catch {
            return nil
        }
    }

    private func sendReportNotification(
        results: [RippleResult],
        serverAlertLines: [String] = [],
        marketBriefLine: String? = nil
    ) async {
        let confirmed = results.filter { $0.verdict == .confirmed }
        let failed = results.filter { $0.verdict == .failed }
        let forming = results.filter { $0.verdict == .forming }

        var lines: [String] = serverAlertLines
        if let marketBriefLine { lines.append(marketBriefLine) }
        if !confirmed.isEmpty {
            lines.append("Confirmed: " + confirmed.map { "\($0.catalystTicker)→\($0.rippleTicker)" }.joined(separator: ", "))
        }
        if !forming.isEmpty {
            lines.append("Forming: " + forming.map { "\($0.catalystTicker)→\($0.rippleTicker)" }.joined(separator: ", "))
        }
        if !failed.isEmpty {
            lines.append("Failed: " + failed.map { "\($0.catalystTicker)→\($0.rippleTicker)" }.joined(separator: ", "))
        }

        let content = UNMutableNotificationContent()
        content.title = "StockPulse Morning Report"
        content.body = lines.isEmpty ? "No ripple updates today." : lines.joined(separator: "\n")
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    private func nextSixAM() -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 6
        components.minute = 0
        guard var next = Calendar.current.date(from: components) else { return Date().addingTimeInterval(3600) }
        if next <= Date() {
            next = Calendar.current.date(byAdding: .day, value: 1, to: next) ?? next
        }
        return next
    }
}
