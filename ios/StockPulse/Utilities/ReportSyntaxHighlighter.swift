import SwiftUI

struct ParsedReportBody {
    let whatsNew: String?
    let researchWatchlist: String?
    let context: String?
    let remainder: String

    var hasStructuredSections: Bool {
        whatsNew != nil || researchWatchlist != nil || context != nil
    }
}

enum ReportBodyParser {
    private static let whatsNewPattern = #"(?i)^#{0,2}\s*what'?s new\s*$"#
    private static let researchPattern = #"(?i)^#{0,2}\s*research watchlist\s*$"#
    private static let contextPattern = #"(?i)^#{0,2}\s*context\s*$"#

    static func parse(_ body: String) -> ParsedReportBody {
        let lines = body.components(separatedBy: .newlines)
        var whatsNew: [String] = []
        var research: [String] = []
        var context: [String] = []
        var remainder: [String] = []
        var section: String?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.range(of: whatsNewPattern, options: .regularExpression) != nil {
                section = "new"
                continue
            }
            if trimmed.range(of: researchPattern, options: .regularExpression) != nil {
                section = "research"
                continue
            }
            if trimmed.range(of: contextPattern, options: .regularExpression) != nil {
                section = "context"
                continue
            }

            switch section {
            case "new":
                whatsNew.append(line)
            case "research":
                research.append(line)
            case "context":
                context.append(line)
            default:
                remainder.append(line)
            }
        }

        let newText = clean(whatsNew.joined(separator: "\n"))
        let researchText = clean(research.joined(separator: "\n"))
        let contextText = clean(context.joined(separator: "\n"))
        let restText = clean(remainder.joined(separator: "\n"))

        if newText != nil || researchText != nil || contextText != nil {
            return ParsedReportBody(
                whatsNew: newText,
                researchWatchlist: researchText,
                context: contextText,
                remainder: restText ?? ""
            )
        }

        return ParsedReportBody(whatsNew: nil, researchWatchlist: nil, context: nil, remainder: body)
    }

    private static func clean(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct TextStyle {
    let range: Range<String.Index>
    let color: Color
    let font: Font
}

enum ReportSyntaxHighlighter {
    private enum MoveSentiment {
        case positive
        case negative
    }

    private static let negativeMoveWords = [
        "drop", "drops", "dropped", "decline", "declined", "fall", "fell",
        "loss", "losses", "down", "lower", "slide", "slid", "sink", "retreat",
        "weaken", "underperform", "selloff", "sell-off", "off",
    ]

    private static let positiveMoveWords = [
        "gain", "gains", "gained", "rose", "rise", "rally", "climb", "jump",
        "surge", "up", "higher", "beat", "rebound", "advance", "bullish",
    ]

    static func highlight(_ text: String, baseFontSize: CGFloat = 12, emphasis: Bool = false) -> AttributedString {
        var attr = AttributedString(text)
        attr.font = DS.Font.sans(baseFontSize)
        attr.foregroundColor = emphasis ? DS.Color.textPrimary : DS.Color.textSecond

        let styles = collectStyles(in: text, baseFontSize: baseFontSize)
        for style in styles {
            guard let start = AttributedString.Index(style.range.lowerBound, within: attr),
                  let end = AttributedString.Index(style.range.upperBound, within: attr) else { continue }
            let range = start..<end
            attr[range].foregroundColor = style.color
            attr[range].font = style.font
        }
        return attr
    }

    private static func collectStyles(in text: String, baseFontSize: CGFloat) -> [TextStyle] {
        var styles: [TextStyle] = []
        styles += matches(
            pattern: #"(?m)^#{1,2}\s*.+$"#,
            in: text,
            color: DS.Color.blue,
            font: DS.Font.sans(baseFontSize, weight: .bold)
        )
        styles += matches(
            pattern: #"\b(CONFIRMED|FORMING|FAILED|WATCHING)\b"#,
            in: text,
            color: DS.Color.blue,
            font: DS.Font.mono(12, weight: .bold),
            colorForMatch: { match in
                switch match.uppercased() {
                case "CONFIRMED": return DS.Color.green
                case "FORMING": return DS.Color.orange
                case "FAILED": return DS.Color.red
                case "WATCHING": return DS.Color.blue
                default: return DS.Color.blue
                }
            }
        )
        styles += percentageStyles(in: text)
        styles += matches(
            pattern: #"\b[A-Z]{2,5}\b"#,
            in: text,
            color: DS.Color.orange,
            font: DS.Font.mono(12, weight: .bold),
            includeMatch: { !commonWords.contains($0) }
        )
        styles += matches(
            pattern: #"\b(WATCH|AVOID)\b"#,
            in: text,
            color: DS.Color.orange,
            font: DS.Font.mono(12, weight: .bold),
            colorForMatch: { match in
                match.uppercased() == "WATCH" ? DS.Color.green : DS.Color.red
            }
        )
        styles += matches(
            pattern: #"\b(bullish|bearish|neutral|RSI|SMA|overbought|oversold|breakout|support|resistance)\b"#,
            options: [.caseInsensitive],
            in: text,
            color: DS.Color.purple,
            font: DS.Font.sans(baseFontSize, weight: .semibold)
        )
        return styles
    }

    private static let commonWords: Set<String> = [
        "AI", "AM", "PM", "ET", "UTC", "USD", "THE", "AND", "FOR", "NEW", "ALL", "TOP"
    ]

    static func percentageColor(match: String, in text: String, at range: Range<String.Index>) -> Color {
        if match.hasPrefix("-") { return DS.Color.red }
        if match.hasPrefix("+") { return DS.Color.green }

        switch contextSentiment(before: range, in: text) {
        case .negative: return DS.Color.red
        case .positive: return DS.Color.green
        case nil: return DS.Color.textSecond
        }
    }

    private static func percentageStyles(in text: String) -> [TextStyle] {
        guard let regex = try? NSRegularExpression(pattern: #"[+-]?\d+(?:\.\d+)?%"#) else { return [] }
        let nsText = text as NSString
        var results: [TextStyle] = []
        for match in regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)) {
            guard let range = Range(match.range, in: text) else { continue }
            let snippet = String(text[range])
            let color = percentageColor(match: snippet, in: text, at: range)
            results.append(TextStyle(range: range, color: color, font: DS.Font.mono(12, weight: .bold)))
        }
        return results
    }

    private static func contextSentiment(
        before range: Range<String.Index>,
        in text: String,
        window: Int = 45
    ) -> MoveSentiment? {
        let start = text.index(range.lowerBound, offsetBy: -window, limitedBy: text.startIndex) ?? text.startIndex
        let context = String(text[start..<range.lowerBound]).lowercased()

        var closestPosition = -1
        var closestSentiment: MoveSentiment?

        for word in negativeMoveWords {
            guard let position = rightmostMatchPosition(for: word, in: context) else { continue }
            if position > closestPosition {
                closestPosition = position
                closestSentiment = .negative
            }
        }

        for word in positiveMoveWords {
            guard let position = rightmostMatchPosition(for: word, in: context) else { continue }
            if position > closestPosition {
                closestPosition = position
                closestSentiment = .positive
            }
        }

        return closestSentiment
    }

    private static func rightmostMatchPosition(for word: String, in text: String) -> Int? {
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let nsText = text as NSString
        var best: Int?
        for match in regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)) {
            let position = match.range.location
            if best == nil || position > best! {
                best = position
            }
        }
        return best
    }

    private static func matches(
        pattern: String,
        options: NSRegularExpression.Options = [],
        in text: String,
        color: Color,
        font: Font,
        colorForMatch: ((String) -> Color)? = nil,
        includeMatch: ((String) -> Bool)? = nil
    ) -> [TextStyle] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
        let nsText = text as NSString
        var results: [TextStyle] = []
        for match in regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)) {
            guard let range = Range(match.range, in: text) else { continue }
            let snippet = String(text[range])
            if let includeMatch, !includeMatch(snippet) { continue }
            let resolvedColor = colorForMatch?(snippet) ?? color
            results.append(TextStyle(range: range, color: resolvedColor, font: font))
        }
        return results
    }
}

