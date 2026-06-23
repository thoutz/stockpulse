import Foundation

// MARK: - API models

struct APIHealth: Decodable {
    let status: String
    let service: String
}

struct APIBar: Decodable {
    let date: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
}

struct APISnapshot: Decodable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let price: Double
    let change1dPct: Double
    let change30dPct: Double
    let change5mPct: Double?
    let change15mPct: Double?
    let rsi: Double?
    let sma20: Double?
    let quoteSource: String?
    let capturedAt: Date

    enum CodingKeys: String, CodingKey {
        case symbol, price
        case change1dPct = "change_1d_pct"
        case change30dPct = "change_30d_pct"
        case change5mPct = "change_5m_pct"
        case change15mPct = "change_15m_pct"
        case rsi
        case sma20 = "sma_20"
        case quoteSource = "quote_source"
        case capturedAt = "captured_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        symbol = try c.decode(String.self, forKey: .symbol)
        price = try c.decode(Double.self, forKey: .price)
        change1dPct = try c.decode(Double.self, forKey: .change1dPct)
        change30dPct = try c.decode(Double.self, forKey: .change30dPct)
        change5mPct = try c.decodeIfPresent(Double.self, forKey: .change5mPct)
        change15mPct = try c.decodeIfPresent(Double.self, forKey: .change15mPct)
        rsi = try c.decodeIfPresent(Double.self, forKey: .rsi)
        sma20 = try c.decodeIfPresent(Double.self, forKey: .sma20)
        quoteSource = try c.decodeIfPresent(String.self, forKey: .quoteSource)
        capturedAt = try c.decode(Date.self, forKey: .capturedAt)
    }
}

struct APIReport: Decodable, Identifiable {
    let id: Int
    let reportType: String
    let title: String
    let body: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case reportType = "report_type"
        case title, body
        case createdAt = "created_at"
    }
}

struct APISuggestion: Decodable, Identifiable {
    let id: Int
    let symbol: String
    let bias: String
    let summary: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, symbol, bias, summary
        case createdAt = "created_at"
    }
}

struct APIAlert: Decodable, Identifiable {
    let id: Int
    let symbol: String
    let alertType: String
    let message: String
    let changePct: Double
    let createdAt: Date
    let deliveredPush: Bool

    enum CodingKeys: String, CodingKey {
        case id, symbol
        case alertType = "alert_type"
        case message
        case changePct = "change_pct"
        case createdAt = "created_at"
        case deliveredPush = "delivered_push"
    }
}

struct APIChatRequest: Encodable {
    let prompt: String
    let selectedCatalystIndex: Int

    enum CodingKeys: String, CodingKey {
        case prompt
        case selectedCatalystIndex = "selected_catalyst_index"
    }
}

struct APIChatResponse: Decodable {
    let response: String
    let questionsRemaining: Int?

    enum CodingKeys: String, CodingKey {
        case response
        case questionsRemaining = "questions_remaining"
    }
}

struct APICatalogSector: Decodable {
    let id: String
    let name: String
    let description: String
    let tickers: [String]
    let accentHex: String

    enum CodingKeys: String, CodingKey {
        case id, name, description, tickers
        case accentHex = "accent_hex"
    }
}

struct APICatalogSectorsResponse: Decodable {
    let count: Int
    let sectors: [APICatalogSector]
}

struct APICatalogRipple: Decodable {
    let ticker: String
    let description: String
}

struct APICatalogCatalyst: Decodable {
    let id: Int?
    let ticker: String
    let name: String
    let eventName: String
    let eventDate: String
    let active: Bool
    let confidenceScore: Double?
    let source: String?
    let ripples: [APICatalogRipple]

    enum CodingKeys: String, CodingKey {
        case id, ticker, name, active, source, ripples
        case eventName = "event_name"
        case eventDate = "event_date"
        case confidenceScore = "confidence_score"
    }
}

struct APICatalogCatalystsResponse: Decodable {
    let count: Int
    let catalysts: [APICatalogCatalyst]
}

struct APIRippleResult: Decodable {
    let catalystTicker: String
    let rippleTicker: String
    let description: String
    let verdict: String
    let preEventPct: Double
    let postEventPct: Double

