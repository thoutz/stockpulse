import SwiftUI

struct AssistantFeedView: View {
    @Environment(StockPulseViewModel.self) private var vm
    @State private var expandedAlertDays: Set<String> = []
    @State private var expandedReportDays: Set<String> = []
    @State private var collapsedReportSlots: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            controlsRow

            if !vm.usesServerAPI {
                Text("Connect STOCKPULSE_API_BASE_URL for server analytics.")
                    .font(DS.Font.sans(12))
                    .foregroundStyle(DS.Color.textMuted)
            } else {
                sectionTabs
                if let err = vm.assistantError {
                    Text(err)
                        .font(DS.Font.sans(12))
                        .foregroundStyle(DS.Color.red)
                }
                switch vm.aiAnalysisSection {
                case .alerts: alertsContent
                case .reports: reportsContent
                }
            }
        }
        .spScrollContentWidth()
        .padding(.horizontal, DS.Space.lg)
        .onAppear { seedExpandedSections() }
        .onChange(of: vm.digestRange) { _, _ in seedExpandedSections() }
    }

    // MARK: - Controls

    private var controlsRow: some View {
        HStack(spacing: DS.Space.sm) {
            Menu {
                ForEach(AIDigestRange.allCases, id: \.self) { range in
                    Button(range.label) {
                        vm.digestRange = range
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(vm.digestRange.label)
                        .font(DS.Font.mono(11, weight: .bold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(DS.Color.blue)
                .padding(.horizontal, DS.Space.md)
                .padding(.vertical, DS.Space.sm)
                .background(DS.Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            }

            Spacer()

            if vm.isAssistantSyncing {
                ProgressView().scaleEffect(0.7).tint(DS.Color.blue)
            }
        }
    }

    private var sectionTabs: some View {
        HStack(spacing: DS.Space.sm) {
            ForEach(AIAnalysisSection.allCases, id: \.self) { section in
                Button {
                    vm.aiAnalysisSection = section
                } label: {
                    Text(section.rawValue)
                        .font(DS.Font.mono(11, weight: .bold))
                        .foregroundStyle(
                            vm.aiAnalysisSection == section
                                ? DS.Color.textPrimary
                                : DS.Color.textMuted
                        )
                        .padding(.horizontal, DS.Space.md)
                        .padding(.vertical, DS.Space.sm)
                        .background(
                            vm.aiAnalysisSection == section
                                ? DS.Color.surface2
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md)
                                .stroke(
                                    vm.aiAnalysisSection == section
                                        ? DS.Color.border
                                        : Color.clear,
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: - Alerts (expandable by day)

    @ViewBuilder
    private var alertsContent: some View {
        let days = vm.alertDaysInRange
        if days.isEmpty && !vm.isAssistantSyncing {
            emptyState("No alerts in the last \(vm.digestRange.label).")
        } else {
            VStack(spacing: DS.Space.sm) {
                ForEach(days) { day in
                    alertDaySection(day)
                }
            }
        }
    }

    private func alertDaySection(_ day: APIDigestDay) -> some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedAlertDays.contains(day.date) },
                set: { expanded in
                    if expanded { expandedAlertDays.insert(day.date) }
                    else { expandedAlertDays.remove(day.date) }
                }
            )
        ) {
            VStack(spacing: DS.Space.sm) {
                ForEach(day.alerts) { alert in
                    alertRow(alert)
                }
            }
            .padding(.top, DS.Space.sm)
        } label: {
            HStack {
                Text(DateFormatting.daySectionLabel(for: day.date))
                    .font(DS.Font.sans(13, weight: .semibold))
                    .foregroundStyle(DS.Color.textPrimary)
                Spacer()
                Text("\(day.alerts.count)")
                    .font(DS.Font.mono(10, weight: .bold))
                    .foregroundStyle(DS.Color.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(DS.Color.orange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
        }
        .tint(DS.Color.orange)
    }

    private func alertRow(_ alert: APIAlert) -> some View {
        HStack(alignment: .top, spacing: DS.Space.sm) {
            Image(systemName: "bell.fill")
                .font(.caption)
                .foregroundStyle(alert.changePct >= 0 ? DS.Color.green : DS.Color.red)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("\(alert.symbol) \(alert.changePct >= 0 ? "+" : "")\(String(format: "%.1f", alert.changePct))%")
                        .font(DS.Font.mono(12, weight: .bold))
                        .foregroundStyle(DS.Color.textPrimary)
                    Spacer(minLength: DS.Space.sm)
                    Text(DateFormatting.timeOnly(alert.createdAt))
                        .font(DS.Font.mono(9))
                        .foregroundStyle(DS.Color.textMuted)
                }
                Text(alert.message)
                    .font(DS.Font.sans(12))
                    .foregroundStyle(DS.Color.textSecond)
            }
        }
        .padding(DS.Space.md)
        .background(DS.Color.orange.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    // MARK: - Reports (day → session slot)

    @ViewBuilder
    private var reportsContent: some View {
        let days = vm.reportDaysInRange
        if days.allSatisfy({ DigestBuilder.sessionGroups(for: $0).allSatisfy(\.reports.isEmpty) })
            && !vm.isAssistantSyncing {
            emptyState(reportEmptyMessage(for: days))
        } else {
            VStack(spacing: DS.Space.sm) {
                ForEach(days) { day in
                    reportDaySection(day)
                }
            }
        }
    }

    private func reportEmptyMessage(for days: [APIDigestDay]) -> String {
        if days.first?.date == DigestBuilder.todayKey() {
            return "No reports yet today. They generate at 10:00 AM, 1:00 PM, and 4:00 PM ET on trading days."
        }
        return "No reports in the last \(vm.digestRange.label)."
    }

    private func reportDaySection(_ day: APIDigestDay) -> some View {
        let slots = DigestBuilder.sessionGroups(for: day)
        let filledCount = slots.filter { !$0.reports.isEmpty }.count
        return DisclosureGroup(
            isExpanded: Binding(
                get: { expandedReportDays.contains(day.date) },
                set: { expanded in
                    if expanded { expandedReportDays.insert(day.date) }
                    else { expandedReportDays.remove(day.date) }
                }
            )
        ) {
            VStack(spacing: DS.Space.sm) {
                ForEach(slots) { group in
                    reportSlotSection(group)
                }
            }
            .padding(.top, DS.Space.sm)
        } label: {
            HStack {
                Text(DateFormatting.daySectionLabel(for: day.date))
                    .font(DS.Font.sans(13, weight: .semibold))
                    .foregroundStyle(DS.Color.textPrimary)
                Spacer()
                Text("\(filledCount)/3")
                    .font(DS.Font.mono(10, weight: .bold))
                    .foregroundStyle(DS.Color.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(DS.Color.blue.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
        }
        .tint(DS.Color.blue)
    }

    private func reportSlotSection(_ group: ReportSessionGroup) -> some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { !collapsedReportSlots.contains(group.id) },
                set: { expanded in
                    if expanded { collapsedReportSlots.remove(group.id) }
                    else { collapsedReportSlots.insert(group.id) }
                }
            )
        ) {
            VStack(spacing: DS.Space.sm) {
                if group.reports.isEmpty {
                    Text("Scheduled · not generated yet")
                        .font(DS.Font.sans(11))
                        .foregroundStyle(DS.Color.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, DS.Space.xs)
                } else {
                    ForEach(group.reports) { report in
                        reportRow(report)
                    }
                }
            }
            .padding(.top, DS.Space.xs)
        } label: {
            HStack(alignment: .top, spacing: DS.Space.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.slot.label)
                        .font(DS.Font.sans(12, weight: .semibold))
                        .foregroundStyle(DS.Color.textPrimary)
                    Text(group.slot.subtitle)
                        .font(DS.Font.mono(9))
                        .foregroundStyle(DS.Color.textMuted)
                }
                Spacer(minLength: DS.Space.sm)
                if let latest = group.reports.first {
                    Text(DateFormatting.timeOnly(latest.createdAt))
                        .font(DS.Font.mono(9))
                        .foregroundStyle(DS.Color.textMuted)
                }
            }
        }
        .tint(DS.Color.teal)
        .padding(DS.Space.sm)
        .background(DS.Color.surface2.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private func reportRow(_ report: APIReport) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            HStack(alignment: .top) {
                Text(report.title)
                    .font(DS.Font.sans(13, weight: .semibold))
                    .foregroundStyle(DS.Color.textPrimary)
                Spacer(minLength: DS.Space.sm)
                Text(DateFormatting.aiStamp(report.createdAt))
                    .font(DS.Font.mono(9))
                    .foregroundStyle(DS.Color.textMuted)
                    .multilineTextAlignment(.trailing)
            }
            StructuredReportBodyView(bodyText: report.body)
        }
        .padding(DS.Space.md)
        .background(DS.Color.blue.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private func emptyState(_ message: String) -> some View {
        Text(message)
            .font(DS.Font.sans(12))
            .foregroundStyle(DS.Color.textMuted)
            .padding(.vertical, DS.Space.sm)
    }

    private func seedExpandedSections() {
        if let firstAlertDay = vm.alertDaysInRange.first?.date {
            expandedAlertDays.insert(firstAlertDay)
        }
        if let firstReportDay = vm.reportDaysInRange.first?.date {
            expandedReportDays.insert(firstReportDay)
        }
    }
}
