# StockPulse iOS — Complete Rewrite Plan
# Hand this entire document to Cursor. This IS the build spec.
# Last updated: June 3, 2026

---

## CRITICAL INSTRUCTION FOR CURSOR

You are rebuilding this iOS app from scratch.
Delete all existing Swift files except Info.plist and the .xcodeproj.

The DESIGN AUTHORITY is `stockpulse-v2-reference.jsx`.
Every screen, color, layout, and interaction must match that file.
Do not invent SwiftUI patterns. Translate the JSX directly.

The app must show real data on first launch with zero API calls.
All data is hardcoded in MockDataStore.swift.
There is no network layer in Phase 1. Build the UI first, data second.

---

## WHAT THE APP IS

StockPulse tracks "ripple effects" in the stock market.
When a major stock (called a Catalyst) moves due to an event,
other related stocks (called Ripples) tend to follow.

The app answers: **did the ripple actually happen?**

It shows:
- A normalized % chart of the catalyst + all its ripple stocks over 30 days
- Verdict badges: CONFIRMED / FORMING / FAILED / WATCHING
- Pre-event vs post-event % change for each ripple
- A scrolling ticker tape of current prices
- An AI analyst that knows the current data

---

## PHASE 1 — COMPLETE UI WITH HARDCODED DATA
### Goal: App looks identical to stockpulse-v2-reference.jsx on device

---

## STEP 1 — Project Setup

Create a new Xcode project:
- Name: StockPulse
- Interface: SwiftUI
- Minimum deployment: iOS 17.0
- No CoreData, no SwiftData (add later)

Add these fonts to the project (download from Google Fonts):
- IBM Plex Mono (Regular + Bold) — for all tickers, prices, labels
- DM Sans (Regular, Medium, SemiBold, Bold) — for body text

Register both fonts in Info.plist under UIAppFonts.

---

## STEP 2 — Design Tokens

Create `DesignSystem.swift`:

```swift
import SwiftUI

enum DS {
    // MARK: - Colors (match JSX exactly)
    enum Color {
        static let bg           = SwiftUI.Color(hex: "060a0f")   // root background
        static let surface      = SwiftUI.Color(hex: "0d1117")   // cards
        static let surface2     = SwiftUI.Color(hex: "111827")   // inset areas
        static let border       = SwiftUI.Color(hex: "1e2535")   // dividers
        static let border2      = SwiftUI.Color(hex: "374151")   // stronger border

        static let textPrimary  = SwiftUI.Color(hex: "e2e8f0")
        static let textSecond   = SwiftUI.Color(hex: "9ca3af")
        static let textMuted    = SwiftUI.Color(hex: "6b7280")
        static let textDim      = SwiftUI.Color(hex: "4b5563")

        static let blue         = SwiftUI.Color(hex: "60a5fa")   // primary accent
        static let blueDark     = SwiftUI.Color(hex: "2563eb")   // button fill
        static let green        = SwiftUI.Color(hex: "22c55e")   // positive / confirmed
        static let orange       = SwiftUI.Color(hex: "f59e0b")   // warning / catalyst
        static let orangeAlt    = SwiftUI.Color(hex: "f97316")   // roadshow event
        static let red          = SwiftUI.Color(hex: "ef4444")   // negative / failed
        static let purple       = SwiftUI.Color(hex: "a78bfa")   // speculate
        static let teal         = SwiftUI.Color(hex: "34d399")   // ripple line 6

        // Chart line colors (in order: catalyst first)
        static let chartLines: [SwiftUI.Color] = [
            SwiftUI.Color(hex: "f59e0b"),  // catalyst — orange
            SwiftUI.Color(hex: "22c55e"),  // ripple 1 — green
            SwiftUI.Color(hex: "60a5fa"),  // ripple 2 — blue
            SwiftUI.Color(hex: "a78bfa"),  // ripple 3 — purple
            SwiftUI.Color(hex: "fb923c"),  // ripple 4 — orange-light
            SwiftUI.Color(hex: "34d399"),  // ripple 5 — teal
        ]

        // Verdict colors
        static func verdict(_ v: RippleVerdict) -> SwiftUI.Color {
            switch v {
            case .confirmed: return green
            case .forming:   return orange
            case .failed:    return red
            case .watching:  return blue
            }
        }
    }

    // MARK: - Typography
    enum Font {
        // Monospaced — tickers, prices, labels, tags
        static func mono(_ size: CGFloat, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            .custom("IBMPlexMono-\(weight == .bold ? "Bold" : "Regular")", size: size)
        }
        // Body — descriptions, AI text
        static func sans(_ size: CGFloat, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            switch weight {
            case .bold:     return .custom("DMSans-Bold", size: size)
            case .semibold: return .custom("DMSans-SemiBold", size: size)
            case .medium:   return .custom("DMSans-Medium", size: size)
            default:        return .custom("DMSans-Regular", size: size)
            }
        }
    }

    // MARK: - Spacing
    enum Space {
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 12
        static let lg:  CGFloat = 16
        static let xl:  CGFloat = 20
        static let xxl: CGFloat = 24
    }

    // MARK: - Corner Radius
    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 10
        static let xl: CGFloat = 12
    }
}

// MARK: - Color hex init
extension SwiftUI.Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int & 0xFF)          / 255
        self.init(red: r, green: g, blue: b)
    }
}
```

---

## STEP 3 — Data Models (plain structs, NO SwiftData)

Create `Models.swift`:

