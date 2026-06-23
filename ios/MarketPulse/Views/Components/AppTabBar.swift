import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case ripple
    case watchlist
    case trends
    case ai

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ripple:    return "Ripple"
        case .watchlist: return "Watchlist"
        case .trends:    return "Trends"
        case .ai:        return "AI"
        }
    }

    var icon: String {
        switch self {
        case .ripple:    return "waveform.path"
        case .watchlist: return "list.bullet.rectangle"
        case .trends:    return "chart.line.uptrend.xyaxis"
        case .ai:        return "brain.head.profile"
        }
    }

    var selectedIcon: String {
        switch self {
        case .ripple:    return "waveform.path"
        case .watchlist: return "list.bullet.rectangle.fill"
        case .trends:    return "chart.line.uptrend.xyaxis"
        case .ai:        return "brain.head.profile"
        }
    }
}

struct AppTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selection = tab
                    }
                } label: {
                    tabItem(for: tab)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) {
                    Divider()
                        .overlay(Color.mpBorder.opacity(0.6))
                }
        }
    }

    @ViewBuilder
    private func tabItem(for tab: AppTab) -> some View {
        let isSelected = selection == tab
        VStack(spacing: 5) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.mpAccent.opacity(0.14))
                        .frame(width: 52, height: 34)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
                Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? Color.mpAccent : Color.mpTextSecondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 52, height: 34)

            Text(tab.title)
                .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Color.mpAccent : Color.mpTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}
