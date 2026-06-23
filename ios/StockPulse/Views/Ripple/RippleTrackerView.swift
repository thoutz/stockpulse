import SwiftUI
import Charts

struct RippleTrackerView: View {
    @Environment(StockPulseViewModel.self) private var vm
    @State private var expandedTicker: String?

    var body: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.lg) {
                    AppHeaderView()

                    if vm.isRefreshing && !vm.usesLiveData && !vm.isCachedData {
                        HStack(spacing: DS.Space.sm) {
                            ProgressView().tint(DS.Color.blue)
                            Text(vm.usesServerAPI
                                 ? "Connecting to server…"
                                 : "Loading market data…")
                                .font(DS.Font.sans(13))
                                .foregroundStyle(DS.Color.textMuted)
                        }
                        .padding(.horizontal, DS.Space.lg)
                    }

                    TickerTapeView(items: vm.tickerTapeItems)

                    VStack(alignment: .leading, spacing: DS.Space.lg) {
                        KeyEventsCard(events: vm.selectedCatalyst.events)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DS.Space.md) {
                                ForEach(Array(vm.catalysts.enumerated()), id: \.element.id) { idx, cat in
                                    CatalystCard(
                                        catalyst: cat,
                                        postEventPct: vm.postEventPct(for: cat),
                                        isSelected: vm.selectedCatalystIndex == idx
                                    ) {
                                        vm.selectedCatalystIndex = idx
                                    }
                                }
                            }
                        }

                        NormalizedChartCard(
                            catalyst: vm.selectedCatalyst,
                            series: vm.chartSeries,
                            predictionHint: vm.predictionHint(for: vm.selectedCatalyst.ticker)
                        )

                        SectionLabel(text: "Ripple Verification")

                        if vm.currentRippleResults.isEmpty && !vm.isRefreshing {
                            Text(vm.usesLiveData
                                 ? "No ripple results for this catalyst."
                                 : "Pull down to load live data.")
                                .font(DS.Font.sans(13))
                                .foregroundStyle(DS.Color.textMuted)
                        }

                        ForEach(vm.currentRippleResults) { result in
                            RippleCard(
                                result: result,
                                sparklinePoints: vm.sparklinePoints(ticker: result.rippleTicker),
                                isExpanded: expandedTicker == result.rippleTicker
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    expandedTicker = expandedTicker == result.rippleTicker
                                        ? nil : result.rippleTicker
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DS.Space.lg)
                    .padding(.bottom, DS.Space.xxl)
                }
                .spScrollContentWidth()
            }
        .spVerticalScrollAxes()
        .scrollContentBackground(.hidden)
        .refreshable { await vm.refresh() }
        .spScreenBackground()
    }
}

struct AppHeaderView: View {
    @Environment(StockPulseViewModel.self) private var vm

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "diamond.fill")
                        .foregroundStyle(DS.Color.blue)
                        .font(.system(size: 14))
                    Text("STOCKPULSE")
                        .font(DS.Font.mono(17, weight: .bold))
                        .foregroundStyle(DS.Color.blue)
                        .tracking(1)
                }
                Text("Market Context · Catalyst Networks · Verification")
                    .font(DS.Font.mono(10))
                    .foregroundStyle(DS.Color.textMuted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(vm.usesLiveData ? DS.Color.green : DS.Color.textDim)
                        .frame(width: 6, height: 6)
                    Text(vm.dataStatusLabel)
                        .font(DS.Font.mono(9, weight: .bold))
                        .foregroundStyle(vm.usesLiveData ? DS.Color.green : DS.Color.textDim)
                }
                Text("DATA THROUGH")
                    .font(DS.Font.mono(9))
                    .foregroundStyle(DS.Color.textDim)
                    .tracking(0.5)
                Text(vm.dataThroughLabel)
                    .font(DS.Font.mono(13, weight: .bold))
                    .foregroundStyle(DS.Color.orange)
            }
        }
        .padding(.horizontal, DS.Space.lg)
        .padding(.top, DS.Space.lg)
        .padding(.bottom, DS.Space.sm)
        .background(DS.Color.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(DS.Color.border).frame(height: 1)
        }
    }
}

