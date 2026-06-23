import SwiftUI

// MARK: - Ticker detail

struct MarketTickerDetailCard: View {
    @Environment(StockPulseViewModel.self) private var vm
    let ticker: String
    let accent: Color

    var body: some View {
        let perf = vm.industrySnapshot(for: ticker)?
            .constituents.first { $0.ticker == ticker }
        let industrySnap = vm.industrySnapshot(for: ticker)
        let industry = IndustryCatalog.industry(for: ticker)
        let sparkline = vm.marketSparkline(ticker: ticker)
        let links = IndustryCatalog.catalystLinks(for: ticker)
        let badges = vm.rippleBadges(for: ticker)

        SPCard {
            VStack(alignment: .leading, spacing: DS.Space.md) {
                detailHeader(
                    title: ticker,
                    subtitle: IndustryCatalog.displayName(for: ticker),
                    accent: accent,
                    onClose: { withAnimation { vm.clearMarketSelection() } }
                )

                if let perf, let industrySnap {
                    performanceRow(perf: perf, industrySnap: industrySnap)
                } else if let perf {
                    HStack(spacing: DS.Space.sm) {
                        Text("$\(String(format: "%.2f", perf.currentPrice))")
                            .font(DS.Font.mono(15, weight: .semibold))
                            .foregroundStyle(DS.Color.textPrimary)
                        pctPill("1D", perf.change1D)
                        pctPill("30D", perf.change30D)
                    }
                }

                if !sparkline.isEmpty {
                    SparklineView(
                        points: sparkline,
                        positive: (perf?.change30D ?? 0) >= 0,
                        height: 64,
                        width: UIScreen.main.bounds.width - 64,
                        showArea: true,
                        tracePhaseOffset: ticker.hashValue
                    )
                }

                if let industry, let industrySnap {
                    groupContextPanel(industry: industry, snap: industrySnap, ticker: ticker, accent: accent)
                }

                if !badges.isEmpty {
                    SectionLabel(text: "Ripple Signals")
                    FlowLayout(spacing: DS.Space.sm) {
                        ForEach(badges, id: \.catalystTicker) { badge in
                            HStack(spacing: 4) {
                                Image(systemName: badge.verdict.icon)
                                    .font(.system(size: 9))
                                Text("↑\(badge.catalystTicker)")
                                    .font(DS.Font.mono(10, weight: .bold))
                            }
                            .foregroundStyle(DS.Color.verdict(badge.verdict))
                            .padding(.horizontal, DS.Space.sm)
                            .padding(.vertical, 4)
                            .background(DS.Color.verdict(badge.verdict).opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !links.isEmpty {
                    SectionLabel(text: "Ripple Network")
                    ForEach(links, id: \.catalystTicker) { link in
                        Text("\(link.catalystTicker) — \(link.role)")
                            .font(DS.Font.mono(11))
                            .foregroundStyle(DS.Color.textSecond)
                    }
                }

                newsSection(title: "\(ticker) Headlines")

                if !vm.marketIndustryNews.isEmpty, let industry {
                    newsSection(
                        title: "\(industry.name) Pulse",
                        articles: vm.marketIndustryNews,
                        accent: accent.opacity(0.85)
                    )
                }

                watchlistButton(ticker: ticker)
            }
            .spScrollContentWidth()
            .padding(DS.Space.md)
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(accent)
                .frame(width: 4)
        }
        .padding(.horizontal, DS.Space.lg)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    @ViewBuilder
    private func performanceRow(perf: TickerPerformance, industrySnap: IndustrySnapshot) -> some View {
        let rank = (industrySnap.constituents.firstIndex { $0.ticker == ticker } ?? 0) + 1
        let total = industrySnap.constituents.count
        let vsGroup = perf.change30D - industrySnap.avgChange30D

        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack(spacing: DS.Space.sm) {
                Text("$\(String(format: "%.2f", perf.currentPrice))")
                    .font(DS.Font.mono(15, weight: .semibold))
                    .foregroundStyle(DS.Color.textPrimary)
                pctPill("1D", perf.change1D)
                pctPill("30D", perf.change30D)
            }
            HStack(spacing: DS.Space.sm) {
                statChip(
                    label: "Group rank",
                    value: "#\(rank) of \(total)",
                    color: accent
                )
                statChip(
                    label: "vs group 30D",
                    value: fmtPct(vsGroup),
                    color: vsGroup >= 0 ? DS.Color.green : DS.Color.red
                )
                statChip(
                    label: "Breadth",
                    value: "\(industrySnap.breadthUp)/\(industrySnap.breadthTotal) up",
                    color: industrySnap.breadthUp > industrySnap.breadthTotal / 2
                        ? DS.Color.green : DS.Color.orange
                )
            }
        }
    }

    @ViewBuilder
    private func groupContextPanel(
        industry: Industry,
        snap: IndustrySnapshot,
        ticker: String,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack {
                SectionLabel(text: industry.name)
                Spacer()
                Text(fmtPct(snap.avgChange1D) + " avg 1D")
                    .font(DS.Font.mono(10, weight: .bold))
                    .foregroundStyle(snap.avgChange1D >= 0 ? DS.Color.green : DS.Color.red)
            }
            Text(industry.description)
                .font(DS.Font.sans(11))
                .foregroundStyle(DS.Color.textMuted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Space.sm) {
                    ForEach(snap.constituents) { peer in
                        let isSelected = peer.ticker == ticker
                        Button {
                            withAnimation(.spring(response: 0.25)) {
                                vm.selectMarketTicker(peer.ticker)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(peer.ticker)
                                    .font(DS.Font.mono(11, weight: .bold))
                                Text(fmtPct(peer.change1D))
                                    .font(DS.Font.mono(9))
                            }
                            .foregroundStyle(isSelected ? accent : DS.Color.textSecond)
                            .padding(.horizontal, DS.Space.sm)
                            .padding(.vertical, 6)
                            .background(isSelected ? accent.opacity(0.15) : DS.Color.surface2)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.sm)
                                    .stroke(isSelected ? accent.opacity(0.5) : DS.Color.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(DS.Space.sm)
        .background(accent.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    @ViewBuilder
    private func newsSection(
        title: String,
        articles: [NewsArticle]? = nil,
        accent: Color = DS.Color.blue
    ) -> some View {
        let items = articles ?? vm.marketNews
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack {
                SectionLabel(text: title)
                Spacer()
                if vm.marketNewsLoading {
                    ProgressView().controlSize(.small).tint(accent)
                } else if let updated = vm.marketNewsUpdatedAt {
                    Text(DateFormatting.relativePhrase(since: updated))
                        .font(DS.Font.mono(9))
                        .foregroundStyle(DS.Color.textMuted)
                }
            }
            if items.isEmpty && !vm.marketNewsLoading {
                Text("No recent headlines. News refreshes every 15 minutes.")
                    .font(DS.Font.sans(11))
                    .foregroundStyle(DS.Color.textMuted)
            } else {
                ForEach(items.prefix(4)) { article in
                    MarketNewsRow(article: article, accent: accent)
                }
            }
        }
    }

    private func watchlistButton(ticker: String) -> some View {
        Button {
            vm.focusTicker(ticker, tab: .watchlist)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet.rectangle")
                Text("View in Watchlist")
            }
            .font(DS.Font.mono(12, weight: .bold))
            .foregroundStyle(DS.Color.blue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Space.sm)
            .background(DS.Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Index detail

struct MarketIndexDetailCard: View {
    @Environment(StockPulseViewModel.self) private var vm
    let indexId: String
    let accent: Color

    var body: some View {
        if let snap = vm.indexSnapshot(for: indexId) {
            indexContent(snap: snap)
        }
    }

    @ViewBuilder
    private func indexContent(snap: IndexSnapshot) -> some View {
        let spySnap = vm.indexSnapshots.first { $0.index.ticker == "SPY" }
        let qqqSnap = vm.indexSnapshots.first { $0.index.ticker == "QQQ" }
        let blurb = IndustryCatalog.indexBlurbs[indexId] ?? snap.index.subtitle

        SPCard {
            VStack(alignment: .leading, spacing: DS.Space.md) {
                detailHeader(
                    title: snap.index.name,
                    subtitle: IndustryCatalog.displayName(for: snap.index.ticker),
                    accent: accent,
                    onClose: { withAnimation { vm.clearMarketSelection() } }
                )

                Text(blurb)
                    .font(DS.Font.sans(12))
                    .foregroundStyle(DS.Color.textSecond)

                HStack(spacing: DS.Space.sm) {
                    Text("$\(String(format: "%.2f", snap.currentPrice))")
                        .font(DS.Font.mono(16, weight: .bold))
                        .foregroundStyle(DS.Color.textPrimary)
                    pctPill("1D", snap.change1D)
                    pctPill("30D", snap.change30D)
                }

                SparklineView(
                    points: snap.normalizedSeries,
                    positive: snap.change30D >= 0,
                    height: 64,
                    width: UIScreen.main.bounds.width - 64,
                    showArea: true,
                    tracePhaseOffset: snap.index.name.hashValue
                )

                if let spySnap, let qqqSnap {
                    HStack(spacing: DS.Space.sm) {
                        compareChip(label: "SPY 30D", value: spySnap.change30D, highlight: snap.index.ticker == "SPY")
                        compareChip(label: "QQQ 30D", value: qqqSnap.change30D, highlight: snap.index.ticker == "QQQ")
                        let spread = qqqSnap.change30D - spySnap.change30D
                        statChip(
                            label: "QQQ − SPY",
                            value: fmtPct(spread),
                            color: spread >= 0 ? DS.Color.green : DS.Color.red
                        )
                    }
                }

                newsSection(title: "\(snap.index.ticker) Headlines")

                Button {
                    vm.focusTicker(snap.index.ticker, tab: .watchlist)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet.rectangle")
                        Text("View \(snap.index.ticker) in Watchlist")
                    }
                    .font(DS.Font.mono(12, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Space.sm)
                    .background(accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                }
                .buttonStyle(.plain)
            }
            .padding(DS.Space.md)
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(accent)
                .frame(width: 4)
        }
        .padding(.horizontal, DS.Space.lg)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    @ViewBuilder
    private func newsSection(title: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack {
                SectionLabel(text: title)
                Spacer()
                if vm.marketNewsLoading {
                    ProgressView().controlSize(.small).tint(accent)
                } else if let updated = vm.marketNewsUpdatedAt {
                    Text(DateFormatting.relativePhrase(since: updated))
                        .font(DS.Font.mono(9))
                        .foregroundStyle(DS.Color.textMuted)
                }
            }
            if vm.marketNews.isEmpty && !vm.marketNewsLoading {
                Text("No recent headlines. News refreshes every 15 minutes.")
                    .font(DS.Font.sans(11))
                    .foregroundStyle(DS.Color.textMuted)
            } else {
                ForEach(vm.marketNews.prefix(5)) { article in
                    MarketNewsRow(article: article, accent: accent)
                }
            }
        }
    }

    private func compareChip(label: String, value: Double, highlight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(DS.Font.mono(9))
                .foregroundStyle(DS.Color.textMuted)
            Text(fmtPct(value))
                .font(DS.Font.mono(11, weight: .bold))
                .foregroundStyle(value >= 0 ? DS.Color.green : DS.Color.red)
        }
        .padding(.horizontal, DS.Space.sm)
        .padding(.vertical, 6)
        .background(highlight ? accent.opacity(0.15) : DS.Color.surface2)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
    }
}

// MARK: - Shared pieces

struct MarketNewsRow: View {
    let article: NewsArticle
    var accent: Color = DS.Color.blue

    var body: some View {
        Link(destination: article.url) {
            HStack(alignment: .top, spacing: DS.Space.sm) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(sentimentColor)
                    .frame(width: 3)
                    .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(article.headline)
                        .font(DS.Font.sans(12, weight: .medium))
                        .foregroundStyle(DS.Color.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)

                    HStack(spacing: DS.Space.sm) {
                        if let source = article.source, !source.isEmpty {
                            Text(source)
                                .font(DS.Font.mono(9, weight: .bold))
                                .foregroundStyle(accent)
                        }
                        Text(DateFormatting.relativePhrase(since: article.publishedAt))
                            .font(DS.Font.mono(9))
                            .foregroundStyle(DS.Color.textMuted)
                        if let label = article.sentimentLabel {
                            Text(label)
                                .font(DS.Font.mono(8, weight: .bold))
                                .foregroundStyle(sentimentColor)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(sentimentColor.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                        }
                    }
                }

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DS.Color.textMuted)
            }
            .padding(DS.Space.sm)
            .background(DS.Color.surface2)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        }
    }

    private var sentimentColor: Color {
        guard let score = article.sentimentScore else { return accent }
        if score > 0.15 { return DS.Color.green }
        if score < -0.15 { return DS.Color.red }
        return DS.Color.orange
    }
}

@ViewBuilder
private func detailHeader(
    title: String,
    subtitle: String,
    accent: Color,
    onClose: @escaping () -> Void
) -> some View {
    HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(DS.Font.mono(20, weight: .bold))
                .foregroundStyle(DS.Color.textPrimary)
            Text(subtitle)
                .font(DS.Font.sans(12))
                .foregroundStyle(accent)
        }
        Spacer()
        Button(action: onClose) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(DS.Color.textMuted)
        }
        .buttonStyle(.plain)
    }
}

private func pctPill(_ label: String, _ value: Double) -> some View {
    VStack(alignment: .leading, spacing: 2) {
        Text(label)
            .font(DS.Font.mono(9))
            .foregroundStyle(DS.Color.textMuted)
        Text(fmtPct(value))
            .font(DS.Font.mono(12, weight: .bold))
            .foregroundStyle(value >= 0 ? DS.Color.green : DS.Color.red)
    }
}

private func statChip(label: String, value: String, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 2) {
        Text(label)
            .font(DS.Font.mono(8))
            .foregroundStyle(DS.Color.textMuted)
        Text(value)
            .font(DS.Font.mono(10, weight: .bold))
            .foregroundStyle(color)
    }
    .padding(.horizontal, DS.Space.sm)
    .padding(.vertical, 5)
    .background(color.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
}

private func fmtPct(_ value: Double) -> String {
    String(format: "%+.1f%%", value)
}
