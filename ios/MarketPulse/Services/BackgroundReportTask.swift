// Services/BackgroundReportTask.swift
import BackgroundTasks
import UserNotifications
import Foundation

// MARK: - Register in AppDelegate or @main App

/*
 In StockPulseApp.swift, add to your App init or .onAppear:

     BackgroundReportScheduler.shared.register()
     BackgroundReportScheduler.shared.schedule()

 In Info.plist add:
     <key>BGTaskSchedulerPermittedIdentifiers</key>
     <array>
         <string>com.yourapp.stockpulse.morningreport</string>
     </array>
*/

final class BackgroundReportScheduler {
    static let shared = BackgroundReportScheduler()
    private let taskIdentifier = "com.marketpulse.morningreport"

    private init() {}

    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            self.handleMorningReport(task: task as! BGAppRefreshTask)
        }
    }

    // Call this after app launch and after each report fires
    func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        // Next 6AM
        request.earliestBeginDate = nextSixAM()
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule background task: \(error)")
        }
    }

    private func handleMorningReport(task: BGAppRefreshTask) {
        // Reschedule for tomorrow before doing any work
        schedule()

        let reportTask = Task {
            do {
                let tickers = Catalyst.defaultWatchlist
                let histories = try await MarketDataService.shared.fetchHistories(tickers: tickers)
                let results = Catalyst.defaults.flatMap { catalyst in
                    RippleEngine.analyze(catalyst: catalyst, histories: histories)
                }
                await sendReportNotification(results: results)
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }

        task.expirationHandler = { reportTask.cancel() }
    }

    private func sendReportNotification(results: [RippleResult]) async {
        let confirmed = results.filter { $0.verdict == .confirmed }
        let failed    = results.filter { $0.verdict == .failed }
        let forming   = results.filter { $0.verdict == .forming }

        var lines: [String] = []
        if !confirmed.isEmpty {
            lines.append("✓ Confirmed: " + confirmed.map { "\($0.catalystTicker)→\($0.rippleTicker)" }.joined(separator: ", "))
        }
        if !forming.isEmpty {
            lines.append("◐ Forming: " + forming.map { "\($0.catalystTicker)→\($0.rippleTicker)" }.joined(separator: ", "))
        }
        if !failed.isEmpty {
            lines.append("✗ Failed: " + failed.map { "\($0.catalystTicker)→\($0.rippleTicker)" }.joined(separator: ", "))
        }

        guard !lines.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = "📊 StockPulse Morning Report"
        content.body = lines.joined(separator: "\n")
        content.sound = .default
        content.badge = NSNumber(value: confirmed.count)

        // Deliver immediately (we're already running at 6AM via background task)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Also: real-time ripple alert

    /// Call this from a timer or after data refresh to check for new confirmations
    func checkForNewRippleConfirmations(
        previous: [RippleResult],
        current: [RippleResult]
    ) async {
        let newConfirmations = current.filter { result in
            result.verdict == .confirmed &&
            previous.first(where: { $0.rippleTicker == result.rippleTicker })?.verdict != .confirmed
        }

        for result in newConfirmations {
            let content = UNMutableNotificationContent()
            content.title = "🚀 Ripple Confirmed"
            content.body = "\(result.catalystTicker) → \(result.rippleTicker): +\(String(format: "%.1f", result.postEventChange))% post-event. Ripple effect validated."
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: "ripple_\(result.rippleTicker)", content: content, trigger: trigger)
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    // MARK: - Helpers

    private func nextSixAM() -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 6
        components.minute = 0
        components.second = 0
        guard var next = Calendar.current.date(from: components) else { return Date() }
        if next <= Date() {
            next = Calendar.current.date(byAdding: .day, value: 1, to: next) ?? next
        }
        return next
    }
}