struct KeyEventsCard: View {
    let events: [MarketEvent]

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM/dd"
        f.timeZone = TimeZone(identifier: "America/New_York")
        return f
    }()

    var body: some View {
        SPCard {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                SectionLabel(text: "Key Events")
                FlowLayout(spacing: DS.Space.lg) {
                    ForEach(events) { event in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: event.color))
                                .frame(width: 8, height: 8)
                            Text(Self.dateFormatter.string(from: event.date))
                                .font(DS.Font.mono(12, weight: .bold))
                                .foregroundStyle(Color(hex: event.color))
                            Text(event.label)
                                .font(DS.Font.sans(12))
                                .foregroundStyle(DS.Color.textSecond)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(DS.Space.lg)
        }
    }
}

struct CatalystCard: View {
    let catalyst: Catalyst
    let postEventPct: Double?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(catalyst.ticker)
                        .font(DS.Font.mono(15, weight: .bold))
                        .foregroundStyle(DS.Color.textPrimary)
                    Spacer()
                    if let pct = postEventPct {
                        Text(String(format: "%+.1f%% post-event", pct))
                            .font(DS.Font.mono(12, weight: .bold))
                            .foregroundStyle(pct >= 0 ? DS.Color.green : DS.Color.red)
                    } else {
                        Text("—")
                            .font(DS.Font.mono(12))
                            .foregroundStyle(DS.Color.textDim)
                    }
                }
                Text(catalyst.eventName)
                    .font(DS.Font.sans(12))
                    .foregroundStyle(DS.Color.textSecond)
                Text("\(catalyst.ripples.count) tracked ripple stocks")
                    .font(DS.Font.mono(10))
                    .foregroundStyle(DS.Color.textDim)
            }
            .padding(DS.Space.md)
            .frame(width: 200)
            .background(isSelected ? DS.Color.blue.opacity(0.12) : DS.Color.surface2)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(isSelected ? DS.Color.blue : DS.Color.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct NormalizedChartCard: View {
    let catalyst: Catalyst
    let series: [(ticker: String, points: [(date: Date, pct: Double)])]
    var predictionHint: String? = nil

    var body: some View {
        SPCard {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                Text("CATALYST: \(catalyst.ticker) — \(catalyst.eventName.uppercased())")
                    .font(DS.Font.mono(10))
                    .foregroundStyle(DS.Color.textDim)
                    .tracking(0.5)

                if let hint = predictionHint {
                    HStack(alignment: .top, spacing: DS.Space.sm) {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundStyle(DS.Color.purple)
                        Text(hint)
                            .font(DS.Font.sans(11))
                            .foregroundStyle(DS.Color.textSecond)
                            .lineLimit(2)
                    }
                    .padding(DS.Space.sm)
                    .background(DS.Color.purple.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                }

                Chart {
                    RuleMark(y: .value("Zero", 0))
                        .foregroundStyle(DS.Color.border2.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                    ForEach(catalyst.events) { event in
                        RuleMark(x: .value("Ev", event.date))
                            .foregroundStyle(Color(hex: event.color).opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .annotation(position: .top, alignment: .leading) {
                                Text(event.label)
                                    .font(DS.Font.mono(8))
                                    .foregroundStyle(Color(hex: event.color))
                            }
                    }

                    ForEach(Array(series.enumerated()), id: \.offset) { idx, s in
                        let color = DS.Color.chartLines[min(idx, DS.Color.chartLines.count - 1)]
                        ForEach(Array(s.points.enumerated()), id: \.offset) { _, pt in
                            LineMark(
                                x: .value("Date", pt.date),
                                y: .value("Pct", pt.pct),
                                series: .value("Ticker", s.ticker)
                            )
                            .foregroundStyle(color)
                            .lineStyle(StrokeStyle(lineWidth: idx == 0 ? 2.5 : 1.8))
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { v in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(DS.Color.border)
                        AxisValueLabel {
                            if let d = v.as(Double.self) {
                                Text("\(d >= 0 ? "+" : "")\(Int(d))%")
                                    .font(DS.Font.mono(9))
                                    .foregroundStyle(DS.Color.textDim)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 5)) { _ in
                        AxisGridLine().foregroundStyle(DS.Color.border.opacity(0.3))
                        AxisValueLabel(format: .dateTime.month(.twoDigits).day(.twoDigits))
                            .font(DS.Font.mono(8))
                            .foregroundStyle(DS.Color.textDim)
                    }
                }
                .frame(height: 200)
                .chartBackground { _ in DS.Color.bg }
                .chartLineTrace(
                    series: series.enumerated().map { idx, item in
                        ChartTraceSeries(
                            id: item.ticker,
                            points: item.points.map { ($0.date, $0.pct) },
                            color: DS.Color.chartLines[min(idx, DS.Color.chartLines.count - 1)]
                        )
                    }
                )

                Text("All lines normalized to % change from first bar in range. Dashed lines = key events.")
                    .font(DS.Font.mono(9))
                    .foregroundStyle(DS.Color.textDim)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 6) {
                    ForEach(Array(series.enumerated()), id: \.offset) { idx, s in
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(DS.Color.chartLines[min(idx, DS.Color.chartLines.count - 1)])
                                .frame(width: 16, height: 2)
                            Text(s.ticker)
                                .font(DS.Font.mono(11, weight: .bold))
                                .foregroundStyle(DS.Color.textSecond)
                        }
                    }
                }
            }
            .padding(DS.Space.lg)
        }
    }
}

struct RippleCard: View {
    let result: RippleResult
    let sparklinePoints: [(date: Date, pct: Double)]
    let isExpanded: Bool
    let onTap: () -> Void

    var color: Color { DS.Color.verdict(result.verdict) }

    var body: some View {
        SPCard {
            VStack(alignment: .leading, spacing: 0) {
                Button(action: onTap) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(result.rippleTicker)
                                .font(DS.Font.mono(15, weight: .bold))
                                .foregroundStyle(DS.Color.textPrimary)
                            Text(result.rippleDescription)
                                .font(DS.Font.sans(12))
                                .foregroundStyle(DS.Color.textMuted)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 6) {
                            VerdictBadge(verdict: result.verdict)
                            SparklineView(
                                points: sparklinePoints,
                                positive: result.postEventPct >= 0,
                                height: 30,
                                width: 80,
                                showArea: true,
                                tracePhaseOffset: result.rippleTicker.hashValue
                            )
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(DS.Space.md)

                HStack(spacing: DS.Space.xl) {
                    VStack(alignment: .leading, spacing: 2) {
                        SectionLabel(text: "Pre-event")
                        Text(String(format: "%+.1f%%", result.preEventPct))
                            .font(DS.Font.mono(12, weight: .bold))
                            .foregroundStyle(result.preEventPct >= 0 ? DS.Color.green : DS.Color.red)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        SectionLabel(text: "Post-event")
                        Text(String(format: "%+.1f%%", result.postEventPct))
                            .font(DS.Font.mono(12, weight: .bold))
                            .foregroundStyle(result.postEventPct >= 0 ? DS.Color.green : DS.Color.red)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(DS.Color.textMuted)
                        .font(.caption)
                }
                .padding(.horizontal, DS.Space.md)
                .padding(.bottom, DS.Space.md)

                if isExpanded {
                    Divider().overlay(DS.Color.border)
                    VStack(alignment: .leading, spacing: DS.Space.sm) {
                        HStack(alignment: .top, spacing: DS.Space.sm) {
                            Image(systemName: result.verdict.icon)
                                .foregroundStyle(color)
                                .font(.system(size: 14))
                            Text(result.explanation)
                                .font(DS.Font.sans(13))
                                .foregroundStyle(DS.Color.textSecond)
                        }
                        .padding(DS.Space.md)
                        .background(color.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(color)
                                .frame(width: 3)
                        }
                    }
                    .padding(DS.Space.md)
                }
            }
        }
    }
}
