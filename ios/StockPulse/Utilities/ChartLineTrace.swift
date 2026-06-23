import SwiftUI
import Charts

struct ChartTraceSeries: Identifiable {
    let id: String
    let points: [(date: Date, value: Double)]
    let color: Color

    var hasTraceablePath: Bool { points.count >= 2 }
}

enum ChartLineTraceStyle {
    case standard
    case compact

    var perSeriesDuration: TimeInterval {
        switch self {
        case .standard: 2.0
        case .compact: 1.2
        }
    }

    var handoffDuration: TimeInterval {
        switch self {
        case .standard: 0.3
        case .compact: 0.15
        }
    }

    var headRadius: CGFloat {
        switch self {
        case .standard: 3
        case .compact: 2
        }
    }

    var glowOpacity: Double {
        switch self {
        case .standard: 0.58
        case .compact: 0.38
        }
    }

    var tailSegmentCount: Int {
        switch self {
        case .standard: 12
        case .compact: 8
        }
    }

    var maxTailRadius: CGFloat {
        switch self {
        case .standard: 3.0
        case .compact: 2.2
        }
    }

    var minTailRadius: CGFloat {
        switch self {
        case .standard: 0.6
        case .compact: 0.45
        }
    }

    var maxTailOpacity: Double {
        switch self {
        case .standard: 0.52
        case .compact: 0.38
        }
    }

    var tailGlowOpacity: Double {
        switch self {
        case .standard: 0.28
        case .compact: 0.2
        }
    }

    var tailSpan: Double {
        switch self {
        case .standard: 0.28
        case .compact: 0.22
        }
    }

    var headGlowRadii: [CGFloat] {
        switch self {
        case .standard: [5.8, 4.2, 2.8]
        case .compact: [4.0, 2.8, 1.9]
        }
    }

    var headGlowOpacities: [Double] {
        switch self {
        case .standard: [0.22, 0.38, 0.55]
        case .compact: [0.16, 0.28, 0.42]
        }
    }
}

enum ChartPathSampler {
    static func sample(at progress: Double, along points: [CGPoint]) -> CGPoint? {
        guard !points.isEmpty else { return nil }
        guard points.count >= 2 else { return points[0] }

        let clamped = min(max(progress, 0), 1)
        var totalLength: CGFloat = 0
        var segmentLengths: [CGFloat] = []

        for index in 1..<points.count {
            let length = hypot(
                points[index].x - points[index - 1].x,
                points[index].y - points[index - 1].y
            )
            segmentLengths.append(length)
            totalLength += length
        }

        guard totalLength > 0 else { return points.last }

        let target = CGFloat(clamped) * totalLength
        var accumulated: CGFloat = 0

        for index in 0..<segmentLengths.count {
            let segmentLength = segmentLengths[index]
            if accumulated + segmentLength >= target {
                let fraction = (target - accumulated) / segmentLength
                let start = points[index]
                let end = points[index + 1]
                return CGPoint(
                    x: start.x + (end.x - start.x) * fraction,
                    y: start.y + (end.y - start.y) * fraction
                )
            }
            accumulated += segmentLength
        }

        return points.last
    }
}

private struct ChartLineTraceModifier: ViewModifier {
    let series: [ChartTraceSeries]
    let style: ChartLineTraceStyle
    let phaseOffset: TimeInterval

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    private var traceableSeries: [ChartTraceSeries] {
        series.filter(\.hasTraceablePath)
    }

