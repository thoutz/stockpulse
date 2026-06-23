import SwiftUI
import Charts

/// Normalized % change point for Swift Charts (values are percentage points, e.g. 5.0 = 5%).
struct NormalizedChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let ticker: String
    let pctChange: Double
}

enum ChartFormatting {
    /// Build multi-series chart points for catalyst + ripples.
    static func normalizedPoints(
        catalyst: Catalyst,
        histories: [String: [HistoryPoint]]
    ) -> [NormalizedChartPoint] {
        let tickers = [catalyst.ticker] + catalyst.ripples.map(\.rippleTicker)
        let baseline = tickers
            .compactMap { histories[$0]?.sorted { $0.date < $1.date }.first?.date }
            .min() ?? Date()

        return tickers.flatMap { ticker -> [NormalizedChartPoint] in
            let normalized = RippleEngine.normalize(
                history: histories[ticker] ?? [],
                from: baseline
            )
            return normalized.map {
                NormalizedChartPoint(date: $0.date, ticker: ticker, pctChange: $0.pctChange)
            }
        }
    }

    static func color(for ticker: String, in tickers: [String]) -> Color {
        let palette: [Color] = [.mpAmber, .mpPositive, .mpAccent, .purple, .orange, .teal]
        guard let idx = tickers.firstIndex(of: ticker) else { return .mpAccent }
        return palette[min(idx, palette.count - 1)]
    }
}

extension View {
    /// Y-axis for percentage-point values (not 0–1 fractions).
    func chartPercentPointAxis() -> some View {
        chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(String(format: "%.0f%%", v))
                    }
                }
            }
        }
    }

    func chartDateAxis() -> some View {
        chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.mpBorder.opacity(0.6))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
    }
}