    enum CodingKeys: String, CodingKey {
        case catalystTicker = "catalyst_ticker"
        case rippleTicker = "ripple_ticker"
        case description
        case verdict
        case preEventPct = "pre_event_pct"
        case postEventPct = "post_event_pct"
    }
}

struct APIDashboard: Decodable {
    let snapshots: [APISnapshot]
    let histories: [String: [APIBar]]
    let historiesExtended: [String: [APIBar]]
    let rippleResults: [String: [APIRippleResult]]
    let dataAsOf: String?
    let stale: Bool
    let staleTickers: [String]
    let favorites: [String]

    enum CodingKeys: String, CodingKey {
        case snapshots, histories
        case historiesExtended = "histories_extended"
        case rippleResults = "ripple_results"
        case dataAsOf = "data_as_of"
        case stale
        case staleTickers = "stale_tickers"
        case favorites
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        snapshots = try c.decode([APISnapshot].self, forKey: .snapshots)
        histories = try c.decode([String: [APIBar]].self, forKey: .histories)
        historiesExtended = try c.decode([String: [APIBar]].self, forKey: .historiesExtended)
        rippleResults = try c.decode([String: [APIRippleResult]].self, forKey: .rippleResults)
        dataAsOf = try c.decodeIfPresent(String.self, forKey: .dataAsOf)
        stale = try c.decode(Bool.self, forKey: .stale)
        staleTickers = try c.decode([String].self, forKey: .staleTickers)
        favorites = try c.decodeIfPresent([String].self, forKey: .favorites) ?? []
    }
}

struct APITickerSearchResult: Decodable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let name: String
}

struct APIFavorite: Decodable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let name: String?
}

struct APIFavoriteList: Decodable {
    let favorites: [APIFavorite]
    let count: Int
    let limit: Int
}

struct APIMonitorSymbol: Decodable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let name: String?
    let tier: String
    let sectorId: String?
    let price: Double
    let change1dPct: Double
    let change5mPct: Double?
    let change15mPct: Double?
    let change30dPct: Double
    let rsi: Double?
    let sma20: Double?
    let quoteSource: String?
    let capturedAt: Date?
    let lagSeconds: Double?
    let isFavorite: Bool

    enum CodingKeys: String, CodingKey {
        case symbol, name, tier, price, rsi
        case sectorId = "sector_id"
        case change1dPct = "change_1d_pct"
        case change5mPct = "change_5m_pct"
        case change15mPct = "change_15m_pct"
        case change30dPct = "change_30d_pct"
        case sma20 = "sma_20"
        case quoteSource = "quote_source"
        case capturedAt = "captured_at"
        case lagSeconds = "lag_seconds"
        case isFavorite = "is_favorite"
    }
}

struct APIMonitorSector: Decodable, Identifiable {
    var id: String { sectorId }
    let sectorId: String
    let name: String
    let description: String
    let tickers: [String]
    let accentHex: String

    enum CodingKeys: String, CodingKey {
        case name, description, tickers
        case sectorId = "id"
        case accentHex = "accent_hex"
    }
}

struct APIMonitorPayload: Decodable {
    let focusSectorId: String?
    let favoriteCount: Int
    let favoriteLimit: Int
    let sectors: [APIMonitorSector]
    let hot: [APIMonitorSymbol]
    let warm: [APIMonitorSymbol]
    let cold: [APIMonitorSymbol]

    enum CodingKeys: String, CodingKey {
        case sectors, hot, warm, cold
        case focusSectorId = "focus_sector_id"
        case favoriteCount = "favorite_count"
        case favoriteLimit = "favorite_limit"
    }
}

struct APINewsItem: Decodable, Identifiable {
    var id: String { url }
    let symbol: String
    let headline: String
    let summary: String?
    let source: String?
    let url: String
    let publishedAt: Date
    let sentimentScore: Double?

    enum CodingKeys: String, CodingKey {
        case symbol, headline, summary, source, url
        case publishedAt = "published_at"
        case sentimentScore = "sentiment_score"
    }
}

