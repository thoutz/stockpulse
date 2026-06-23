import SwiftUI
import Charts

struct MonitorScrubDisplay: Equatable {
    let price: Double
    let dateLabel: String
    let changePct: Double
}

private struct IndexedChartBar: Identifiable {
    let index: Int
    let date: Date
    let close: Double
    var id: Int { index }
}

struct MonitorPriceChartView: View {
    let symbol: String
    let bars: [HistoryPoint]
    let livePrice: Double
    @Binding var range: TrendChartRange
    @Binding var scrubDisplay: MonitorScrubDisplay?
    let loading: Bool
    let error: String?

    @State private var selectedDate: Date?
    @State private var selectedIndex: Int?

    private var sortedBars: [HistoryPoint] {
        bars.sorted { $0.date < $1.date }
    }

    private var indexedBars: [IndexedChartBar] {
        sortedBars.enumerated().map {
            IndexedChartBar(index: $0.offset, date: $0.element.date, close: $0.element.close)
        }
    }

    private var xAxisTickIndices: [Int] {
        let count = indexedBars.count
        guard count >= 2 else { return [0] }
        let tickCount: Int
        switch range {
        case .oneWeek: tickCount = min(5, count)
        case .thirtyDays: tickCount = 5
        case .oneYear: tickCount = 6
        default: tickCount = 5
        }
        if tickCount <= 1 { return [0] }
        return (0..<tickCount).map { i in
            Int((Double(i) / Double(tickCount - 1)) * Double(count - 1))
        }
    }

    private var periodChange: Double? {
        guard let first = sortedBars.first?.close,
              let last = sortedBars.last?.close else { return nil }
        return LiveDataBridge.changePct(from: first, to: last)
    }

    private var lineColor: Color {
        (periodChange ?? 0) >= 0 ? DS.Color.green : DS.Color.red
    }

