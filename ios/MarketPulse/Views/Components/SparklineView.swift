import SwiftUI
import Charts

struct SparklineView: View {
    let data: [(date: Date, pctChange: Double)]
    var color: Color = .mpAccent
    var showArea: Bool = false
    var eventDate: Date? = nil
    var height: CGFloat = 36
    var tracePhaseOffset: Int = 0

    private var points: [NormalizedChartPoint] {
        data.map { NormalizedChartPoint(date: $0.date, ticker: "S", pctChange: $0.pctChange) }
    }

    private var yDomain: ClosedRange<Double> {
        let values = data.map(\.pctChange)
        guard let minV = values.min(), let maxV = values.max() else { return -2...2 }
        let pad = max(0.5, (maxV - minV) * 0.15)
        return (minV - pad)...(maxV + pad)
    }

    var body: some View {
        Chart {
            if showArea, !points.isEmpty {
                ForEach(points) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        yStart: .value("Zero", yDomain.lowerBound),
                        yEnd: .value("Change", point.pctChange)
                    )
                    .foregroundStyle(color.opacity(0.12))
                }
            }

            ForEach(points) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Change", point.pctChange)
                )
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .interpolationMethod(.catmullRom)
            }

            if let eventDate {
                RuleMark(x: .value("Event", eventDate))
                    .foregroundStyle(Color.mpAmber.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartYScale(domain: yDomain)
        .chartLineTrace(
            series: [
                ChartTraceSeries(
                    id: "sparkline",
                    points: data.map { ($0.date, $0.pctChange) },
                    color: color
                )
            ],
            style: .compact,
            phaseOffset: tracePhaseOffset
        )
        .frame(height: height)
    }
}

// MARK: - Verdict Badge

struct VerdictBadge: View {
    let verdict: RippleVerdict

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: verdict.icon)
                .font(.system(size: 9, weight: .bold))
            Text(verdict.rawValue)
                .font(.mpMono(10, weight: .bold))
        }
        .foregroundStyle(verdict.swiftColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(verdict.backgroundColor)
        .clipShape(Capsule())
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let label: String
    let value: String
    var valueColor: Color = .mpTextPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.mpTextMuted)
                .textCase(.uppercase)
                .tracking(0.4)
            Text(value)
                .font(.mpMono(15, weight: .bold))
                .foregroundStyle(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.mpSurfaceSelected)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.smallCornerRadius)
                .strokeBorder(Color.mpBorder, lineWidth: 0.5)
        )
    }
}
