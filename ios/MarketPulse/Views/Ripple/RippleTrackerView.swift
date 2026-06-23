import SwiftUI
import Charts

struct RippleTrackerView: View {
    @Environment(RippleViewModel.self) private var vm
    @State private var expandedRipple: String?

    private var hasData: Bool {
        !vm.histories.isEmpty
    }

    private let rippleGridColumns = [
        GridItem(.adaptive(minimum: 220), spacing: 10)
    ]

    var body: some View {
        MarketPulseScrollScreen(
            title: "Ripple Tracker",
            isLoading: vm.isLoading,
            isEmpty: !hasData,
            onRefresh: { await vm.loadAll() }
        ) {
            VStack(spacing: 16) {
                CatalystSelectorView()

                TrendChartCard(
                    catalyst: vm.selectedCatalyst,
                    histories: vm.histories
                )

                rippleVerificationSection
            }
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var rippleVerificationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RIPPLE VERIFICATION")
                .mpSectionLabel()
                .padding(.horizontal, DesignSystem.horizontalPadding)

            if vm.currentRippleResults.isEmpty {
                Text("No ripple results yet. Pull to refresh.")
                    .font(.footnote)
                    .foregroundStyle(Color.mpTextSecondary)
                    .padding(.horizontal, DesignSystem.horizontalPadding)
            } else {
                LazyVGrid(columns: rippleGridColumns, spacing: 10) {
                    ForEach(vm.currentRippleResults) { result in
                        RippleCardView(
                            result: result,
                            catalyst: vm.selectedCatalyst,
                            histories: vm.histories,
                            isExpanded: expandedRipple == result.rippleTicker
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                expandedRipple = expandedRipple == result.rippleTicker ? nil : result.rippleTicker
                            }
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.horizontalPadding)
            }
        }
    }
}

// MARK: - Catalyst Selector

struct CatalystSelectorView: View {
    @Environment(RippleViewModel.self) private var vm

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(vm.catalysts.enumerated()), id: \.element.id) { idx, catalyst in
                    catalystCard(catalyst: catalyst, index: idx)
                        .frame(width: 280)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, DesignSystem.horizontalPadding)
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .frame(height: 116)
    }

    @ViewBuilder
    private func catalystCard(catalyst: Catalyst, index idx: Int) -> some View {
        let isSelected = vm.selectedCatalystIndex == idx
        let history = vm.histories[catalyst.ticker] ?? []
        let postChange = RippleEngine.postEventChange(history: history, eventDate: catalyst.eventDate)
        let accentColor: Color = catalyst.ticker == "SPCX" ? .mpAmber : .mpAccent

        Button {
            withAnimation(.easeInOut(duration: 0.2)) { vm.selectedCatalystIndex = idx }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(catalyst.ticker)
                        .font(.mpMono(16, weight: .bold))
                        .foregroundStyle(Color.mpTextPrimary)
                    Spacer(minLength: 8)
                    Text(String(format: "%+.1f%%", postChange))
                        .font(.mpMono(13, weight: .semibold))
                        .mpDeltaColor(postChange)
                }
                Text(catalyst.eventName)
                    .font(.mpBody(13))
                    .foregroundStyle(Color.mpTextSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(catalyst.ripples.count) ripple stocks")
                    .font(.mpMono(10))
                    .foregroundStyle(Color.mpTextMuted)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.mpSurfaceSelected : Color.mpSurface)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.cardCornerRadius)
                    .stroke(isSelected ? accentColor : Color.mpBorder, lineWidth: isSelected ? 1.5 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardCornerRadius))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Trend Chart Card

struct TrendChartCard: View {
    let catalyst: Catalyst
    let histories: [String: [HistoryPoint]]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NORMALIZED PERFORMANCE")
                .mpSectionLabel()

            NormalizedTrendChart(catalyst: catalyst, histories: histories, height: 220)

            Text("All lines normalized to % change from baseline. Dashed lines = key events.")
                .font(.mpMono(11))
                .foregroundStyle(Color.mpTextMuted)
        }
        .mpCard(padding: 14)
        .padding(.horizontal, DesignSystem.horizontalPadding)
    }
}

// MARK: - Ripple Card

struct RippleCardView: View {
    let result: RippleResult
    let catalyst: Catalyst
    let histories: [String: [HistoryPoint]]
    let isExpanded: Bool
    let onTap: () -> Void

