import SwiftUI

/// Broad Market + Industries chart sections (Market tab → Trends tab).
struct MarketIndicesSection: View {
    @Environment(StockPulseViewModel.self) private var vm

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            SectionLabel(text: "Broad Market")
                .padding(.horizontal, DS.Space.lg)
            if vm.indexSnapshots.isEmpty {
                MarketSectionHint(text: "SPY and QQQ load with market data refresh.")
                    .padding(.horizontal, DS.Space.lg)
            } else {
                HStack(spacing: DS.Space.sm) {
                    ForEach(vm.indexSnapshots) { snap in
                        MarketIndexCard(snap: snap)
                    }
                }
                .spScrollContentWidth()
                .padding(.horizontal, DS.Space.lg)
            }
        }
        .spScrollContentWidth()
    }
}

struct MarketIndustriesSection: View {
    @Environment(StockPulseViewModel.self) private var vm

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            SectionLabel(text: "Industries")
                .padding(.horizontal, DS.Space.lg)
            if vm.industrySnapshots.isEmpty {
                MarketSectionHint(text: "Industry trends appear after market data loads.")
                    .padding(.horizontal, DS.Space.lg)
            } else {
                ForEach(vm.industrySnapshots) { snap in
                    MarketIndustryCard(snap: snap)
                        .padding(.horizontal, DS.Space.lg)
                }
            }
        }
        .spScrollContentWidth()
    }
}

struct MarketDetailSection: View {
    @Environment(StockPulseViewModel.self) private var vm

    var body: some View {
        switch vm.selectedMarketDetail {
        case .ticker(let ticker):
            let industryId = IndustryCatalog.industry(for: ticker)?.id ?? "semiconductors"
            MarketTickerDetailCard(
                ticker: ticker,
                accent: IndustryCatalog.accentColor(for: industryId)
            )
        case .index(let indexId):
            MarketIndexDetailCard(
                indexId: indexId,
                accent: IndustryCatalog.indexAccentColor(for: indexId)
            )
        case nil:
            EmptyView()
        }
    }
}

struct MarketSectionHint: View {
    let text: String

    var body: some View {
        Text(text)
            .font(DS.Font.sans(12))
            .foregroundStyle(DS.Color.textMuted)
    }
}

struct MarketIndexCard: View {
    @Environment(StockPulseViewModel.self) private var vm
    let snap: IndexSnapshot