```swift
import Foundation

// MARK: - Price History

struct PricePoint: Identifiable {
    let id = UUID()
    let date: Date
    let close: Double
}

// MARK: - Ripple Verdict

enum RippleVerdict: String {
    case confirmed = "CONFIRMED"
    case forming   = "FORMING"
    case failed    = "FAILED"
    case watching  = "WATCHING"

    var icon: String {
        switch self {
        case .confirmed: return "checkmark.circle.fill"
        case .forming:   return "circle.lefthalf.filled"
        case .failed:    return "xmark.circle.fill"
        case .watching:  return "eye.circle"
        }
    }
    var label: String { rawValue }
}

// MARK: - Ripple Stock

struct RippleStock: Identifiable {
    let id = UUID()
    let ticker: String
    let description: String
}

// MARK: - Market Event (vertical line on chart)

struct MarketEvent: Identifiable {
    let id = UUID()
    let dateIndex: Int   // index into the 30-day array
    let label: String
    let color: String    // hex
}

// MARK: - Catalyst

struct Catalyst: Identifiable {
    let id = UUID()
    let ticker: String
    let name: String
    let eventName: String
    let eventDateIndex: Int   // index into 30-day DATES array
    let ripples: [RippleStock]
    let events: [MarketEvent]
}

// MARK: - Ripple Result (computed)

struct RippleResult: Identifiable {
    let id = UUID()
    let catalystTicker: String
    let rippleTicker: String
    let rippleDescription: String
    let verdict: RippleVerdict
    let preEventPct: Double
    let postEventPct: Double

    var explanation: String {
        switch verdict {
        case .confirmed:
            return "\(rippleTicker) rose \(String(format: "%.1f", postEventPct))% after the \(catalystTicker) event. Ripple confirmed."
        case .forming:
            return "\(rippleTicker) showing +\(String(format: "%.1f", postEventPct))% drift. Not yet decisive — watch for acceleration."
        case .failed:
            return "\(rippleTicker) did not follow \(catalystTicker). Sector correlation broke down."
        case .watching:
            return "Catalyst still early. Pre-event move \(String(format: "%.1f", preEventPct))% suggests anticipation building."
        }
    }
}

// MARK: - Watchlist Row Data

struct WatchItem: Identifiable {
    let id = UUID()
    let ticker: String
    let history: [PricePoint]
    let rippleBadges: [(catalystTicker: String, verdict: RippleVerdict)]

    var currentPrice: Double  { history.last?.close ?? 0 }
    var previousPrice: Double { history.count >= 2 ? history[history.count - 2].close : currentPrice }
    var firstPrice: Double    { history.first?.close ?? currentPrice }

    var change1D: Double  { previousPrice > 0 ? ((currentPrice - previousPrice) / previousPrice) * 100 : 0 }
    var change30D: Double { firstPrice > 0 ? ((currentPrice - firstPrice) / firstPrice) * 100 : 0 }

    var normalizedHistory: [(date: Date, pct: Double)] {
        guard firstPrice > 0 else { return [] }
        return history.map { pt in
            (date: pt.date, pct: ((pt.close - firstPrice) / firstPrice) * 100)
        }
    }
}
```

---

## STEP 4 — Mock Data Store

Create `MockDataStore.swift`.
This is the SINGLE SOURCE of all data. No network calls in Phase 1.

