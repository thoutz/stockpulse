// Views/Watchlist/WatchlistView.swift
import SwiftUI
import Charts

struct WatchlistView: View {
    @Environment(RippleViewModel.self) private var vm
    @State private var selectedTicker: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(vm.allTickers, id: \.self) { ticker in
                    WatchRowView(ticker: ticker, selectedTicker: $selectedTicker)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, DesignSystem.tabBarClearance, for: .scrollContent)
            .navigationTitle("Watchlist")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .refreshable { await vm.loadAll() }
            .safeAreaInset(edge: .top, spacing: 0) {
                if let ticker = selectedTicker {
                    StockDetailBanner(ticker: ticker) { selectedTicker = nil }
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3), value: selectedTicker)
            .overlay {
                if vm.isLoading && vm.histories.isEmpty {
                    HStack(spacing: 10) {
                        ProgressView().tint(Color.mpAccent)
                        Text("Loading market data…")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.mpTextSecondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Color.mpSurface)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallCornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.smallCornerRadius)
                            .strokeBorder(Color.mpBorder, lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
                }
            }
        }
        .mpScreenBackground()
    }
}

// MARK: - Watch Row

struct WatchRowView: View {
    let ticker: String
    @Binding var selectedTicker: String?
    @Environment(RippleViewModel.self) private var vm

    var body: some View {
        let stats = vm.stats(for: ticker)
        let normalized = vm.normalizedHistory(for: ticker)
        let rippleBadges = vm.rippleBadges(for: ticker)
        let isSelected = selectedTicker == ticker

        Button {
            withAnimation { selectedTicker = isSelected ? nil : ticker }
        } label: {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(ticker)
                        .font(.mpMono(14, weight: .bold))
                        .foregroundStyle(Color.mpTextPrimary)
                    if !rippleBadges.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(rippleBadges, id: \.catalystTicker) { badge in
                                HStack(spacing: 2) {
                                    Image(systemName: badge.verdict.icon)
                                        .font(.system(size: 8))
                                    Text("↑\(badge.catalystTicker)")
                                        .font(.mpMono(9, weight: .semibold))
                                }
                                .foregroundStyle(badge.verdict.swiftColor)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(badge.verdict.backgroundColor)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                        }
                    }
                }
                .frame(minWidth: 80, maxWidth: DesignSystem.watchlistTickerWidth, alignment: .leading)

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "$%.2f", stats.price))
                        .font(.mpMono(13, weight: .semibold))
                        .foregroundStyle(Color.mpTextPrimary)
                    Text(String(format: "%+.2f%%", stats.change1D))
                        .font(.mpMono(11))
                        .mpDeltaColor(stats.change1D)
                }
                .frame(width: DesignSystem.watchlistPriceWidth, alignment: .trailing)

                SparklineView(
                    data: normalized,
                    color: stats.change30D >= 0 ? .mpPositive : .mpNegative,
                    showArea: true,
                    height: 34,
                    tracePhaseOffset: ticker.hashValue
                )
                .frame(width: DesignSystem.watchlistSparklineWidth)
                .padding(.horizontal, 10)

                Text(String(format: "%+.1f%%", stats.change30D))
                    .font(.mpMono(11))
                    .mpDeltaColor(stats.change30D)
                    .frame(width: DesignSystem.watchlistChange30DWidth, alignment: .trailing)
            }
            .mpRowPadding()
            .background(isSelected ? Color.mpSurfaceSelected : Color.clear)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.mpBorder)
                    .frame(height: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stock Detail Banner

struct StockDetailBanner: View {
    let ticker: String
    let onClose: () -> Void
    @Environment(RippleViewModel.self) private var vm

    var body: some View {
        let stats = vm.stats(for: ticker)
        let normalized = vm.normalizedHistory(for: ticker)
        let history = vm.histories[ticker] ?? []
        let sorted = history.sorted { $0.date < $1.date }

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ticker)
                        .font(.mpMono(22, weight: .bold))
                        .foregroundStyle(Color.mpTextPrimary)
                    Text(String(format: "$%.2f", stats.price))
                        .font(.mpMono(17))
                        .foregroundStyle(Color.mpTextSecondary)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.mpTextSecondary)
                        .font(.title2)
                }
            }

            HStack(spacing: 8) {
                StatCard(label: "1D", value: String(format: "%+.2f%%", stats.change1D),
                         valueColor: .mpDelta(stats.change1D))
                StatCard(label: "30D", value: String(format: "%+.1f%%", stats.change30D),
                         valueColor: .mpDelta(stats.change30D))
                StatCard(label: "High", value: String(format: "$%.2f", sorted.map(\.high).max() ?? 0))
                StatCard(label: "Low",  value: String(format: "$%.2f", sorted.map(\.low).min() ?? 0))
            }

            let chartColor = stats.change30D >= 0 ? Color.mpPositive : Color.mpNegative
            let chartPoints = normalized.map {
                NormalizedChartPoint(date: $0.date, ticker: ticker, pctChange: $0.pctChange)
            }
            Chart {
                ForEach(chartPoints) { pt in
                    AreaMark(
                        x: .value("Date", pt.date),
                        yStart: .value("Zero", 0),
                        yEnd: .value("Chg", pt.pctChange)
                    )
                    .foregroundStyle(chartColor.opacity(0.12))
                    LineMark(x: .value("Date", pt.date), y: .value("Chg", pt.pctChange))
                        .foregroundStyle(chartColor)
                        .interpolationMethod(.catmullRom)
                }
            }
            .chartPercentPointAxis()
            .chartDateAxis()
            .chartLineTrace(
                series: [
                    ChartTraceSeries(
                        id: ticker,
                        points: normalized.map { ($0.date, $0.pctChange) },
                        color: chartColor
                    )
                ],
                phaseOffset: ticker.hashValue
            )
            .frame(height: 120)

            let badges = vm.rippleBadges(for: ticker)
            if !badges.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(badges, id: \.catalystTicker) { badge in
                            VerdictBadge(verdict: badge.verdict)
                            Text("of \(badge.catalystTicker)")
                                .font(.mpMono(11))
                                .foregroundStyle(Color.mpTextSecondary)
                        }
                    }
                }
            }
        }
        .padding(DesignSystem.cardPadding + 4)
        .background(Color.mpSurfaceSelected)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.cardCornerRadius)
                .stroke(Color.mpBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardCornerRadius))
        .shadow(color: .black.opacity(0.3), radius: 8)
        .padding(.horizontal, DesignSystem.horizontalPadding)
    }
}

