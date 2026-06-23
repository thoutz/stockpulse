import SwiftUI

struct MarketPulseScrollScreen<Content: View>: View {
    let title: String
    var isLoading: Bool = false
    var isEmpty: Bool = false
    let onRefresh: (() async -> Void)?
    @ViewBuilder let content: () -> Content

    var body: some View {
        NavigationStack {
            ZStack {
                // Background — mpScreenBackground carries the accent glow
                Color.mpBackground
                    .ignoresSafeArea()

                if isEmpty && !isLoading {
                    emptyState
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 20) {
                            content()
                        }
                        .padding(.top, 4)
                        .padding(.bottom, 24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentMargins(.bottom, DesignSystem.tabBarClearance, for: .scrollContent)
                    .refreshable {
                        if let onRefresh { await onRefresh() }
                    }
                }

                if isLoading && isEmpty {
                    loadingOverlay
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .mpScreenBackground()
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.mpAccent.opacity(0.08))
                    .frame(width: 88, height: 88)
                Circle()
                    .fill(Color.mpAccent.opacity(0.05))
                    .frame(width: 120, height: 120)
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(Color.mpTextMuted)
            }

            VStack(spacing: 8) {
                Text("No Market Data")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.mpTextPrimary)
                Text("Pull to refresh or check your connection.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.mpTextSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 48)
    }

    // MARK: - Loading overlay

    private var loadingOverlay: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(Color.mpAccent)
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