```swift
import Foundation

struct MockDataStore {

    // MARK: - 30-day date labels
    static let dateLabels = [
        "05/04","05/05","05/06","05/07","05/08","05/09","05/10",
        "05/11","05/12","05/13","05/14","05/15","05/16","05/17",
        "05/18","05/19","05/20","05/21","05/22","05/23","05/24",
        "05/25","05/26","05/27","05/28","05/29","05/30","05/31",
        "06/01","06/02"
    ]

    static let dates: [Date] = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        let year = "2026"
        return dateLabels.compactMap { formatter.date(from: "\(year)/\($0)") }
    }()

    // MARK: - Raw closing prices
    static let rawPrices: [String: [Double]] = [
        "SPCX": [280.69,280.29,279.85,278.89,284.71,287.22,290.44,288.91,292.3,295.1,
                 298.8,296.2,299.5,302.1,298.9,296.4,300.2,304.5,308.1,312.9,
                 320.4,325.1,322.8,318.9,316.2,314.8,318.3,321.7,319.2,324.52],
        "RKLB": [21.69,21.4,21.82,21.55,22.1,22.44,22.9,22.6,23.1,23.8,
                 24.2,23.7,24.0,24.4,23.9,23.5,24.1,24.7,25.1,25.6,
                 26.2,26.8,26.4,26.0,25.7,25.4,25.9,26.3,26.1,26.99],
        "TSLA": [257.59,256.8,258.2,255.9,257.1,259.4,261.2,259.8,260.5,258.9,
                 262.1,264.3,261.8,259.2,261.5,263.8,260.4,258.7,261.9,264.5,
                 262.1,260.8,263.4,265.7,263.2,261.9,264.8,266.1,264.5,264.27],
        "NVDA": [127.78,128.4,129.1,128.5,129.8,131.2,133.5,132.1,133.8,135.2,
                 143.8,141.5,142.9,144.3,142.8,141.2,143.5,145.1,143.7,144.9,
                 146.2,145.8,144.6,146.1,147.3,145.9,147.2,148.5,146.9,139.16],
        "ASTS": [17.53,17.2,17.8,17.4,18.1,18.5,19.0,18.6,19.2,19.8,
                 20.2,19.7,20.1,20.6,20.1,19.7,20.3,20.9,21.4,22.0,
                 22.8,23.4,23.0,22.6,22.3,22.0,22.5,23.0,22.8,23.34],
        "LUNR": [9.63,9.5,9.7,9.55,9.8,9.95,10.1,9.9,10.15,10.3,
                 10.5,10.3,10.45,10.6,10.4,10.2,10.45,10.65,10.5,10.7,
                 10.9,11.1,10.95,10.8,10.65,10.5,10.7,10.85,10.7,10.64],
        "HWM":  [125.49,125.8,126.2,125.6,126.5,127.1,127.8,127.3,128.0,128.7,
                 129.4,129.0,129.6,130.2,129.7,129.2,130.0,130.8,130.3,131.1,
                 131.8,132.5,132.1,132.9,133.6,133.1,134.0,134.8,134.3,136.94],
        "RDW":  [7.01,6.9,7.1,6.95,7.15,7.25,7.4,7.2,7.35,7.5,
                 7.65,7.5,7.6,7.75,7.6,7.45,7.6,7.8,7.65,7.85,
                 8.0,8.2,8.05,7.9,7.75,7.6,7.75,7.9,7.75,7.34],
        "AMD":  [157.35,158.1,159.0,158.2,159.5,160.8,162.4,161.2,162.9,164.3,
                 168.8,167.2,168.5,169.8,168.3,167.0,168.8,170.2,168.9,170.3,
                 171.5,170.8,169.6,171.1,172.3,170.9,172.2,173.5,171.9,170.6],
        "AVGO": [210.01,211.2,212.5,211.3,213.0,214.8,216.5,215.1,217.2,218.8,
                 222.4,220.9,222.1,223.8,222.1,220.7,222.5,224.3,222.8,224.5,
                 226.1,225.4,224.2,226.0,227.5,225.9,227.4,228.9,227.2,229.35],
    ]

    // MARK: - Build PricePoint history for a ticker
    static func history(for ticker: String) -> [PricePoint] {
        guard let prices = rawPrices[ticker] else { return [] }
        return zip(dates, prices).map { PricePoint(date: $0, close: $1) }
    }

    // MARK: - Catalysts
    static let catalysts: [Catalyst] = [
        Catalyst(
            ticker: "SPCX", name: "SpaceX",
            eventName: "IPO Filing + Roadshow",
            eventDateIndex: 20,
            ripples: [
                RippleStock(ticker: "RKLB", description: "Primary proxy — launch competitor"),
                RippleStock(ticker: "ASTS", description: "Satellite connectivity play"),
                RippleStock(ticker: "LUNR", description: "Lunar infrastructure"),
                RippleStock(ticker: "HWM",  description: "Aerospace components"),
                RippleStock(ticker: "RDW",  description: "Spacecraft components"),
            ],
            events: [
                MarketEvent(dateIndex: 10, label: "NVDA Earnings",    color: "22c55e"),
                MarketEvent(dateIndex: 20, label: "SPCX IPO Filing",  color: "f59e0b"),
                MarketEvent(dateIndex: 25, label: "SPCX Roadshow",    color: "f97316"),
            ]
        ),
        Catalyst(
            ticker: "NVDA", name: "NVIDIA",
            eventName: "Q1 Earnings Beat",
            eventDateIndex: 10,
            ripples: [
                RippleStock(ticker: "AMD",  description: "Chip sector peer"),
                RippleStock(ticker: "AVGO", description: "AI networking"),
            ],
            events: [
                MarketEvent(dateIndex: 10, label: "NVDA Earnings", color: "22c55e"),
            ]
        ),
    ]

    // MARK: - Watchlist tickers in display order
    static let watchlistTickers = ["SPCX","RKLB","TSLA","NVDA","ASTS","LUNR","HWM","RDW","AMD","AVGO"]

    // MARK: - Compute ripple verdict
    static func verdict(catalystTicker: String, rippleTicker: String, eventDateIndex: Int) -> RippleVerdict {
        guard let catPrices = rawPrices[catalystTicker],
              let ripPrices = rawPrices[rippleTicker],
              eventDateIndex < catPrices.count else { return .watching }

        let catPost = ((catPrices.last! - catPrices[eventDateIndex]) / catPrices[eventDateIndex]) * 100
        let ripPost = ((ripPrices.last! - ripPrices[eventDateIndex]) / ripPrices[eventDateIndex]) * 100
        let ripPre  = ((ripPrices[eventDateIndex] - ripPrices[0]) / ripPrices[0]) * 100

        if catPost > 3.0 && ripPost > 2.0 { return .confirmed }
        if catPost > 3.0 && ripPost > 0.5 { return .forming }
        if catPost > 3.0 && ripPost <= 0   { return .failed }
        return .watching
    }

    // MARK: - Build all ripple results for a catalyst
    static func rippleResults(for catalyst: Catalyst) -> [RippleResult] {
        guard let catPrices = rawPrices[catalyst.ticker] else { return [] }
        let eventIdx = catalyst.eventDateIndex

        return catalyst.ripples.compactMap { ripple in
            guard let ripPrices = rawPrices[ripple.ticker] else { return nil }
            let prePct  = ((ripPrices[eventIdx] - ripPrices[0]) / ripPrices[0]) * 100
            let postPct = ((ripPrices.last! - ripPrices[eventIdx]) / ripPrices[eventIdx]) * 100
            let v = verdict(catalystTicker: catalyst.ticker,
                            rippleTicker: ripple.ticker,
                            eventDateIndex: eventIdx)
            return RippleResult(
                catalystTicker: catalyst.ticker,
                rippleTicker: ripple.ticker,
                rippleDescription: ripple.description,
                verdict: v,
                preEventPct: prePct,
                postEventPct: postPct
            )
        }
    }

    // MARK: - Build watchlist items
    static func watchItems() -> [WatchItem] {
        watchlistTickers.map { ticker in
            let badges: [(String, RippleVerdict)] = catalysts
                .filter { c in c.ripples.contains(where: { $0.ticker == ticker }) }
                .map { c in (c.ticker, verdict(catalystTicker: c.ticker,
                                                rippleTicker: ticker,
                                                eventDateIndex: c.eventDateIndex)) }
            return WatchItem(ticker: ticker, history: history(for: ticker), rippleBadges: badges)
        }
    }

    // MARK: - Normalized chart data for multiple tickers
    static func normalizedSeries(tickers: [String]) -> [(ticker: String, points: [(date: Date, pct: Double)])] {
        tickers.compactMap { ticker in
            guard let prices = rawPrices[ticker], let first = prices.first, first > 0 else { return nil }
            let points = zip(dates, prices).map { (date: $0, pct: (($1 - first) / first) * 100) }
            return (ticker: ticker, points: points)
        }
    }
}
```

---

## STEP 5 — ViewModel

Create `StockPulseViewModel.swift`:

```swift
import Foundation
import Observation

@Observable
class StockPulseViewModel {

    // MARK: - Data (loaded immediately from MockDataStore)
    var catalysts: [Catalyst]        = MockDataStore.catalysts
    var watchItems: [WatchItem]      = MockDataStore.watchItems()
    var selectedCatalystIndex: Int   = 0

    var selectedCatalyst: Catalyst   { catalysts[selectedCatalystIndex] }
    var currentRippleResults: [RippleResult] {
        MockDataStore.rippleResults(for: selectedCatalyst)
    }

    // MARK: - Ticker tape (cycles through watchlist)
    var tickerTapeItems: [(ticker: String, price: Double, change1D: Double)] {
        watchItems.map { ($0.ticker, $0.currentPrice, $0.change1D) }
    }

    // MARK: - Chart data for selected catalyst
    var chartSeries: [(ticker: String, points: [(date: Date, pct: Double)])] {
        let tickers = [selectedCatalyst.ticker] + selectedCatalyst.ripples.map(\.ticker)
        return MockDataStore.normalizedSeries(tickers: tickers)
    }

    // MARK: - AI
    var aiQuery    = ""
    var aiResponse = ""
    var aiLoading  = false

    @MainActor
    func askAI() async {
        guard !aiQuery.isEmpty else { return }
        aiLoading = true
        aiResponse = ""

        let context = buildAIContext()
        do {
            let res = try await callGroq(prompt: aiQuery, context: context)
            aiResponse = res
        } catch {
            aiResponse = "Error: \(error.localizedDescription)"
        }
        aiLoading = false
    }

    private func buildAIContext() -> String {
        var lines = ["You are a stock market analyst. 30-day data May 4–Jun 2 2026.\n"]
        for item in watchItems {
            lines.append("\(item.ticker): $\(String(format: "%.2f", item.currentPrice)), 30d: \(String(format: "%+.1f", item.change30D))%")
        }
        lines.append("\nRipple verdicts:")
        for catalyst in catalysts {
            for result in MockDataStore.rippleResults(for: catalyst) {
                lines.append("\(result.catalystTicker)→\(result.rippleTicker): \(result.verdict.rawValue) (post: \(String(format: "%+.1f", result.postEventPct))%)")
            }
        }
        lines.append("\nAnswer in 3-5 sentences. Be direct and actionable.")
        return lines.joined(separator: "\n")
    }

    private func callGroq(prompt: String, context: String) async throws -> String {
        struct Req: Encodable {
            let model: String; let messages: [Msg]; let max_tokens: Int
            struct Msg: Encodable { let role: String; let content: String }
        }
        struct Res: Decodable {
            struct Choice: Decodable { struct Msg: Decodable { let content: String }; let message: Msg }
            let choices: [Choice]
        }
        let key = Bundle.main.object(forInfoDictionaryKey: "GROQ_API_KEY") as? String ?? ""
        let body = Req(model: "llama-3.3-70b-versatile",
                       messages: [.init(role: "system", content: context),
                                  .init(role: "user", content: prompt)],
                       max_tokens: 400)
        var req = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/chat/completions")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, _) = try await URLSession.shared.data(for: req)
        let decoded = try JSONDecoder().decode(Res.self, from: data)
        return decoded.choices.first?.message.content ?? "No response."
    }
}
```

---

## STEP 6 — App Entry Point

Create `StockPulseApp.swift`:

```swift
import SwiftUI

@main
struct StockPulseApp: App {
    // ViewModel init loads MockDataStore immediately — data ready before first frame
    @State private var vm = StockPulseViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(vm)
                .preferredColorScheme(.dark)
        }
    }
}
```

Create `RootView.swift`:

```swift
import SwiftUI

struct RootView: View {
    var body: some View {
        ZStack {
            DS.Color.bg.ignoresSafeArea()   // ← black background covers ALL safe areas

            TabView {
                RippleTrackerView()
                    .tabItem { Label("Ripple", systemImage: "waveform.path") }

                WatchlistView()
                    .tabItem { Label("Watchlist", systemImage: "list.bullet.rectangle") }

                TrendsView()
                    .tabItem { Label("Trends", systemImage: "chart.line.uptrend.xyaxis") }

                AIAnalystView()
                    .tabItem { Label("AI", systemImage: "brain.head.profile") }
            }
            .tint(DS.Color.blue)
        }
    }
}
```

---

## STEP 7 — Shared Components

### 7a. SparklineView.swift
```swift
import SwiftUI
import Charts

struct SparklineView: View {
    let points: [(date: Date, pct: Double)]
    var positive: Bool = true
    var height: CGFloat = 32
    var width: CGFloat = 80
    var showArea: Bool = true
    var eventDate: Date? = nil

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
        .chartXAxis(.hidden).chartYAxis(.hidden).chartLegend(.hidden)
        .frame(width: width, height: height)
    }
}
```

### 7b. VerdictBadge.swift
```swift
import SwiftUI

struct VerdictBadge: View {
    let verdict: RippleVerdict
    var compact: Bool = false

    var color: Color { DS.Color.verdict(verdict) }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: verdict.icon)
                .font(.system(size: compact ? 8 : 10, weight: .bold))
            Text(verdict.label)
                .font(DS.Font.mono(compact ? 8 : 10, weight: .bold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 2 : 3)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
    }
}
```

### 7c. SectionLabel.swift
```swift
import SwiftUI

/// Uppercase monospaced section header — matches JSX "KEY EVENTS", "RIPPLE VERIFICATION" etc.
struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(DS.Font.mono(10, weight: .bold))
            .foregroundStyle(DS.Color.textDim)
            .tracking(1.0)
            .textCase(.uppercase)
    }
}
```

### 7d. SPCard.swift (standard card container)
```swift
import SwiftUI

/// Dark card matching JSX: background #0d1117, border #1e2535, radius 10
struct SPCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .background(DS.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(DS.Color.border, lineWidth: 1)
            )
    }
}
```

### 7e. TickerTapeView.swift
```swift
import SwiftUI

struct TickerTapeView: View {
    let items: [(ticker: String, price: Double, change1D: Double)]
    @State private var offset: CGFloat = 0
    private let itemWidth: CGFloat = 140

    var body: some View {
        let allItems = items + items  // duplicate for seamless loop
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(Array(allItems.enumerated()), id: \.offset) { i, item in
                    HStack(spacing: 4) {
                        Text(item.ticker)
                            .font(DS.Font.mono(11, weight: .bold))
                            .foregroundStyle(DS.Color.textPrimary)
                        Text("$\(String(format: "%.2f", item.price))")
                            .font(DS.Font.mono(11))
                            .foregroundStyle(DS.Color.textSecond)
                        HStack(spacing: 2) {
                            Image(systemName: item.change1D >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                                .font(.system(size: 7))
                            Text(String(format: "%.2f%%", abs(item.change1D)))
                                .font(DS.Font.mono(11))
                        }
                        .foregroundStyle(item.change1D >= 0 ? DS.Color.green : DS.Color.red)
                    }
                    .frame(width: itemWidth)
                }
            }
            .offset(x: -offset)
            .onAppear {
                withAnimation(.linear(duration: Double(items.count) * 3).repeatForever(autoreverses: false)) {
                    offset = itemWidth * CGFloat(items.count)
                }
            }
        }
        .frame(height: 28)
        .clipped()
        .background(DS.Color.bg)
    }
}
```

---

## STEP 8 — Ripple Tracker View

This is the main tab. Match the JSX RipplePanel exactly.

Create `RippleTrackerView.swift`:

```swift
import SwiftUI
import Charts

struct RippleTrackerView: View {
    @Environment(StockPulseViewModel.self) private var vm
    @State private var expandedTicker: String? = nil

    var body: some View {
        ZStack {
            DS.Color.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.lg) {

                    // App header (matches JSX header exactly)
                    AppHeaderView()

                    // Ticker tape
                    TickerTapeView(items: vm.tickerTapeItems)

                    VStack(alignment: .leading, spacing: DS.Space.lg) {

                        // Key events card
                        KeyEventsCard(events: vm.selectedCatalyst.events)

                        // Catalyst selector cards (horizontal)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DS.Space.md) {
                                ForEach(Array(vm.catalysts.enumerated()), id: \.element.id) { idx, cat in
                                    CatalystCard(
                                        catalyst: cat,
                                        isSelected: vm.selectedCatalystIndex == idx
                                    ) {
                                        vm.selectedCatalystIndex = idx
                                    }
                                }
                            }
                        }

                        // Normalized trend chart
                        NormalizedChartCard(
                            catalyst: vm.selectedCatalyst,
                            series: vm.chartSeries
                        )

                        // Ripple verdict cards
                        SectionLabel(text: "Ripple Verification")

                        ForEach(vm.currentRippleResults) { result in
                            RippleCard(
                                result: result,
                                catalyst: vm.selectedCatalyst,
                                isExpanded: expandedTicker == result.rippleTicker
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    expandedTicker = expandedTicker == result.rippleTicker
                                        ? nil : result.rippleTicker
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DS.Space.lg)
                    .padding(.bottom, DS.Space.xxl)
                }
            }
        }
    }
}

// MARK: - App Header
struct AppHeaderView: View {
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "diamond.fill")
                        .foregroundStyle(DS.Color.blue)
                        .font(.system(size: 14))
                    Text("STOCKPULSE")
                        .font(DS.Font.mono(17, weight: .bold))
                        .foregroundStyle(DS.Color.blue)
                        .tracking(1)
                }
                Text("Ripple Intelligence · 30-Day History · Trend Verification")
                    .font(DS.Font.mono(10))
                    .foregroundStyle(DS.Color.textMuted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("DATA THROUGH")
                    .font(DS.Font.mono(9))
                    .foregroundStyle(DS.Color.textDim)
                    .tracking(0.5)
                Text("Jun 02, 2026")
                    .font(DS.Font.mono(13, weight: .bold))
                    .foregroundStyle(DS.Color.orange)
            }
        }
        .padding(.horizontal, DS.Space.lg)
        .padding(.top, DS.Space.lg)
        .padding(.bottom, DS.Space.sm)
        .background(DS.Color.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(DS.Color.border).frame(height: 1)
        }
    }
}

// MARK: - Key Events Card
struct KeyEventsCard: View {
    let events: [MarketEvent]
    var body: some View {
        SPCard {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                SectionLabel(text: "Key Events")
                FlowLayout(spacing: DS.Space.lg) {
                    ForEach(events) { event in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: event.color))
                                .frame(width: 8, height: 8)
                            Text(event.label.hasPrefix("05") || event.label.hasPrefix("06")
                                 ? event.label
                                 : MockDataStore.dateLabels[safe: event.dateIndex] ?? "")
                                .font(DS.Font.mono(12, weight: .bold))
                                .foregroundStyle(Color(hex: event.color))
                            Text(event.label)
                                .font(DS.Font.sans(12))
                                .foregroundStyle(DS.Color.textSecond)
                        }
                    }
                }
            }
            .padding(DS.Space.lg)
        }
    }
}

// MARK: - Catalyst Card
struct CatalystCard: View {
    let catalyst: Catalyst
    let isSelected: Bool
    let onTap: () -> Void

    private var postEventPct: Double {
        guard let prices = MockDataStore.rawPrices[catalyst.ticker],
              catalyst.eventDateIndex < prices.count,
              let last = prices.last,
              prices[catalyst.eventDateIndex] > 0 else { return 0 }
        return ((last - prices[catalyst.eventDateIndex]) / prices[catalyst.eventDateIndex]) * 100
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(catalyst.ticker)
                        .font(DS.Font.mono(15, weight: .bold))
                        .foregroundStyle(DS.Color.textPrimary)
                    Spacer()
                    Text(String(format: "%+.1f%% post-event", postEventPct))
                        .font(DS.Font.mono(12, weight: .bold))
                        .foregroundStyle(postEventPct >= 0 ? DS.Color.green : DS.Color.red)
                }
                Text(catalyst.eventName)
                    .font(DS.Font.sans(12))
                    .foregroundStyle(DS.Color.textSecond)
                Text("\(catalyst.ripples.count) tracked ripple stocks")
                    .font(DS.Font.mono(10))
                    .foregroundStyle(DS.Color.textDim)
            }
            .padding(DS.Space.md)
            .frame(width: 200)
            .background(isSelected ? DS.Color.blue.opacity(0.12) : DS.Color.surface2)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(isSelected ? DS.Color.blue : DS.Color.border, lineWidth: 1)
            )
        }
    }
}

// MARK: - Normalized Chart Card
struct NormalizedChartCard: View {
    let catalyst: Catalyst
    let series: [(ticker: String, points: [(date: Date, pct: Double)])]

    var body: some View {
        SPCard {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                // Label matching JSX
                Text("CATALYST: \(catalyst.ticker) — \(catalyst.eventName.uppercased())")
                    .font(DS.Font.mono(10))
                    .foregroundStyle(DS.Color.textDim)
                    .tracking(0.5)

                // Chart
                Chart {
                    // Zero line
                    RuleMark(y: .value("Zero", 0))
                        .foregroundStyle(DS.Color.border2.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                    // Event markers
                    ForEach(catalyst.events) { event in
                        if event.dateIndex < MockDataStore.dates.count {
                            RuleMark(x: .value("Ev", MockDataStore.dates[event.dateIndex]))
                                .foregroundStyle(Color(hex: event.color).opacity(0.6))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                                .annotation(position: .top, alignment: .leading) {
                                    Text(event.label)
                                        .font(DS.Font.mono(8))
                                        .foregroundStyle(Color(hex: event.color))
                                }
                        }
                    }

                    // Stock lines
                    ForEach(Array(series.enumerated()), id: \.offset) { idx, s in
                        let color = DS.Color.chartLines[min(idx, DS.Color.chartLines.count - 1)]
                        ForEach(Array(s.points.enumerated()), id: \.offset) { _, pt in
                            LineMark(
                                x: .value("Date", pt.date),
                                y: .value("Pct", pt.pct),
                                series: .value("Ticker", s.ticker)
                            )
                            .foregroundStyle(color)
                            .lineStyle(StrokeStyle(lineWidth: idx == 0 ? 2.5 : 1.8))
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { v in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(DS.Color.border)
                        AxisValueLabel {
                            if let d = v.as(Double.self) {
                                Text("\(d >= 0 ? "+" : "")\(Int(d))%")
                                    .font(DS.Font.mono(9))
                                    .foregroundStyle(DS.Color.textDim)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 5)) { v in
                        AxisGridLine().foregroundStyle(DS.Color.border.opacity(0.3))
                        AxisValueLabel(format: .dateTime.month(.twoDigits).day(.twoDigits))
                            .font(DS.Font.mono(8))
                            .foregroundStyle(DS.Color.textDim)
                    }
                }
                .frame(height: 200)
                .chartBackground { _ in DS.Color.bg }

                // Note
                Text("All lines normalized to % change from May 4. Dashed lines = key events.")
                    .font(DS.Font.mono(9))
                    .foregroundStyle(DS.Color.textDim)

                // Legend
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 6) {
                    ForEach(Array(series.enumerated()), id: \.offset) { idx, s in
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(DS.Color.chartLines[min(idx, DS.Color.chartLines.count - 1)])
                                .frame(width: 16, height: 2)
                            Text(s.ticker)
                                .font(DS.Font.mono(11, weight: .bold))
                                .foregroundStyle(DS.Color.textSecond)
                        }
                    }
                }
            }
            .padding(DS.Space.lg)
        }
    }
}

// MARK: - Ripple Card
struct RippleCard: View {
    let result: RippleResult
    let catalyst: Catalyst
    let isExpanded: Bool
    let onTap: () -> Void

    var color: Color { DS.Color.verdict(result.verdict) }

    var body: some View {
        SPCard {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                Button(action: onTap) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(result.rippleTicker)
                                .font(DS.Font.mono(15, weight: .bold))
                                .foregroundStyle(DS.Color.textPrimary)
                            Text(result.rippleDescription)
                                .font(DS.Font.sans(12))
                                .foregroundStyle(DS.Color.textMuted)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 6) {
                            VerdictBadge(verdict: result.verdict)
                            // Sparkline
                            let rippleHistory = MockDataStore.history(for: result.rippleTicker)
                            let pts = rippleHistory.map { (date: $0.date, pct: (($0.close - (rippleHistory.first?.close ?? $0.close)) / (rippleHistory.first?.close ?? 1)) * 100) }
                            SparklineView(
                                points: pts,
                                positive: result.postEventPct >= 0,
                                height: 30, width: 80,
                                showArea: true
                            )
                        }
                    }
                }
                .foregroundStyle(.primary)
                .padding(DS.Space.md)

                // Stats row
                HStack(spacing: DS.Space.xl) {
                    VStack(alignment: .leading, spacing: 2) {
                        SectionLabel(text: "Pre-event")
                        Text(String(format: "%+.1f%%", result.preEventPct))
                            .font(DS.Font.mono(12, weight: .bold))
                            .foregroundStyle(result.preEventPct >= 0 ? DS.Color.green : DS.Color.red)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        SectionLabel(text: "Post-event")
                        Text(String(format: "%+.1f%%", result.postEventPct))
                            .font(DS.Font.mono(12, weight: .bold))
                            .foregroundStyle(result.postEventPct >= 0 ? DS.Color.green : DS.Color.red)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(DS.Color.textMuted)
                        .font(.caption)
                }
                .padding(.horizontal, DS.Space.md)
                .padding(.bottom, DS.Space.md)

                // Expanded detail
                if isExpanded {
                    Divider().overlay(DS.Color.border)
                    VStack(alignment: .leading, spacing: DS.Space.sm) {
                        // Verdict explanation
                        HStack(alignment: .top, spacing: DS.Space.sm) {
                            Image(systemName: result.verdict.icon)
                                .foregroundStyle(color)
                                .font(.system(size: 14))
                            Text(result.explanation)
                                .font(DS.Font.sans(13))
                                .foregroundStyle(DS.Color.textSecond)
                        }
                        .padding(DS.Space.md)
                        .background(color.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(color)
                                .frame(width: 3)
                        }
                    }
                    .padding(DS.Space.md)
                }
            }
        }
    }
}
```