// MARK: - Trading (Alpaca via server)

struct APIAutoTradeLastRun: Decodable {
    let at: Date
    let status: String
    let reason: String?
    let executed: Int?
    let skippedSymbols: [String]?

    enum CodingKeys: String, CodingKey {
        case at, status, reason, executed
        case skippedSymbols = "skipped_symbols"
    }
}

struct APIMicroTradeLastRun: Decodable {
    let at: Date
    let status: String
    let reason: String?
    let entries: Int?
    let exits: Int?
    let skippedSymbols: [String]?

    enum CodingKeys: String, CodingKey {
        case at, status, reason, entries, exits
        case skippedSymbols = "skipped_symbols"
    }
}

struct APITradingStatus: Decodable {
    let configured: Bool
    let connected: Bool
    let paper: Bool
    let accountMode: String?
    let tradingEnabled: Bool
    let autoTradeEnabled: Bool
    let fractionalTrading: Bool?
    let minFractionalNotional: Double?
    let accountStatus: String?
    let accountNumber: String?
    let needsPaperFunding: Bool?
    let message: String?
    let lastAutoTradeRun: APIAutoTradeLastRun?
    let nextAutoTradeRunAt: Date?
    let autoTradeScheduleEt: [String]?
    let lastMicroTradeRun: APIMicroTradeLastRun?
    let microTradeEnabled: Bool?
    let microScanIntervalMinutes: Int?
    let microTradeNotional: Double?
    let microTakeProfitPct: Double?
    let microStopLossPct: Double?
    let microDailyProfitCapUsd: Double?

    enum CodingKeys: String, CodingKey {
        case configured, connected, paper, message
        case accountMode = "account_mode"
        case tradingEnabled = "trading_enabled"
        case autoTradeEnabled = "auto_trade_enabled"
        case fractionalTrading = "fractional_trading"
        case minFractionalNotional = "min_fractional_notional"
        case accountStatus = "account_status"
        case accountNumber = "account_number"
        case needsPaperFunding = "needs_paper_funding"
        case lastAutoTradeRun = "last_auto_trade_run"
        case nextAutoTradeRunAt = "next_auto_trade_run_at"
        case autoTradeScheduleEt = "auto_trade_schedule_et"
        case lastMicroTradeRun = "last_micro_trade_run"
        case microTradeEnabled = "micro_trade_enabled"
        case microScanIntervalMinutes = "micro_scan_interval_minutes"
        case microTradeNotional = "micro_trade_notional"
        case microTakeProfitPct = "micro_take_profit_pct"
        case microStopLossPct = "micro_stop_loss_pct"
        case microDailyProfitCapUsd = "micro_daily_profit_cap_usd"
    }
}

struct APITradingAccount: Decodable {
    let equity: Double
    let cash: Double
    let buyingPower: Double
    let portfolioValue: Double
    let lastEquity: Double
    let dayPl: Double
    let dayPlPct: Double
    let status: String
    let currency: String
    let accountNumber: String?
    let needsPaperFunding: Bool?

    enum CodingKeys: String, CodingKey {
        case equity, cash, status, currency
        case buyingPower = "buying_power"
        case portfolioValue = "portfolio_value"
        case lastEquity = "last_equity"
        case dayPl = "day_pl"
        case dayPlPct = "day_pl_pct"
        case accountNumber = "account_number"
        case needsPaperFunding = "needs_paper_funding"
    }
}

struct APITradePosition: Decodable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let qty: Double
    let side: String
    let avgEntryPrice: Double
    let currentPrice: Double
    let marketValue: Double
    let unrealizedPl: Double
    let unrealizedPlpc: Double
    let isAuto: Bool?

    enum CodingKeys: String, CodingKey {
        case symbol, qty, side
        case avgEntryPrice = "avg_entry_price"
        case currentPrice = "current_price"
        case marketValue = "market_value"
        case unrealizedPl = "unrealized_pl"
        case unrealizedPlpc = "unrealized_plpc"
        case isAuto = "is_auto"
    }
}

