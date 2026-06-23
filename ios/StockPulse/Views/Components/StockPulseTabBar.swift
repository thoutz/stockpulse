import SwiftUI

/// Custom tab bar so all six tabs stay visible. System `TabView` only shows four tabs
/// plus a "More" overflow on iPhone, which grouped Trade with AI.
struct StockPulseTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    selection = tab
                } label: {
                    tabItem(for: tab)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, DS.Space.xs)
        .padding(.top, DS.Space.sm)
        .frame(minHeight: 56)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(DS.Color.border.opacity(0.6))
                        .frame(height: 1)
                }
        }
    }

    @ViewBuilder
    private func tabItem(for tab: AppTab) -> some View {
        let isSelected = selection == tab
        VStack(spacing: 3) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(DS.Color.blue.opacity(0.14))
                        .frame(width: 44, height: 28)
                }
                Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 17, weight: isSelected ? .semibold : .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? DS.Color.blue : DS.Color.textMuted)
            }
            .frame(height: 28)

            Text(tab.title)
                .font(DS.Font.sans(9, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? DS.Color.blue : DS.Color.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, DS.Space.xs)
    }
}
