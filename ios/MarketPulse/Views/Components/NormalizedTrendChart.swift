import SwiftUI
import Charts

struct NormalizedTrendChart: View {
    let catalyst: Catalyst
    let histories: [String: [HistoryPoint]]
    var height: CGFloat = 220

    private var tickers: [String] {
        [catalyst.ticker] + catalyst.ripples.map(\.rippleTicker)
    }

    private var points: [NormalizedChartPoint] {
        ChartFormatting.normalizedPoints(catalyst: catalyst, histories: histories)
    }

    private var hasData: Bool {
        !points.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if hasData {
                Chart {
                    RuleMark(y: .value("Zero", 0))
                        .foregroundStyle(Color.mpBorder.opacity(0.8))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                    ForEach(catalyst.events) { event in
                        RuleMark(x: .value("Event", event.date))
                            .foregroundStyle(Color.mpAmber.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }

                    ForEach(points) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Change", point.pctChange),
                            series: .value("Ticker", point.ticker)
                        )
                        .foregroundStyle(ChartFormatting.color(for: point.ticker, in: tickers))
                        .lineStyle(StrokeStyle(
                            lineWidth: point.ticker == catalyst.ticker ? 2.5 : 1.5,
                            lineCap: .round,
                            lineJoin: .round
                        ))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartLegend(.hidden)
                .chartDateAxis()
                .chartPercentPointAxis()
                .chartYScale(domain: yDomain)
                .chartLineTrace(
                    series: tickers.map { ticker in
                        ChartTraceSeries(
                            id: ticker,
                            points: points
                                .filter { $0.ticker == ticker }
                                .map { ($0.date, $0.pctChange) },
                            color: ChartFormatting.color(for: ticker, in: tickers)
                        )
                    }
                )
                .frame(height: height)

                legend
            } else {
                Text("No price history for this catalyst network.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: height, alignment: .center)
            }
        }
    }

    private var yDomain: ClosedRange<Double> {
        let values = points.map(\.pctChange)
        guard let minV = values.min(), let maxV = values.max() else { return -5...5 }
        let pad = max(1, (maxV - minV) * 0.12)
        return (minV - pad)...(maxV + pad)
    }

    private var legend: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], alignment: .leading, spacing: 6) {
            ForEach(tickers, id: \.self) { ticker in
                HStack(spacing: 4) {
                    Circle()
                        .fill(ChartFormatting.color(for: ticker, in: tickers))
                        .frame(width: 6, height: 6)
                    Text(ticker)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
            }
        }
    }
}
