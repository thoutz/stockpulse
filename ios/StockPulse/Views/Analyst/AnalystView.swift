import SwiftUI

struct AnalystView: View {
    @Environment(StockPulseViewModel.self) private var vm

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                header
                marketBriefSection
                marketResearchSection
                marketTrendsSection
                AssistantFeedView()
                Spacer(minLength: DS.Space.xxl)
            }
            .padding(.top, DS.Space.lg)
            .spScrollContentWidth()
        }
        .spVerticalScrollAxes()
        .scrollContentBackground(.hidden)
        .spScreenBackground()
        .refreshable {
            await vm.refreshMarketTab()
        }
        .task {
            await vm.generateMarketBrief()
            await vm.refreshMarketTab()
        }
    }

    private var marketTrendsSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.lg) {
            MarketIndicesSection()
            MarketIndustriesSection()
            MarketDetailSection()
        }
    }

    private var header: some View {
        HStack {
            Text("Analyst")
                .font(DS.Font.sans(20, weight: .bold))
                .foregroundStyle(DS.Color.textPrimary)
            Spacer()
            HStack(spacing: 4) {
                Circle()
                    .fill(vm.usesLiveData ? DS.Color.green : DS.Color.textDim)
                    .frame(width: 6, height: 6)
                Text(vm.usesLiveData ? vm.dataThroughLabel : "Waiting for data")
                    .font(DS.Font.mono(10))
                    .foregroundStyle(vm.usesLiveData ? DS.Color.green : DS.Color.textDim)
            }
        }
        .padding(.horizontal, DS.Space.lg)
    }

    private var marketBriefSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack {
                SectionLabel(text: "Market Brief")
                Spacer()
                if vm.marketLoading || vm.isRefreshing {
                    ProgressView().controlSize(.small).tint(DS.Color.blue)
                } else {
                    Button("Refresh") {
                        Task { await vm.refreshMarketTab() }
                    }
                    .font(DS.Font.mono(10, weight: .bold))
                    .foregroundStyle(DS.Color.blue)
                    .disabled(vm.marketLoading || vm.isRefreshing)
                }
            }
            .padding(.horizontal, DS.Space.lg)

            if let brief = vm.marketWhatsNewBrief {
                VStack(alignment: .leading, spacing: DS.Space.sm) {
                    MarketTabReportView(bodyText: brief.text, mode: .whatsNewOnly)
                    Text(DateFormatting.aiStamp(brief.generatedAt))
                        .font(DS.Font.mono(9))
                        .foregroundStyle(DS.Color.textMuted)
                }
                .spScrollContentWidth()
                .padding(DS.Space.lg)
                .background(DS.Color.purple.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(DS.Color.purple)
                        .frame(width: 3)
                }
                .padding(.horizontal, DS.Space.lg)
            } else if vm.marketLoading || vm.isRefreshing {
                HStack(spacing: DS.Space.sm) {
                    ProgressView().tint(DS.Color.blue)
                    Text(vm.isRefreshing
                         ? "Refreshing market data..."
                         : (vm.usesServerAPI ? "Server analyzing broader market..." : "Groq analyzing broader market..."))
                        .font(DS.Font.sans(13))
                        .foregroundStyle(DS.Color.textMuted)
                }
                .padding(.horizontal, DS.Space.lg)
            } else if !vm.usesLiveData {
                MarketSectionHint(text: "Load market data to generate the AI market brief.")
                    .padding(.horizontal, DS.Space.lg)
            }
        }
    }

    private var marketResearchSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            SectionLabel(text: "Research Watchlist")
                .padding(.horizontal, DS.Space.lg)

            if let research = vm.marketResearchBrief {
                VStack(alignment: .leading, spacing: DS.Space.sm) {
                    MarketTabReportView(bodyText: research.text, mode: .researchOnly)
                    Text(DateFormatting.aiStamp(research.generatedAt))
                        .font(DS.Font.mono(9))
                        .foregroundStyle(DS.Color.textMuted)
                }
                .spScrollContentWidth()
                .padding(DS.Space.lg)
                .background(DS.Color.orange.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(DS.Color.orange)
                        .frame(width: 3)
                }
                .padding(.horizontal, DS.Space.lg)
            } else if vm.marketLoading {
                ProgressView().tint(DS.Color.orange)
                    .padding(.horizontal, DS.Space.lg)
            } else {
                MarketSectionHint(text: "Research watchlist appears after the first pulse report of the day.")
                    .padding(.horizontal, DS.Space.lg)
            }
        }
    }
}
