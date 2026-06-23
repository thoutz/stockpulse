import SwiftUI
import Charts

struct SparklineView: View {
    let points: [(date: Date, pct: Double)]
    var positive: Bool = true
    var height: CGFloat = 32
    var width: CGFloat = 80
    var showArea: Bool = true
    var eventDate: Date? = nil
    var tracePhaseOffset: Int = 0

    var lineColor: Color { positive ? DS.Color.green : DS.Color.red }

    var body: some View {
        Chart {
            if showArea {
                ForEach(Array(points.enumerated()), id: \.offset) { _, pt in
                    AreaMark(x: .value("D", pt.date), yStart: .value("Z", 0), yEnd: .value("P", pt.pct))
                        .foregroundStyle(lineColor.opacity(0.1))
                }
            }
            ForEach(Array(points.enumerated()), id: \.offset) { _, pt in
                LineMark(x: .value("D", pt.date), y: .value("P", pt.pct))
                    .foregroundStyle(lineColor)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
            }
            if let ev = eventDate {
                RuleMark(x: .value("Ev", ev))
                    .foregroundStyle(DS.Color.orange.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartLineTrace(
            series: [
                ChartTraceSeries(
                    id: "sparkline",
                    points: points.map { ($0.date, $0.pct) },
                    color: lineColor
                )
            ],
            style: .compact,
            phaseOffset: tracePhaseOffset
        )
        .frame(width: width, height: height)
    }
}