struct APITradeActivity: Decodable, Identifiable {
    let id: String
    let activityType: String
    let symbol: String?
    let side: String?
    let qty: Double?
    let price: Double?
    let netAmount: Double?
    let transactionTime: Date?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id, symbol, side, qty, price, description
        case activityType = "activity_type"
        case netAmount = "net_amount"
        case transactionTime = "transaction_time"
    }
}

struct APITradeDecision: Decodable, Identifiable {
    let id: Int
    let symbol: String
    let action: String
    let confidence: Double
    let notionalUsd: Double
    let rationale: String
    let signalSource: String?
    let buyingSignalScore: Double?
    let alpacaOrderId: String?
    let status: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, symbol, action, confidence, rationale, status
        case notionalUsd = "notional_usd"
        case signalSource = "signal_source"
        case buyingSignalScore = "buying_signal_score"
        case alpacaOrderId = "alpaca_order_id"
        case createdAt = "created_at"
    }
}

struct APITradingDashboard: Decodable {
    let status: APITradingStatus
    let account: APITradingAccount?
    let positions: [APITradePosition]
    let activities: [APITradeActivity]
    let decisions: [APITradeDecision]
}

struct APITradeExecuteResponse: Decodable {
    let decision: APITradeDecision
    let order: APITradeOrder
}

struct APITradeOrder: Decodable {
    let id: String
    let symbol: String
    let side: String
    let status: String
    let notional: Double?
    let filledQty: Double?

    enum CodingKeys: String, CodingKey {
        case id, symbol, side, status, notional
        case filledQty = "filled_qty"
    }
}

// MARK: - Service

enum StockPulseAPIError: LocalizedError {
    case missingBaseURL
    case invalidURL
    case httpStatus(Int, String?)
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .missingBaseURL:
            return "Set STOCKPULSE_API_BASE_URL in Config.xcconfig (e.g. \"https://api.tryan.app\")."
        case .invalidURL:
            return "Invalid API URL."
        case .httpStatus(let code, let detail):
            if let detail, !detail.isEmpty { return detail }
            switch code {
            case 500, 502, 503:
                return "AI analysis temporarily unavailable. Try again shortly."
            default:
                return "Server error (HTTP \(code))."
            }
        case .decodeFailed:
            return "Could not parse server response."
        }
    }
}