---

## STEP 9 — Watchlist View

```swift
// WatchlistView.swift
import SwiftUI

struct WatchlistView: View {
    @Environment(StockPulseViewModel.self) private var vm
    @State private var selectedTicker: String? = nil

    var body: some View {
        ZStack {
            DS.Color.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Inline header — NO NavigationStack, NO large title
                HStack {
                    Text("Watchlist")
                        .font(DS.Font.sans(20, weight: .bold))
                        .foregroundStyle(DS.Color.textPrimary)
                    Spacer()
                    Text("Jun 02")
                        .font(DS.Font.mono(11))
                        .foregroundStyle(DS.Color.textMuted)
                }
                .padding(.horizontal, DS.Space.lg)
                .padding(.vertical, DS.Space.md)
                .background(DS.Color.surface)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(DS.Color.border).frame(height: 1)
                }

                // Detail banner (slides in when row tapped)
                if let ticker = selectedTicker,
                   let item = vm.watchItems.first(where: { $0.ticker == ticker }) {
                    WatchDetailBanner(item: item) { selectedTicker = nil }
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // List
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.watchItems) { item in
                            WatchRow(
                                item: item,
                                isSelected: selectedTicker == item.ticker
                            ) {
                                withAnimation(.spring(response: 0.25)) {
                                    selectedTicker = selectedTicker == item.ticker ? nil : item.ticker
                                }
                            }
                            Rectangle().fill(DS.Color.border).frame(height: 1)
                        }
                    }
                }
            }
        }
        .animation(.spring(response: 0.3), value: selectedTicker)
    }
}

// MARK: - Watch Row
struct WatchRow: View {
    let item: WatchItem
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Ticker + badges
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.ticker)
                        .font(DS.Font.mono(14, weight: .bold))
                        .foregroundStyle(DS.Color.textPrimary)
                    if !item.rippleBadges.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(item.rippleBadges, id: \.catalystTicker) { badge in
                                HStack(spacing: 3) {
                                    Image(systemName: badge.verdict.icon)
                                        .font(.system(size: 8))
                                    Text("↑\(badge.catalystTicker)")
                                        .font(DS.Font.mono(9, weight: .bold))
                                }
                                .foregroundStyle(DS.Color.verdict(badge.verdict))
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(DS.Color.verdict(badge.verdict).opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                        }
                    }
                }
                .frame(width: 88, alignment: .leading)

                Spacer(minLength: 4)

                // Price + 1D change
                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(String(format: "%.2f", item.currentPrice))")
                        .font(DS.Font.mono(13, weight: .semibold))
                        .foregroundStyle(DS.Color.textPrimary)
                    Text(String(format: "%+.2f%%", item.change1D))
                        .font(DS.Font.mono(11))
                        .foregroundStyle(item.change1D >= 0 ? DS.Color.green : DS.Color.red)
                }
                .frame(width: 76, alignment: .trailing)

                // Sparkline
                SparklineView(
                    points: item.normalizedHistory,
                    positive: item.change30D >= 0,
                    height: 34, width: 72,
                    showArea: true
                )
                .padding(.horizontal, DS.Space.sm)

                // 30D change
                Text(String(format: "%+.1f%%", item.change30D))
                    .font(DS.Font.mono(11))
                    .foregroundStyle(item.change30D >= 0 ? DS.Color.green : DS.Color.red)
                    .frame(width: 52, alignment: .trailing)
            }
            .padding(.vertical, DS.Space.sm)
            .padding(.horizontal, DS.Space.lg)
            .background(isSelected ? DS.Color.blue.opacity(0.06) : DS.Color.bg)
        }
        .foregroundStyle(.primary)
    }
}

// MARK: - Detail Banner
struct WatchDetailBanner: View {
    let item: WatchItem
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.ticker)
                        .font(DS.Font.mono(22, weight: .bold))
                        .foregroundStyle(DS.Color.textPrimary)
                    Text("$\(String(format: "%.2f", item.currentPrice))")
                        .font(DS.Font.mono(16))
                        .foregroundStyle(DS.Color.textSecond)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DS.Color.textMuted)
                        .font(.title2)
                }
            }

            HStack(spacing: DS.Space.sm) {
                ForEach([
                    ("1D", String(format: "%+.2f%%", item.change1D), item.change1D >= 0),
                    ("30D", String(format: "%+.1f%%", item.change30D), item.change30D >= 0),
                ], id: \.0) { label, value, positive in
                    VStack(alignment: .leading, spacing: 3) {
                        SectionLabel(text: label)
                        Text(value)
                            .font(DS.Font.mono(13, weight: .bold))
                            .foregroundStyle(positive ? DS.Color.green : DS.Color.red)
                    }
                    .padding(DS.Space.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.Color.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                }
            }

            SparklineView(
                points: item.normalizedHistory,
                positive: item.change30D >= 0,
                height: 80,
                width: UIScreen.main.bounds.width - 48,
                showArea: true
            )
        }
        .padding(DS.Space.lg)
        .background(DS.Color.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(DS.Color.border).frame(height: 1)
        }
    }
}
```