    var body: some View {
        let isSelected = vm.selectedMarketDetail == .index(snap.id)
        let accent = IndustryCatalog.indexAccentColor(for: snap.id)

        Button {
            withAnimation(.spring(response: 0.25)) {
                if isSelected {
                    vm.clearMarketSelection()
                } else {
                    vm.selectMarketIndex(snap.id)
                }
            }
        } label: {
            SPCard {
                VStack(alignment: .leading, spacing: DS.Space.sm) {
                    Text(snap.index.name)
                        .font(DS.Font.sans(13, weight: .semibold))
                        .foregroundStyle(isSelected ? accent : DS.Color.textPrimary)
                    Text(snap.index.subtitle)
                        .font(DS.Font.mono(9))
                        .foregroundStyle(DS.Color.textMuted)
                    Text("$\(String(format: "%.2f", snap.currentPrice))")
                        .font(DS.Font.mono(16, weight: .bold))
                        .foregroundStyle(DS.Color.textPrimary)
                    HStack(spacing: DS.Space.md) {
                        MarketPctLabel(label: "1D", value: snap.change1D)
                        MarketPctLabel(label: "30D", value: snap.change30D)
                    }
                    SparklineView(
                        points: snap.normalizedSeries,
                        positive: snap.change30D >= 0,
                        height: 36,
                        width: (UIScreen.main.bounds.width - DS.Space.lg * 2 - DS.Space.sm) / 2 - DS.Space.md * 2,
                        showArea: true,
                        tracePhaseOffset: snap.index.name.hashValue
                    )
                }
                .padding(DS.Space.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(isSelected ? accent.opacity(0.6) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

struct MarketIndustryCard: View {
    @Environment(StockPulseViewModel.self) private var vm
    let snap: IndustrySnapshot

    var body: some View {
        SPCard {
            VStack(alignment: .leading, spacing: DS.Space.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snap.industry.name)
                            .font(DS.Font.sans(15, weight: .semibold))
                            .foregroundStyle(DS.Color.textPrimary)
                        Text(snap.industry.description)
                            .font(DS.Font.sans(11))
                            .foregroundStyle(DS.Color.textMuted)
                    }
                    Spacer()
                    MarketBreadthBadge(up: snap.breadthUp, total: snap.breadthTotal)
                }

                HStack(spacing: DS.Space.md) {
                    MarketPctLabel(label: "Avg 1D", value: snap.avgChange1D)
                    MarketPctLabel(label: "Avg 30D", value: snap.avgChange30D)
                }

                if snap.normalizedSeries.count >= 2 {
                    SparklineView(
                        points: snap.normalizedSeries,
                        positive: snap.avgChange30D >= 0,
                        height: 44,
                        width: UIScreen.main.bounds.width - 64,
                        showArea: true,
                        tracePhaseOffset: snap.industry.name.hashValue
                    )
                } else {
                    Text("Chart loads with market data refresh.")
                        .font(DS.Font.sans(11))
                        .foregroundStyle(DS.Color.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 44)
                }

                if let leader = snap.leader, let laggard = snap.laggard {
                    HStack(spacing: DS.Space.sm) {
                        MarketChip(text: "Leader \(leader.ticker) \(MarketFmt.pct(leader.change30D))", color: DS.Color.green)
                        MarketChip(text: "Laggard \(laggard.ticker) \(MarketFmt.pct(laggard.change30D))", color: DS.Color.red)
                    }
                    .spScrollContentWidth()
                }

                Button {
                    Task {
                        await vm.setMonitorFocus(sectorId: snap.industry.id)
                        vm.focusTicker(snap.industry.tickers.first ?? snap.leader?.ticker ?? "", tab: .watchlist)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "scope")
                        Text("Monitor heavily")
                    }
                    .font(DS.Font.mono(11, weight: .bold))
                    .foregroundStyle(IndustryCatalog.accentColor(for: snap.industry.id))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Space.sm)
                    .background(IndustryCatalog.accentColor(for: snap.industry.id).opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                }
                .buttonStyle(.plain)

                FlowLayout(spacing: DS.Space.sm) {
                    ForEach(snap.constituents) { perf in
                        Button {
                            withAnimation(.spring(response: 0.25)) {
                                if vm.selectedMarketDetail == .ticker(perf.ticker) {
                                    vm.clearMarketSelection()
                                } else {
                                    vm.selectMarketTicker(perf.ticker)
                                }
                            }
                        } label: {
                            let isSelected = vm.selectedMarketDetail == .ticker(perf.ticker)
                            let accent = IndustryCatalog.accentColor(for: snap.industry.id)
                            HStack(spacing: 4) {
                                Text(perf.ticker)
                                    .font(DS.Font.mono(11, weight: .bold))
                                Text(MarketFmt.pct(perf.change1D))
                                    .font(DS.Font.mono(10))
                            }
                            .foregroundStyle(isSelected ? accent : DS.Color.textSecond)
                            .padding(.horizontal, DS.Space.sm)
                            .padding(.vertical, 4)
                            .background(isSelected ? accent.opacity(0.15) : DS.Color.surface2)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.sm)
                                    .stroke(isSelected ? accent.opacity(0.45) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .spScrollContentWidth()
            .padding(DS.Space.md)
        }
    }
}

struct MarketPctLabel: View {
    let label: String
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(DS.Font.mono(9))
                .foregroundStyle(DS.Color.textMuted)
            Text(MarketFmt.pct(value))
                .font(DS.Font.mono(12, weight: .bold))
                .foregroundStyle(value >= 0 ? DS.Color.green : DS.Color.red)
        }
    }
}

struct MarketBreadthBadge: View {
    let up: Int
    let total: Int

    var body: some View {
        Text("\(up)/\(total) up")
            .font(DS.Font.mono(10, weight: .bold))
            .foregroundStyle(up > total / 2 ? DS.Color.green : DS.Color.orange)
            .padding(.horizontal, DS.Space.sm)
            .padding(.vertical, 4)
            .background((up > total / 2 ? DS.Color.green : DS.Color.orange).opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
    }
}

struct MarketChip: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(DS.Font.mono(9, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, DS.Space.sm)
            .padding(.vertical, 3)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
    }
}

enum MarketFmt {
    static func pct(_ value: Double) -> String {
        String(format: "%+.1f%%", value)
    }
}
