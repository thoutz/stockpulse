import SwiftUI

struct TrendCompareView: View {
    @Environment(RippleViewModel.self) private var vm

    var body: some View {
        MarketPulseScrollScreen(
            title: "Trend Compare",
            isLoading: vm.isLoading,
            isEmpty: vm.histories.isEmpty,
            onRefresh: { await vm.loadAll() }
        ) {
            VStack(spacing: 16) {
                CatalystSelectorView()

                TrendChartCard(
                    catalyst: vm.selectedCatalyst,
                    histories: vm.histories
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("CORRELATION (30D)")
                        .mpSectionLabel()
                        .padding(.horizontal, DesignSystem.horizontalPadding)

                    ForEach(vm.selectedCatalyst.ripples) { relation in
                        correlationRow(for: relation)
                            .padding(.horizontal, DesignSystem.horizontalPadding)
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private func correlationRow(for relation: RippleRelation) -> some View {
        let catHistory = vm.histories[vm.selectedCatalyst.ticker] ?? []
        let ripHistory = vm.histories[relation.rippleTicker] ?? []
        let r = RippleEngine.pearsonCorrelation(
            catalystHistory: catHistory,
            rippleHistory: ripHistory
        )
        let strength = abs(r) >= 0.7 ? "Strong" : abs(r) >= 0.4 ? "Moderate" : "Weak"

        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(relation.rippleTicker)
                    .font(.mpMono(15, weight: .bold))
                    .foregroundStyle(Color.mpTextPrimary)
                Text(relation.description)
                    .font(.mpBody(12))
                    .foregroundStyle(Color.mpTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.2f", r))
                    .font(.mpMono(15, weight: .bold))
                    .mpDeltaColor(r)
                Text(strength)
                    .font(.mpMono(10))
                    .foregroundStyle(Color.mpTextMuted)
            }
        }
        .mpCard()
    }
}

#Preview {
    TrendCompareView()
        .environment(RippleViewModel.preview)
        .preferredColorScheme(.dark)
}