---

## STEP 10 — AI Analyst View

```swift
// AIAnalystView.swift
import SwiftUI

struct AIAnalystView: View {
    @Environment(StockPulseViewModel.self) private var vm
    @FocusState private var focused: Bool

    let suggestions = [
        "Did SPCX actually lift RKLB?",
        "Which ripple confirmed most strongly?",
        "Is it too late to buy ASTS?",
        "Compare NVDA and SPCX ripple strength",
        "Which space stock has best risk/reward?",
    ]

    var body: some View {
        ZStack {
            DS.Color.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.lg) {
                    // Header
                    HStack {
                        Text("AI Analyst")
                            .font(DS.Font.sans(20, weight: .bold))
                            .foregroundStyle(DS.Color.textPrimary)
                        Spacer()
                        HStack(spacing: 4) {
                            Circle().fill(DS.Color.green).frame(width: 6, height: 6)
                            Text("30-day context loaded")
                                .font(DS.Font.mono(10))
                                .foregroundStyle(DS.Color.green)
                        }
                    }
                    .padding(.horizontal, DS.Space.lg)
                    .padding(.top, DS.Space.lg)

                    // Suggestion chips
                    FlowLayout(spacing: DS.Space.sm) {
                        ForEach(suggestions, id: \.self) { q in
                            Button(q) {
                                vm.aiQuery = q
                                Task { await vm.askAI() }
                            }
                            .font(DS.Font.sans(12))
                            .foregroundStyle(DS.Color.textSecond)
                            .padding(.horizontal, DS.Space.md)
                            .padding(.vertical, DS.Space.sm)
                            .background(DS.Color.surface2)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        }
                    }
                    .padding(.horizontal, DS.Space.lg)

                    // Input
                    @Bindable var bindVm = vm
                    HStack(alignment: .bottom, spacing: DS.Space.sm) {
                        TextField("Ask about ripples, timing, trends...", text: $bindVm.aiQuery, axis: .vertical)
                            .font(DS.Font.sans(14))
                            .foregroundStyle(DS.Color.textPrimary)
                            .tint(DS.Color.blue)
                            .lineLimit(4)
                            .focused($focused)
                            .padding(DS.Space.md)
                            .background(DS.Color.surface2)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                            .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).stroke(DS.Color.border, lineWidth: 1))

                        Button {
                            focused = false
                            Task { await vm.askAI() }
                        } label: {
                            Image(systemName: vm.aiLoading ? "arrow.triangle.2.circlepath" : "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundStyle(vm.aiQuery.isEmpty ? DS.Color.textDim : DS.Color.blue)
                        }
                        .disabled(vm.aiQuery.isEmpty || vm.aiLoading)
                    }
                    .padding(.horizontal, DS.Space.lg)

                    // Response
                    if !vm.aiResponse.isEmpty {
                        VStack(alignment: .leading, spacing: DS.Space.sm) {
                            SectionLabel(text: "Analysis")
                            Text(vm.aiResponse)
                                .font(DS.Font.sans(14))
                                .foregroundStyle(DS.Color.textPrimary)
                                .lineSpacing(4)
                        }
                        .padding(DS.Space.lg)
                        .background(DS.Color.blue.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(DS.Color.blue)
                                .frame(width: 3)
                        }
                        .padding(.horizontal, DS.Space.lg)
                    }

                    if vm.aiLoading {
                        HStack(spacing: DS.Space.sm) {
                            ProgressView().tint(DS.Color.blue)
                            Text("Analyzing market data...").font(DS.Font.sans(13)).foregroundStyle(DS.Color.textMuted)
                        }
                        .padding(.horizontal, DS.Space.lg)
                    }

                    Spacer(minLength: DS.Space.xxl)
                }
            }
        }
    }
}
```

