import SwiftUI

struct TickerTapeView: View {
    let items: [(ticker: String, price: Double, change1D: Double)]

    @State private var offset: CGFloat = 0
    @State private var isRunning = false

    private let itemSpacing: CGFloat = 24

    private func itemWidth(for item: (ticker: String, price: Double, change1D: Double)) -> CGFloat {
        let priceText = String(format: "$%.2f", item.price)
        let changeText = String(format: "%.2f%%", abs(item.change1D))
        let chars = item.ticker.count + priceText.count + changeText.count
        return max(160, CGFloat(chars) * 8.0 + 36)
    }

    private func segmentWidth(for widths: [CGFloat]) -> CGFloat {
        guard !widths.isEmpty else { return 0 }
        return widths.reduce(0, +) + itemSpacing * CGFloat(widths.count)
    }

    var body: some View {
        if items.isEmpty {
            Color.clear.frame(height: 28)
        } else {
            tapeContent
        }
    }

    private var tapeContent: some View {
        let widths = items.map { itemWidth(for: $0) }
        let loopWidth = segmentWidth(for: widths)
        let duplicated = items + items

        return HStack(spacing: itemSpacing) {
            ForEach(Array(duplicated.enumerated()), id: \.offset) { idx, item in
                tapeItem(item)
                    .frame(width: widths[idx % items.count], alignment: .leading)
            }
        }
        .offset(x: -offset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 28)
        .clipped()
        .background(DS.Color.bg)
        .onAppear { startScrolling(loopWidth: loopWidth) }
        .onDisappear { stopScrolling() }
        .onChange(of: items.count) { _, _ in
            stopScrolling()
            startScrolling(loopWidth: loopWidth)
        }
    }

    private func tapeItem(_ item: (ticker: String, price: Double, change1D: Double)) -> some View {
        HStack(spacing: 6) {
            Text(item.ticker)
                .font(DS.Font.mono(11, weight: .bold))
                .foregroundStyle(DS.Color.textPrimary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Text(String(format: "$%.2f", item.price))
                .font(DS.Font.mono(11))
                .foregroundStyle(DS.Color.textSecond)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            HStack(spacing: 2) {
                Image(systemName: item.change1D >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.system(size: 7))
                Text(String(format: "%.2f%%", abs(item.change1D)))
                    .font(DS.Font.mono(11))
            }
            .foregroundStyle(item.change1D >= 0 ? DS.Color.green : DS.Color.red)
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    private func startScrolling(loopWidth: CGFloat) {
        guard loopWidth > 0, !isRunning else { return }
        isRunning = true
        offset = 0
        let duration = max(12, Double(items.count) * 3)
        withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
            offset = loopWidth
        }
    }

    private func stopScrolling() {
        isRunning = false
        withAnimation(.none) {
            offset = 0
        }
    }
}