    private var selectedBar: HistoryPoint? {
        guard let selectedDate else { return nil }
        return LiveDataBridge.nearestBar(to: selectedDate, in: sortedBars)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            rangePicker

            if let error, !error.isEmpty {
                Text(error)
                    .font(DS.Font.mono(10))
                    .foregroundStyle(DS.Color.red)
            } else if loading {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Spacer()
                }
                .frame(height: 180)
            } else if sortedBars.count < 2 {
                Text("Not enough chart data for \(symbol)")
                    .font(DS.Font.mono(11))
                    .foregroundStyle(DS.Color.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            } else {
                chart
                    .frame(height: 180)
            }
        }
        .spScrollContentWidth()
        .onChange(of: selectedDate) { _, date in
            updateScrubDisplay(for: date)
        }
        .onChange(of: selectedIndex) { _, index in
            updateScrubDisplay(forIndex: index)
        }
        .onChange(of: range) { _, _ in
            selectedDate = nil
            selectedIndex = nil
            scrubDisplay = nil
        }
        .onChange(of: bars.count) { _, _ in
            if selectedDate != nil {
                updateScrubDisplay(for: selectedDate)
            } else if selectedIndex != nil {
                updateScrubDisplay(forIndex: selectedIndex)
            }
        }
    }

    private var rangePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Space.sm) {
                ForEach(TrendChartRange.allCases, id: \.self) { item in
                    Button {
                        range = item
                    } label: {
                        Text(item.label)
                            .font(DS.Font.mono(11, weight: .bold))
                            .foregroundStyle(range == item ? DS.Color.blue : DS.Color.textDim)
                            .padding(.horizontal, DS.Space.md)
                            .padding(.vertical, DS.Space.sm)
                            .background(
                                range == item
                                    ? DS.Color.blue.opacity(0.12)
                                    : DS.Color.surface2
                            )
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.md)
                                    .stroke(
                                        range == item ? DS.Color.blue.opacity(0.35) : DS.Color.border,
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }

                if loading {
                    Text("Loading…")
                        .font(DS.Font.mono(10))
                        .foregroundStyle(DS.Color.textDim)
                }
            }
        }
        .spContainedHorizontalScroll()
    }

    private var chart: some View {
        Group {
            if range.isIntraday {
                intradayChart
            } else {
                dailyChart
            }
        }
    }

    private var intradayChart: some View {
        Chart {
            ForEach(Array(sortedBars.enumerated()), id: \.offset) { _, bar in
                AreaMark(
                    x: .value("Date", bar.date),
                    yStart: .value("Min", yDomainMin),
                    yEnd: .value("Price", bar.close)
                )
                .foregroundStyle(lineColor.opacity(0.12))
            }

            ForEach(Array(sortedBars.enumerated()), id: \.offset) { _, bar in
                LineMark(
                    x: .value("Date", bar.date),
                    y: .value("Price", bar.close)
                )
                .foregroundStyle(lineColor)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }

            if let bar = selectedBar {
                RuleMark(x: .value("Sel", bar.date))
                    .foregroundStyle(DS.Color.textMuted.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))

                PointMark(
                    x: .value("Sel", bar.date),
                    y: .value("Price", bar.close)
                )
                .foregroundStyle(lineColor)
                .symbolSize(64)
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartXScale(domain: intradayXDomain)
        .chartYScale(domain: yDomainMin...yDomainMax)
        .chartYAxis { priceYAxis }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(Self.intradayFormatter.string(from: date))
                            .font(DS.Font.mono(8))
                            .foregroundStyle(DS.Color.textDim)
                    }
                }
            }
        }
        .chartBackground { _ in DS.Color.bg }
    }

    private var dailyChart: some View {
        Chart {
            ForEach(indexedBars) { bar in
                AreaMark(
                    x: .value("X", bar.index),
                    yStart: .value("Min", yDomainMin),
                    yEnd: .value("Price", bar.close)
                )
                .foregroundStyle(lineColor.opacity(0.12))
            }

            ForEach(indexedBars) { bar in
                LineMark(
                    x: .value("X", bar.index),
                    y: .value("Price", bar.close)
                )
                .foregroundStyle(lineColor)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }

            if let bar = selectedIndexedBar {
                RuleMark(x: .value("Sel", bar.index))
                    .foregroundStyle(DS.Color.textMuted.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))

                PointMark(
                    x: .value("Sel", bar.index),
                    y: .value("Price", bar.close)
                )
                .foregroundStyle(lineColor)
                .symbolSize(64)
            }
        }
        .chartXSelection(value: $selectedIndex)
        .chartXScale(domain: dailyXDomain)
        .chartYScale(domain: yDomainMin...yDomainMax)
        .chartYAxis { priceYAxis }
        .chartXAxis {
            AxisMarks(values: xAxisTickIndices) { value in
                AxisValueLabel {
                    if let idx = value.as(Int.self), idx < indexedBars.count {
                        Text(formatAxisDate(indexedBars[idx].date))
                            .font(DS.Font.mono(8))
                            .foregroundStyle(DS.Color.textDim)
                    }
                }
            }
        }
        .chartBackground { _ in DS.Color.bg }
    }

    @AxisContentBuilder
    private var priceYAxis: some AxisContent {
        AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                .foregroundStyle(DS.Color.border)
            AxisValueLabel {
                if let price = value.as(Double.self) {
                    Text(formatPrice(price))
                        .font(DS.Font.mono(8))
                        .foregroundStyle(DS.Color.textDim)
                }
            }
        }
    }

    private var selectedIndexedBar: IndexedChartBar? {
        guard let selectedIndex, selectedIndex >= 0, selectedIndex < indexedBars.count else { return nil }
        return indexedBars[selectedIndex]
    }

    private var intradayXDomain: ClosedRange<Date> {
        guard let first = sortedBars.first?.date, let last = sortedBars.last?.date else {
            return Date()...Date()
        }
        return first...last
    }

    private var dailyXDomain: ClosedRange<Int> {
        let last = max(indexedBars.count - 1, 0)
        return 0...last
    }

    private func formatAxisDate(_ date: Date) -> String {
        if range == .oneYear {
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
        return date.formatted(.dateTime.month(.twoDigits).day(.twoDigits))
    }

    private var yDomainMin: Double {
        let closes = sortedBars.map(\.close)
        guard let lo = closes.min(), let hi = closes.max() else { return 0 }
        let pad = Swift.max((hi - lo) * 0.08, 0.01)
        return lo - pad
    }

    private var yDomainMax: Double {
        let closes = sortedBars.map(\.close)
        guard let lo = closes.min(), let hi = closes.max() else { return 1 }
        let pad = Swift.max((hi - lo) * 0.08, 0.01)
        return hi + pad
    }

    private func formatPrice(_ value: Double) -> String {
        if value >= 1000 { return String(format: "$%.0f", value) }
        if value >= 100 { return String(format: "$%.1f", value) }
        return String(format: "$%.2f", value)
    }

    private static let intradayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        return formatter
    }()

    private func formatScrubDate(_ date: Date) -> String {
        if range.isIntraday {
            return Self.intradayFormatter.string(from: date)
        }
        return date.formatted(.dateTime.month(.abbreviated).day().year())
    }

    private func updateScrubDisplay(for date: Date?) {
        guard let date,
              let bar = LiveDataBridge.nearestBar(to: date, in: sortedBars),
              let first = sortedBars.first?.close,
              let change = LiveDataBridge.changePct(from: first, to: bar.close)
        else {
            scrubDisplay = nil
            return
        }
        scrubDisplay = MonitorScrubDisplay(
            price: bar.close,
            dateLabel: formatScrubDate(bar.date),
            changePct: change
        )
    }

    private func updateScrubDisplay(forIndex index: Int?) {
        guard let index,
              index >= 0,
              index < indexedBars.count,
              let first = sortedBars.first?.close,
              let change = LiveDataBridge.changePct(from: first, to: indexedBars[index].close)
        else {
            scrubDisplay = nil
            return
        }
        let bar = indexedBars[index]
        scrubDisplay = MonitorScrubDisplay(
            price: bar.close,
            dateLabel: formatScrubDate(bar.date),
            changePct: change
        )
    }
}