---

## STEP 11 — FlowLayout + Array Safe Subscript

Add `Utilities.swift`:

```swift
import SwiftUI

// MARK: - Flow layout for chip buttons
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(proposal: proposal, subviews: subviews)
        let h = rows.map { $0.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0 }.reduce(0) { $0 + $1 + spacing }
        return CGSize(width: proposal.width ?? 0, height: max(0, h - spacing))
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(proposal: proposal, subviews: subviews) {
            var x = bounds.minX
            let rowH = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            for sv in row { let s = sv.sizeThatFits(.unspecified); sv.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s)); x += s.width + spacing }
            y += rowH + spacing
        }
    }
    private func rows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = [[]]
        var w: CGFloat = 0
        let maxW = proposal.width ?? .infinity
        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            if w + s.width > maxW, !rows.last!.isEmpty { rows.append([]); w = 0 }
            rows[rows.count - 1].append(sv); w += s.width + spacing
        }
        return rows
    }
}

// MARK: - Safe array subscript
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
```

---

## STEP 12 — TrendsView (placeholder for now)

```swift
// TrendsView.swift
import SwiftUI
import Charts

struct TrendsView: View {
    @Environment(StockPulseViewModel.self) private var vm

    var body: some View {
        ZStack {
            DS.Color.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.lg) {
                    HStack {
                        Text("Compare Trends")
                            .font(DS.Font.sans(20, weight: .bold))
                            .foregroundStyle(DS.Color.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, DS.Space.lg)
                    .padding(.top, DS.Space.lg)

                    ForEach(vm.catalysts) { catalyst in
                        SPCard {
                            VStack(alignment: .leading, spacing: DS.Space.sm) {
                                Text("\(catalyst.ticker) Ripple Network — \(catalyst.eventName)")
                                    .font(DS.Font.mono(12, weight: .bold))
                                    .foregroundStyle(DS.Color.orange)
                                Text("All lines = % change from May 4.")
                                    .font(DS.Font.mono(9))
                                    .foregroundStyle(DS.Color.textDim)

                                let tickers = [catalyst.ticker] + catalyst.ripples.map(\.ticker)
                                let series = MockDataStore.normalizedSeries(tickers: tickers)

                                Chart {
                                    RuleMark(y: .value("Zero", 0))
                                        .foregroundStyle(DS.Color.border2.opacity(0.5))
                                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                                    ForEach(catalyst.events) { event in
                                        if event.dateIndex < MockDataStore.dates.count {
                                            RuleMark(x: .value("Ev", MockDataStore.dates[event.dateIndex]))
                                                .foregroundStyle(Color(hex: event.color).opacity(0.5))
                                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
                                        }
                                    }

                                    ForEach(Array(series.enumerated()), id: \.offset) { idx, s in
                                        let c = DS.Color.chartLines[min(idx, DS.Color.chartLines.count - 1)]
                                        ForEach(Array(s.points.enumerated()), id: \.offset) { _, pt in
                                            LineMark(x: .value("D", pt.date), y: .value("P", pt.pct), series: .value("T", s.ticker))
                                                .foregroundStyle(c)
                                                .lineStyle(StrokeStyle(lineWidth: idx == 0 ? 2.5 : 1.5))
                                        }
                                    }
                                }
                                .chartYAxis { AxisMarks { v in
                                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(DS.Color.border)
                                    AxisValueLabel { if let d = v.as(Double.self) { Text("\(d >= 0 ? "+" : "")\(Int(d))%").font(DS.Font.mono(8)).foregroundStyle(DS.Color.textDim) } }
                                }}
                                .chartXAxis { AxisMarks(values: .stride(by: .day, count: 7)) { v in
                                    AxisValueLabel(format: .dateTime.month(.twoDigits).day(.twoDigits)).font(DS.Font.mono(8)).foregroundStyle(DS.Color.textDim)
                                }}
                                .frame(height: 200)
                                .chartBackground { _ in DS.Color.bg }

                                // Summary chips
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: DS.Space.sm) {
                                        ForEach(Array(tickers.enumerated()), id: \.offset) { idx, ticker in
                                            if let prices = MockDataStore.rawPrices[ticker],
                                               let first = prices.first, let last = prices.last, first > 0 {
                                                let chg = ((last - first) / first) * 100
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Rectangle()
                                                        .fill(DS.Color.chartLines[min(idx, DS.Color.chartLines.count - 1)])
                                                        .frame(height: 3)
                                                        .clipShape(Capsule())
                                                    Text(ticker).font(DS.Font.mono(11, weight: .bold)).foregroundStyle(DS.Color.textPrimary)
                                                    Text(String(format: "%+.1f%%", chg)).font(DS.Font.mono(10)).foregroundStyle(chg >= 0 ? DS.Color.green : DS.Color.red)
                                                }
                                                .padding(DS.Space.sm)
                                                .background(DS.Color.surface2)
                                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(DS.Space.lg)
                        }
                        .padding(.horizontal, DS.Space.lg)
                    }
                    Spacer(minLength: DS.Space.xxl)
                }
            }
        }
    }
}
```

---

## CRITICAL RULES FOR CURSOR

1. **NO NavigationStack anywhere.** Headers are built manually as HStack views. NavigationStack causes the large title black void bug.

2. **Every view's root is `ZStack { DS.Color.bg.ignoresSafeArea() ... }`** — this is what fills the black bars at top and bottom of the screen.

3. **TabView sits inside a ZStack with the bg color** — see RootView.swift.

4. **All data is available at vm init time.** `StockPulseViewModel()` calls `MockDataStore.watchItems()` and `MockDataStore.catalysts` inline in the property declarations. No async loading needed for Phase 1.

5. **IBM Plex Mono for all ticker text, prices, percentages, labels.** DM Sans for descriptions and AI response text.

6. **Colors come from DS.Color only.** Never use `.green`, `.blue`, `.orange` directly — always `DS.Color.green` etc. so the hex matches the JSX exactly.

7. **Do not use List.** Use `ScrollView` + `LazyVStack` for the watchlist. `List` adds unwanted insets and background tints that are hard to override.

8. **Do not use `.navigationBarTitleDisplayMode`.** There is no navigation bar. Titles are plain `Text` views in custom header HStacks.