    private var verdictColor: Color { result.verdict.swiftColor }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.rippleTicker)
                            .font(.mpMono(14, weight: .bold))
                            .foregroundStyle(Color.mpTextPrimary)
                        Text(result.rippleDescription)
                            .font(.mpBody(11))
                            .foregroundStyle(Color.mpTextSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 6) {
                        VerdictBadge(verdict: result.verdict)
                        SparklineView(
                            data: RippleEngine.normalize(
                                history: histories[result.rippleTicker] ?? [],
                                from: histories[result.rippleTicker]?.sorted { $0.date < $1.date }.first?.date
                            ),
                            color: verdictColor,
                            showArea: true,
                            eventDate: catalyst.eventDate,
                            height: 32,
                            tracePhaseOffset: result.rippleTicker.hashValue
                        )
                        .frame(width: 80)
                    }
                }
                .padding(DesignSystem.cardPadding)
            }
            .buttonStyle(.plain)

            HStack(spacing: 12) {
                StatMini(
                    label: "Pre-event",
                    value: String(format: "%+.1f%%", result.preEventChange),
                    color: .mpDelta(result.preEventChange)
                )
                StatMini(
                    label: "Post-event",
                    value: String(format: "%+.1f%%", result.postEventChange),
                    color: .mpDelta(result.postEventChange)
                )
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.mpTextMuted)
            }
            .padding(.horizontal, DesignSystem.cardPadding)
            .padding(.bottom, DesignSystem.cardPadding)

            if isExpanded {
                Rectangle()
                    .fill(Color.mpBorder)
                    .frame(height: 1)
                    .padding(.horizontal, DesignSystem.cardPadding)
                expandedContent
            }
        }
        .background(isExpanded ? Color.mpSurfaceSelected : Color.mpSurface)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.cardCornerRadius)
                .stroke(isExpanded ? verdictColor : Color.mpBorder, lineWidth: isExpanded ? 1.5 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardCornerRadius))
    }

    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CATALYST vs RIPPLE")
                .font(.mpMono(9, weight: .semibold))
                .foregroundStyle(Color.mpTextMuted)
                .tracking(1)
                .textCase(.uppercase)

            dualComparisonChart
                .frame(height: 140)

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: result.verdict.icon)
                    .foregroundStyle(verdictColor)
                Text(result.verdictExplanation)
                    .font(.mpBody(11))
                    .foregroundStyle(Color.mpTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(verdictColor.opacity(0.09))
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(verdictColor)
                    .frame(width: 3)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(DesignSystem.cardPadding)
    }

    @ViewBuilder
    private var dualComparisonChart: some View {
        let catNorm = RippleEngine.normalize(
            history: histories[result.catalystTicker] ?? [],
            from: histories[result.catalystTicker]?.sorted { $0.date < $1.date }.first?.date
        )
        let ripNorm = RippleEngine.normalize(
            history: histories[result.rippleTicker] ?? [],
            from: histories[result.rippleTicker]?.sorted { $0.date < $1.date }.first?.date
        )
        let catPoints = catNorm.map { NormalizedChartPoint(date: $0.date, ticker: result.catalystTicker, pctChange: $0.pctChange) }
        let ripPoints = ripNorm.map { NormalizedChartPoint(date: $0.date, ticker: result.rippleTicker, pctChange: $0.pctChange) }
        let allPoints = catPoints + ripPoints
        let domain = [result.catalystTicker, result.rippleTicker]

        Chart {
            RuleMark(x: .value("Event", catalyst.eventDate))
                .foregroundStyle(Color.mpAmber.opacity(0.5))
                .lineStyle(StrokeStyle(dash: [2, 2]))

            ForEach(allPoints) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Chg", point.pctChange),
                    series: .value("Ticker", point.ticker)
                )
                .foregroundStyle(by: .value("Ticker", point.ticker))
                .interpolationMethod(.catmullRom)
            }
        }
        .chartForegroundStyleScale(
            domain: domain,
            range: [.mpAmber, verdictColor]
        )
        .chartLegend(position: .bottom, alignment: .leading, spacing: 8)
        .chartPercentPointAxis()
        .chartDateAxis()
        .chartLineTrace(
            series: domain.map { ticker in
                ChartTraceSeries(
                    id: ticker,
                    points: allPoints
                        .filter { $0.ticker == ticker }
                        .map { ($0.date, $0.pctChange) },
                    color: ticker == result.catalystTicker ? .mpAmber : verdictColor
                )
            }
        )
    }
}

// MARK: - Stat Mini

struct StatMini: View {
    let label: String
    let value: String
    var color: Color = .mpTextPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.mpMono(9))
                .foregroundStyle(Color.mpTextMuted)
                .textCase(.uppercase)
            Text(value)
                .font(.mpMono(12, weight: .bold))
                .foregroundStyle(color)
        }
    }
}

#Preview {
    RippleTrackerView()
        .environment(RippleViewModel.preview)
        .preferredColorScheme(.dark)
}