// MARK: - AI Analyst View

struct AIAnalystView: View {
    @Environment(RippleViewModel.self) private var vm
    @FocusState private var focused: Bool

    let quickQuestions = [
        "Did SPCX actually lift RKLB?",
        "Which ripple confirmed most strongly?",
        "Which ripple failed to materialize?",
        "Is it too late to buy ASTS?",
        "Compare NVDA and SPCX ripple strength",
    ]

    var body: some View {
        MarketPulseScrollScreen(
            title: "AI Analyst",
            isLoading: vm.isLoading,
            isEmpty: vm.histories.isEmpty,
            onRefresh: { await vm.loadAll() }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Text("The AI analyst has full access to 30 days of price history and knows which ripples confirmed vs. failed.")
                    .font(.mpBody(13))
                    .foregroundStyle(Color.mpTextSecondary)
                    .padding(.horizontal, DesignSystem.horizontalPadding)

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("AI ANALYST — RIPPLE-AWARE")
                            .mpSectionLabel()
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(vm.histories.isEmpty ? Color.mpAmber : Color.mpPositive)
                                .frame(width: 6, height: 6)
                            Text(vm.histories.isEmpty ? "Pending" : "Ready")
                                .font(.mpMono(11))
                                .foregroundStyle(vm.histories.isEmpty ? Color.mpAmber : Color.mpPositive)
                        }
                    }
                    .padding(12)
                    .background(Color.mpSurface)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color.mpBorder).frame(height: 1)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("QUICK QUESTIONS")
                            .mpSectionLabel()

                        FlowLayout(spacing: 8) {
                            ForEach(quickQuestions, id: \.self) { q in
                                Button(q) {
                                    vm.aiQuery = q
                                    Task { await vm.askAI() }
                                }
                                .font(.mpBody(11))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.mpSurfaceSelected)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.mpBorder, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .foregroundStyle(Color.mpTextSecondary)
                            }
                        }

                        @Bindable var bindVm = vm
                        HStack(alignment: .bottom, spacing: 10) {
                            TextField("Ask about ripples, trends, timing...", text: $bindVm.aiQuery, axis: .vertical)
                                .textFieldStyle(.plain)
                                .lineLimit(3...6)
                                .focused($focused)
                                .padding(12)
                                .background(Color.mpSurfaceSelected)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.mpBorder, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .foregroundStyle(Color.mpTextPrimary)

                            Button {
                                focused = false
                                Task { await vm.askAI() }
                            } label: {
                                Image(systemName: vm.aiLoading ? "arrow.triangle.2.circlepath" : "arrow.up.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(vm.aiQuery.isEmpty ? Color.mpTextMuted : Color.mpAccent)
                            }
                            .disabled(vm.aiQuery.isEmpty || vm.aiLoading)
                        }

                        if !vm.aiResponse.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("ANALYSIS")
                                    .mpSectionLabel()
                                Text(vm.aiResponse)
                                    .font(.mpBody(13))
                                    .foregroundStyle(Color.mpTextPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.mpSurfaceSelected)
                            .overlay(alignment: .leading) {
                                Rectangle().fill(Color.mpAccent).frame(width: 3)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        if vm.aiLoading {
                            HStack {
                                ProgressView()
                                Text("Analyzing…")
                                    .font(.footnote)
                                    .foregroundStyle(Color.mpTextSecondary)
                            }
                        }
                    }
                    .padding(16)
                }
                .background(Color.mpSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.mpBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, DesignSystem.horizontalPadding)
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Simple flow layout for chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.map { $0.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0 }.reduce(0) { $0 + $1 + spacing }
        return CGSize(width: proposal.width ?? 0, height: max(0, height - spacing))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = [[]]
        var currentWidth: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentWidth + size.width > maxWidth && !rows[rows.count - 1].isEmpty {
                rows.append([])
                currentWidth = 0
            }
            rows[rows.count - 1].append(subview)
            currentWidth += size.width + spacing
        }
        return rows
    }
}

#Preview {
    WatchlistView()
        .environment(RippleViewModel.preview)
        .preferredColorScheme(.dark)
}