struct HighlightedReportText: View {
    let text: String
    var fontSize: CGFloat = 12
    var emphasis: Bool = false

    var body: some View {
        Text(ReportSyntaxHighlighter.highlight(text, baseFontSize: fontSize, emphasis: emphasis))
            .lineSpacing(4)
            .spScrollContentWidth()
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct StructuredReportBodyView: View {
    let bodyText: String
    @State private var showContext = false

    private var parsed: ParsedReportBody {
        ReportBodyParser.parse(bodyText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            if let whatsNew = parsed.whatsNew {
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    Text("WHAT'S NEW")
                        .font(DS.Font.mono(9, weight: .bold))
                        .foregroundStyle(DS.Color.green)
                    HighlightedReportText(text: whatsNew, fontSize: 13, emphasis: true)
                }
            }

            if let research = parsed.researchWatchlist {
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    Text("RESEARCH WATCHLIST")
                        .font(DS.Font.mono(9, weight: .bold))
                        .foregroundStyle(DS.Color.orange)
                    HighlightedReportText(text: research, fontSize: 12, emphasis: true)
                }
            }

            if let context = parsed.context {
                DisclosureGroup(isExpanded: $showContext) {
                    HighlightedReportText(text: context, fontSize: 11)
                        .padding(.top, DS.Space.xs)
                } label: {
                    Text("Background context")
                        .font(DS.Font.mono(10, weight: .bold))
                        .foregroundStyle(DS.Color.textMuted)
                }
                .tint(DS.Color.textMuted)
            }

            if !parsed.remainder.isEmpty {
                HighlightedReportText(
                    text: parsed.remainder,
                    fontSize: parsed.hasStructuredSections ? 11 : 12,
                    emphasis: !parsed.hasStructuredSections
                )
                .opacity(parsed.hasStructuredSections ? 0.85 : 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum MarketTabReportMode {
    case whatsNewOnly
    case researchOnly
}

struct MarketTabReportView: View {
    let bodyText: String
    let mode: MarketTabReportMode

    private var parsed: ParsedReportBody {
        ReportBodyParser.parse(bodyText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            switch mode {
            case .whatsNewOnly:
                if let whatsNew = parsed.whatsNew {
                    HighlightedReportText(text: whatsNew, fontSize: 13, emphasis: true)
                } else {
                    HighlightedReportText(text: bodyText, fontSize: 13, emphasis: true)
                }
            case .researchOnly:
                if let research = parsed.researchWatchlist {
                    HighlightedReportText(text: research, fontSize: 12, emphasis: true)
                } else {
                    MarketSectionHint(text: "No research watchlist in the latest pulse yet.")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
