import SwiftUI
import Charts

struct TrendRangePicker: View {
    @Environment(StockPulseViewModel.self) private var vm

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Space.sm) {
                ForEach(TrendChartRange.allCases, id: \.self) { range in
                    Button {
                        vm.trendRange = range
                    } label: {
                        Text(range.label)
                            .font(DS.Font.mono(11, weight: .bold))
                            .foregroundStyle(vm.trendRange == range ? DS.Color.blue : DS.Color.textDim)
                            .padding(.horizontal, DS.Space.md)
                            .padding(.vertical, DS.Space.sm)
                            .background(
                                vm.trendRange == range
                                    ? DS.Color.blue.opacity(0.12)
                                    : DS.Color.surface2
                            )
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.md)
                                    .stroke(
                                        vm.trendRange == range ? DS.Color.blue.opacity(0.35) : DS.Color.border,
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }

                if vm.trendRangeLoading {
                    Text("Loading…")
                        .font(DS.Font.mono(10))
                        .foregroundStyle(DS.Color.textDim)
                }
            }
        }
        .spContainedHorizontalScroll()
    }
}

struct CatalystTrendChartCard: View {
    @Environment(StockPulseViewModel.self) private var vm
    let catalyst: Catalyst

    var body: some View {
        SPCard {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                Text("\(catalyst.ticker) Ripple Network — \(catalyst.eventName)")
                    .font(DS.Font.mono(12, weight: .bold))
                    .foregroundStyle(DS.Color.orange)
                Text("All lines = % change from start of \(vm.trendRange.label) range.")
                    .font(DS.Font.mono(9))
                    .foregroundStyle(DS.Color.textDim)

                let tickers = [catalyst.ticker] + catalyst.ripples.map(\.ticker)
                let series = vm.chartSeries(for: catalyst)

                Chart {
                    RuleMark(y: .value("Zero", 0))
                        .foregroundStyle(DS.Color.border2.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                    ForEach(catalyst.events) { event in
                        RuleMark(x: .value("Ev", event.date))
                            .foregroundStyle(Color(hex: event.color).opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    }

                    ForEach(Array(series.enumerated()), id: \.offset) { idx, s in
                        let c = DS.Color.chartLines[min(idx, DS.Color.chartLines.count - 1)]
                        ForEach(Array(s.points.enumerated()), id: \.offset) { _, pt in
                            LineMark(x: .value("D", pt.date), y: .value("P", pt.pct), series: .value("T", s.ticker))
                                .foregroundStyle(c)
                                .lineStyle(StrokeStyle(lineWidth: idx == 0 ? 2.5 : 1.5))
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
                                    .font(DS.Font.mono(8))
                                    .foregroundStyle(DS.Color.textDim)
                            }
                        }
                    }
                }
                .chartXAxis {
                    if vm.trendRange.isIntraday {
                        AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                            AxisValueLabel(format: .dateTime.hour().minute())
                                .font(DS.Font.mono(8))
                                .foregroundStyle(DS.Color.textDim)
                        }
                    } else if vm.trendRange == .oneWeek {
                        AxisMarks(values: .stride(by: .day, count: 1)) { _ in
                            AxisValueLabel(format: .dateTime.month(.twoDigits).day(.twoDigits))
                                .font(DS.Font.mono(8))
                                .foregroundStyle(DS.Color.textDim)
                        }
                    } else {
                        AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                            AxisValueLabel(format: .dateTime.month(.twoDigits).day(.twoDigits))
                                .font(DS.Font.mono(8))
                                .foregroundStyle(DS.Color.textDim)
                        }
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

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Space.sm) {
                        ForEach(Array(tickers.enumerated()), id: \.offset) { idx, ticker in
                            if let chg = vm.periodChangePct(ticker: ticker) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Rectangle()
                                        .fill(DS.Color.chartLines[min(idx, DS.Color.chartLines.count - 1)])
                                        .frame(height: 3)
                                        .clipShape(Capsule())
                                    Text(ticker)
                                        .font(DS.Font.mono(11, weight: .bold))
                                        .foregroundStyle(DS.Color.textPrimary)
                                    Text(String(format: "%+.1f%%", chg))
                                        .font(DS.Font.mono(10))
                                        .foregroundStyle(chg >= 0 ? DS.Color.green : DS.Color.red)
                                }
                                .padding(DS.Space.sm)
                                .background(DS.Color.surface2)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                            }
                        }
                    }
                }
                .spContainedHorizontalScroll()
            }
            .spScrollContentWidth()
            .padding(DS.Space.lg)
        }
        .padding(.horizontal, DS.Space.lg)
    }
}