    func body(content: Content) -> some View {
        content
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    if shouldAnimate, let plotFrame = proxy.plotFrame {
                        let plotRect = geometry[plotFrame]

                        TimelineView(.animation) { timeline in
                            if let frame = animationFrame(
                                at: timeline.date,
                                proxy: proxy
                            ) {
                                ChartLineTraceCanvas(
                                    head: frame.head,
                                    tail: frame.tail,
                                    color: frame.color,
                                    style: style,
                                    plotRect: plotRect
                                )
                            }
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                }
            }
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false }
    }

    private var shouldAnimate: Bool {
        isVisible && !reduceMotion && !traceableSeries.isEmpty
    }

    private struct AnimationFrame {
        let head: CGPoint
        let tail: [CGPoint]
        let color: Color
    }

    private func animationFrame(
        at date: Date,
        proxy: ChartProxy
    ) -> AnimationFrame? {
        let items = traceableSeries
        guard !items.isEmpty else { return nil }

        let slotDuration = style.perSeriesDuration + style.handoffDuration
        let cycleDuration = slotDuration * Double(items.count)
        let elapsed = date.timeIntervalSinceReferenceDate + phaseOffset
        let cyclePosition = elapsed.truncatingRemainder(dividingBy: cycleDuration)
        let seriesIndex = min(Int(cyclePosition / slotDuration), items.count - 1)
        let slotPosition = cyclePosition - Double(seriesIndex) * slotDuration

        guard slotPosition <= style.perSeriesDuration else { return nil }

        let progress = slotPosition / style.perSeriesDuration
        let activeSeries = items[seriesIndex]
        let pathPoints = plotPoints(for: activeSeries, proxy: proxy)

        guard pathPoints.count >= 2,
              let head = ChartPathSampler.sample(at: progress, along: pathPoints)
        else { return nil }

        let tail = (1...style.tailSegmentCount).compactMap { index -> CGPoint? in
            let fraction = Double(index) / Double(style.tailSegmentCount + 1)
            let trailProgress = max(0, progress - fraction * style.tailSpan)
            return ChartPathSampler.sample(at: trailProgress, along: pathPoints)
        }

        return AnimationFrame(head: head, tail: tail, color: activeSeries.color)
    }

    private func plotPoints(for series: ChartTraceSeries, proxy: ChartProxy) -> [CGPoint] {
        series.points.compactMap { point in
            guard let x = proxy.position(forX: point.date),
                  let y = proxy.position(forY: point.value)
            else { return nil }
            return CGPoint(x: x, y: y)
        }
    }
}

private struct ChartLineTraceCanvas: View {
    let head: CGPoint
    let tail: [CGPoint]
    let color: Color
    let style: ChartLineTraceStyle
    let plotRect: CGRect

    var body: some View {
        Canvas { context, _ in
            context.clip(to: Path(plotRect))

            for (index, point) in tail.enumerated() {
                let fraction = Double(index + 1) / Double(tail.count + 1)
                let radius = style.maxTailRadius
                    - (style.maxTailRadius - style.minTailRadius) * CGFloat(fraction)
                let opacity = style.maxTailOpacity * (1 - fraction * 0.85)
                let glowRadius = radius * 2.1
                let glowOpacity = style.tailGlowOpacity * (1 - fraction)

                fillCircle(
                    in: &context,
                    center: point,
                    radius: glowRadius,
                    color: color.opacity(glowOpacity)
                )
                fillCircle(
                    in: &context,
                    center: point,
                    radius: radius,
                    color: color.opacity(opacity)
                )
            }

            for (glowRadius, glowOpacity) in zip(style.headGlowRadii, style.headGlowOpacities) {
                fillCircle(
                    in: &context,
                    center: head,
                    radius: glowRadius,
                    color: color.opacity(glowOpacity * style.glowOpacity)
                )
            }

            fillCircle(
                in: &context,
                center: head,
                radius: style.headRadius,
                color: color
            )
            fillCircle(
                in: &context,
                center: head,
                radius: style.headRadius * 0.55,
                color: .white.opacity(style == .compact ? 0.35 : 0.45)
            )
        }
        .allowsHitTesting(false)
    }

    private func fillCircle(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        color: Color
    ) {
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        context.fill(Path(ellipseIn: rect), with: .color(color))
    }
}

extension View {
    func chartLineTrace(
        series: [ChartTraceSeries],
        style: ChartLineTraceStyle = .standard,
        phaseOffset: Int = 0
    ) -> some View {
        modifier(
            ChartLineTraceModifier(
                series: series,
                style: style,
                phaseOffset: TimeInterval(abs(phaseOffset) % 10_000) * 0.001
            )
        )
    }
}