actor StockPulseAPIService {
    static let shared = StockPulseAPIService()

    private var decoder: JSONDecoder { Self.makeDecoder() }

    private var baseURL: String {
        Self.normalizedBaseURL(from: Bundle.main.object(forInfoDictionaryKey: "STOCKPULSE_API_BASE_URL") as? String)
    }

    /// Strips whitespace, trailing slashes, and stray quotes from xcconfig/Info.plist values.
    private static func normalizedBaseURL(from raw: String?) -> String {
        var value = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("\"") { value.removeFirst() }
        if value.hasSuffix("\"") { value.removeLast() }
        return value.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func url(path: String) throws -> URL {
        guard !baseURL.isEmpty else { throw StockPulseAPIError.missingBaseURL }
        guard Self.isValidBaseURL(baseURL) else {
            throw StockPulseAPIError.missingBaseURL
        }
        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        guard let url = URL(string: normalizedPath, relativeTo: URL(string: baseURL + "/"))?.absoluteURL else {
            throw StockPulseAPIError.invalidURL
        }
        return url
    }

    /// Rejects xcconfig mistakes like `https:` (// treated as comment).
    private static func isValidBaseURL(_ value: String) -> Bool {
        guard let components = URLComponents(string: value),
              let host = components.host,
              !host.isEmpty,
              host.contains(".") || host == "localhost",
              components.scheme == "https" || components.scheme == "http" else {
            return false
        }
        return true
    }

    private func apiError(from data: Data, statusCode: Int) -> StockPulseAPIError {
        struct DetailBody: Decodable { let detail: String? }
        if let body = try? JSONDecoder().decode(DetailBody.self, from: data),
           let detail = body.detail, !detail.isEmpty {
            return .httpStatus(statusCode, detail)
        }
        return .httpStatus(statusCode, nil)
    }

    private func getData(_ path: String) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: try url(path: path))
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard http.statusCode == 200 else { throw apiError(from: data, statusCode: http.statusCode) }
        return data
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let data = try await getData(path)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw StockPulseAPIError.decodeFailed
        }
    }

    static var isConfigured: Bool {
        let trimmed = normalizedBaseURL(from: Bundle.main.object(forInfoDictionaryKey: "STOCKPULSE_API_BASE_URL") as? String)
        guard !trimmed.isEmpty else { return false }
        return isValidBaseURL(trimmed)
    }

    func health() async throws -> APIHealth {
        try await get("/api/health")
    }

    func snapshots() async throws -> [APISnapshot] {
        try await get("/api/snapshot")
    }

    func history(ticker: String, days: Int = 90) async throws -> [APIBar] {
        try await get("/api/history/\(ticker)?days=\(days)")
    }

    func histories(tickers: [String], days: Int = 365) async throws -> [String: [APIBar]] {
        struct HistoriesOut: Decodable {
            let histories: [String: [APIBar]]
        }
        let joined = tickers.map { $0.uppercased() }.joined(separator: ",")
        let encoded = joined.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? joined
        let out: HistoriesOut = try await get("/api/histories?tickers=\(encoded)&days=\(days)")
        return out.histories
    }

    func minuteBars(ticker: String, limit: Int = 500) async throws -> [APIBar] {
        let sym = ticker.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ticker
        return try await get("/api/minute/\(sym)?limit=\(limit)")
    }

    func digest(days: Int = 7) async throws -> APIDigest {
        let window = min(max(days, 1), 7)
        return try await get("/api/ai/digest?days=\(window)")
    }

    func reports(limit: Int = 20) async throws -> [APIReport] {
        try await get("/api/ai/reports?limit=\(limit)")
    }

    func suggestions(limit: Int = 30) async throws -> [APISuggestion] {
        try await get("/api/ai/suggestions?limit=\(limit)")
    }

    func alerts(limit: Int = 50) async throws -> [APIAlert] {
        let cap = min(max(limit, 1), 50)
        return try await get("/api/ai/alerts?limit=\(cap)")
    }

    func chatPrompts() async throws -> [String] {
        try await get("/api/ai/chat-prompts")
    }

    func chat(prompt: String, selectedCatalystIndex: Int) async throws -> String {
        let body = APIChatRequest(prompt: prompt, selectedCatalystIndex: selectedCatalystIndex)
        var request = URLRequest(url: try url(path: "/api/ai/chat"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard http.statusCode == 200 else { throw apiError(from: data, statusCode: http.statusCode) }
        let decoded = try decoder.decode(APIChatResponse.self, from: data)
        return decoded.response
    }

    func searchTickers(query: String) async throws -> [APITickerSearchResult] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
        return try await get("/api/search?q=\(encoded)")
    }

    func favorites() async throws -> APIFavoriteList {
        try await get("/api/favorites")
    }

    func fetchMonitor() async throws -> APIMonitorPayload {
        try await get("/api/monitor")
    }

    func fetchCatalogSectors() async throws -> APICatalogSectorsResponse {
        try await get("/api/catalog/sectors")
    }

    func fetchCatalogCatalysts() async throws -> APICatalogCatalystsResponse {
        try await get("/api/catalog/catalysts")
    }

    func setMonitorFocus(sectorId: String?) async throws -> APIMonitorPayload {
        struct Body: Encodable {
            let focusSectorId: String?
            enum CodingKeys: String, CodingKey {
                case focusSectorId = "focus_sector_id"
            }
        }
        var request = URLRequest(url: try url(path: "/api/monitor/focus"))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(Body(focusSectorId: sectorId))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard http.statusCode == 200 else { throw apiError(from: data, statusCode: http.statusCode) }
        return try decoder.decode(APIMonitorPayload.self, from: data)
    }

    @discardableResult
    func addFavorite(symbol: String, name: String?) async throws -> APIFavorite {
        struct Body: Encodable { let symbol: String; let name: String? }
        var request = URLRequest(url: try url(path: "/api/favorites"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(Body(symbol: symbol, name: name))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard http.statusCode == 200 else { throw apiError(from: data, statusCode: http.statusCode) }
        return try decoder.decode(APIFavorite.self, from: data)
    }

    func removeFavorite(symbol: String) async throws {
        let encoded = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
        var request = URLRequest(url: try url(path: "/api/favorites/\(encoded)"))
        request.httpMethod = "DELETE"
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard http.statusCode == 200 else { throw apiError(from: data, statusCode: http.statusCode) }
    }

    func news(symbols: [String], limit: Int = 6, hours: Int = 72) async throws -> [APINewsItem] {
        let joined = symbols.map { $0.uppercased() }.joined(separator: ",")
        let encoded = joined.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? joined
        let cap = min(max(limit, 1), 50)
        return try await get("/api/news?symbols=\(encoded)&limit=\(cap)&hours=\(hours)")
    }

    func fetchDashboardRaw() async throws -> Data {
        try await getData("/api/dashboard")
    }

    func dashboard() async throws -> APIDashboard {
        try await get("/api/dashboard")
    }

    nonisolated func decodeDashboard(_ data: Data) throws -> APIDashboard {
        try Self.makeDecoder().decode(APIDashboard.self, from: data)
    }

    nonisolated private static func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if container.decodeNil() {
                throw DecodingError.valueNotFound(Date.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Null date"))
            }
            let str = try container.decode(String.self)
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: str) { return date }
            iso.formatOptions = [.withInternetDateTime]
            if let date = iso.date(from: str) { return date }
            let formats = ["yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd"]
            for fmt in formats {
                let f = DateFormatter()
                f.locale = Locale(identifier: "en_US_POSIX")
                f.timeZone = TimeZone(secondsFromGMT: 0)
                f.dateFormat = fmt
                if let date = f.date(from: str) { return date }
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(str)")
        }
        return d
    }

    static func historyPoints(from bars: [APIBar]) -> [HistoryPoint] {
        bars.map {
            HistoryPoint(
                date: $0.date,
                open: $0.open,
                high: $0.high,
                low: $0.low,
                close: $0.close,
                volume: Int64($0.volume)
            )
        }
    }

    private var tradingSecret: String {
        let raw = Bundle.main.object(forInfoDictionaryKey: "TRADING_API_SECRET") as? String ?? ""
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func fetchTradingDashboard() async throws -> APITradingDashboard {
        try await get("/api/trading/dashboard")
    }

    func proposeTrades(symbol: String? = nil) async throws -> [APITradeDecision] {
        struct Body: Encodable { let symbol: String? }
        struct Out: Decodable { let proposals: [APITradeDecision] }
        var request = URLRequest(url: try url(path: "/api/trading/propose"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !tradingSecret.isEmpty {
            request.setValue(tradingSecret, forHTTPHeaderField: "X-Trading-Secret")
        }
        request.httpBody = try JSONEncoder().encode(Body(symbol: symbol))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard http.statusCode == 200 else { throw apiError(from: data, statusCode: http.statusCode) }
        return try decoder.decode(Out.self, from: data).proposals
    }

    func executeTradeDecision(id: Int) async throws -> APITradeExecuteResponse {
        var request = URLRequest(url: try url(path: "/api/trading/execute/\(id)"))
        request.httpMethod = "POST"
        if !tradingSecret.isEmpty {
            request.setValue(tradingSecret, forHTTPHeaderField: "X-Trading-Secret")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard http.statusCode == 200 else { throw apiError(from: data, statusCode: http.statusCode) }
        return try decoder.decode(APITradeExecuteResponse.self, from: data)
    }

    func closeTradePosition(symbol: String) async throws -> APITradeOrder {
        struct Out: Decodable { let order: APITradeOrder }
        let encoded = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
        var request = URLRequest(url: try url(path: "/api/trading/close/\(encoded)"))
        request.httpMethod = "POST"
        if !tradingSecret.isEmpty {
            request.setValue(tradingSecret, forHTTPHeaderField: "X-Trading-Secret")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard http.statusCode == 200 else { throw apiError(from: data, statusCode: http.statusCode) }
        return try decoder.decode(Out.self, from: data).order
    }
}
