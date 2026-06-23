import SwiftUI

struct PulseView: View {
    @Environment(StockPulseViewModel.self) private var vm
    @State private var expandedTicker: String?
    @State private var compareAllExpanded = false

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

                SectionLabel(text: "Chart Range")
                    .padding(.horizontal, DS.Space.lg)

                TrendRangePicker()
                    .padding(.horizontal, DS.Space.lg)

                if let refreshError = vm.refreshError {
                    Text(refreshError)
                        .font(DS.Font.mono(11))
                        .foregroundStyle(DS.Color.red)
                        .padding(.horizontal, DS.Space.lg)
                } else if let trendError = vm.trendRangeError, vm.trendRange != .oneDay {
                    Text(trendError)
                        .font(DS.Font.mono(11))
                        .foregroundStyle(DS.Color.red)
                        .padding(.horizontal, DS.Space.lg)
                }

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
                    .spContainedHorizontalScroll()

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

                    compareAllNetworksSection
                }
                .padding(.horizontal, DS.Space.lg)

                Spacer(minLength: DS.Space.xxl)
            }
            .spScrollContentWidth()
        }
        .spVerticalScrollAxes()
        .scrollContentBackground(.hidden)
        .refreshable { await vm.refresh() }
        .spScreenBackground()
        .onChange(of: vm.trendRange) { _, _ in
            Task { await vm.loadTrendRangeIfNeeded() }
        }
        .task {
            await vm.loadTrendRangeIfNeeded()
        }
    }

    private var compareAllNetworksSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    compareAllExpanded.toggle()
                }
            } label: {
                HStack {
                    SectionLabel(text: "Compare All Networks")
                    Spacer()
                    Image(systemName: compareAllExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(DS.Color.textMuted)
                }
            }
            .buttonStyle(.plain)

            if compareAllExpanded {
                ForEach(vm.catalysts) { catalyst in
                    CatalystTrendChartCard(catalyst: catalyst)
                }
            }
        }
    }
}
