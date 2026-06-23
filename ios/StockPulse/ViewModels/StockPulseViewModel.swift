import Foundation
import Observation

@Observable
class StockPulseViewModel {

    var catalysts: [Catalyst] = CatalystCatalog.catalysts
    var watchItems: [WatchItem] = CatalystCatalog.watchlistTickers.map {
        WatchItem(ticker: $0, history: [], rippleBadges: [])
    }
    var selectedCatalystIndex: Int = 0
    var isRefreshing = false
    var lastRefreshed: Date?
    var refreshError: String?
    var isCachedData = false
    var serverStale = false

    private var liveHistories: [String: [HistoryPoint]] = [:]
    private var liveRippleResults: [String: [RippleResult]] = [:]
    private var lastDataAsOf: String?

    // Server assistant feed
    var aiReports: [APIReport] = []
    var aiSuggestions: [APISuggestion] = []
    var aiChatPrompts: [String] = ChatPromptPicker.fallbackPrompts()
    var aiAlerts: [APIAlert] = []
    var aiDigestDays: [APIDigestDay] = []
    var digestRange: AIDigestRange = .oneDay
    var aiAnalysisSection: AIAnalysisSection = .reports
    var isAssistantSyncing = false
    var assistantError: String?
    var usesServerAPI = false

    // Trends chart range
    var trendRange: TrendChartRange = .thirtyDays
    var trendRangeLoading = false
    var trendRangeError: String?
    private var trendRangeFetched: [TrendChartRange: [String: [HistoryPoint]]] = [:]

    // Monitor symbol chart
    var monitorChartRange: TrendChartRange = .oneDay
    var monitorChartLoading = false
    var monitorChartError: String?
    private var monitorChartFetched: [String: [TrendChartRange: [HistoryPoint]]] = [:]
    private var monitorDailyCache: [String: [HistoryPoint]] = [:]

    var digestDaysInRange: [APIDigestDay] {
        let n = digestRange.rawValue
        let keys = DigestBuilder.lastNDayKeys(count: n)
        guard !aiDigestDays.isEmpty else {
            return keys.map {
                APIDigestDay(date: $0, reports: [], alerts: [], suggestions: [])
            }
        }
        let byDate = Dictionary(uniqueKeysWithValues: aiDigestDays.map { ($0.date, $0) })
        return keys.map { key in
            byDate[key] ?? APIDigestDay(date: key, reports: [], alerts: [], suggestions: [])
        }
    }

    var reportDaysInRange: [APIDigestDay] {
        if digestRange == .oneDay {
            let today = DigestBuilder.todayKey()
            let day = digestDaysInRange.first(where: { $0.date == today })
                ?? APIDigestDay(date: today, reports: [], alerts: [], suggestions: [])
            return [day]
        }
        return digestDaysInRange
            .reversed()
            .filter { day in
                day.reports.contains(where: ReportSessionSlot.isDisplayable)
            }
    }

    var reportSessionGroupsInRange: [ReportSessionGroup] {
        DigestBuilder.sessionGroups(for: digestDaysInRange)
    }

    var alertDaysInRange: [APIDigestDay] {
        digestDaysInRange
            .reversed()
            .filter { !$0.alerts.isEmpty }
    }

    var selectedCatalyst: Catalyst { catalysts[selectedCatalystIndex] }

    var currentRippleResults: [RippleResult] {
        liveRippleResults[selectedCatalyst.ticker] ?? []
    }

    var tickerTapeItems: [(ticker: String, price: Double, change1D: Double)] {
        watchItems.map { ($0.ticker, $0.currentPrice, $0.change1D) }
    }

    var chartSeries: [(ticker: String, points: [(date: Date, pct: Double)])] {
        chartSeries(for: selectedCatalyst)
    }

    func chartSeries(for catalyst: Catalyst) -> [(ticker: String, points: [(date: Date, pct: Double)])] {
        chartSeries(for: catalyst, range: trendRange)
    }

    func chartSeries(
        for catalyst: Catalyst,
        range: TrendChartRange
    ) -> [(ticker: String, points: [(date: Date, pct: Double)])] {
        let tickers = [catalyst.ticker] + catalyst.ripples.map(\.ticker)
        let fetched = trendRangeFetched[range] ?? [:]
        var barsByTicker: [String: [HistoryPoint]] = [:]
        for ticker in tickers {
            barsByTicker[ticker] = TrendRangeHelper.bars(
                ticker: ticker,
                range: range,
                liveHistories: liveHistories,
                fetchedHistories: fetched
            )
        }
        let aligned = TrendRangeHelper.align(tickers: tickers, barsByTicker: barsByTicker)
        return LiveDataBridge.normalizedSeries(tickers: tickers, histories: aligned)
    }

    func periodChangePct(ticker: String, range: TrendChartRange? = nil) -> Double? {
        let activeRange = range ?? trendRange
        let fetched = trendRangeFetched[activeRange] ?? [:]
        let bars = TrendRangeHelper.bars(
            ticker: ticker,
            range: activeRange,
            liveHistories: liveHistories,
            fetchedHistories: fetched
        )
        return LiveDataBridge.periodChangePct(ticker: ticker, histories: [ticker: bars])
    }

    @MainActor
    func loadTrendRangeIfNeeded() async {
        guard trendRange.needsRemoteFetch else {
            trendRangeError = nil
            return
        }
        if trendRangeFetched[trendRange] != nil {
            trendRangeError = nil
            return
        }
        guard StockPulseAPIService.isConfigured else {
            trendRangeError = "Connect STOCKPULSE_API_BASE_URL for \(trendRange.label) charts."
            return
        }

        trendRangeLoading = true
        trendRangeError = nil
        defer { trendRangeLoading = false }

        do {
            let tickers = TrendChartRange.allTrendTickers
            if trendRange == .oneDay {
                var out: [String: [HistoryPoint]] = [:]
                for ticker in tickers {
                    let bars = try await StockPulseAPIService.shared.minuteBars(ticker: ticker)
                    out[ticker] = StockPulseAPIService.historyPoints(from: bars)
                }
                trendRangeFetched[.oneDay] = out
            } else if trendRange == .oneYear {
                let raw = try await StockPulseAPIService.shared.histories(tickers: tickers, days: 365)
                var out: [String: [HistoryPoint]] = [:]
                for (ticker, bars) in raw {
                    out[ticker] = StockPulseAPIService.historyPoints(from: bars)
                }
                trendRangeFetched[.oneYear] = out
            }
        } catch {
            trendRangeError = error.localizedDescription
        }
    }

    func monitorChartBars(symbol: String) -> [HistoryPoint] {
        let sym = symbol.uppercased()
        let daily = monitorDailyCache[sym] ?? liveHistories[sym]
        let minute = monitorChartFetched[sym]?[.oneDay]
        return MonitorChartHelper.bars(
            range: monitorChartRange,
            dailyHistory: daily,
            minuteHistory: minute
        )
    }

    func monitorChartPeriodChange(symbol: String) -> Double? {
        let bars = monitorChartBars(symbol: symbol)
        guard let first = bars.first?.close,
              let last = bars.last?.close else { return nil }
        return LiveDataBridge.changePct(from: first, to: last)
    }

    @MainActor
    func loadMonitorChart(symbol: String) async {
        let sym = symbol.uppercased()

        if !StockPulseAPIService.isConfigured {
            if monitorDailyCache[sym] == nil, let live = liveHistories[sym] {
                monitorDailyCache[sym] = live
            }
            monitorChartError = monitorChartRange == .oneDay
                ? "Connect STOCKPULSE_API_BASE_URL for \(monitorChartRange.label) charts."
                : nil
            return
        }

        monitorChartLoading = true
        monitorChartError = nil
        defer { monitorChartLoading = false }

        do {
            if monitorDailyCache[sym] == nil {
                let bars = try await StockPulseAPIService.shared.history(ticker: sym, days: 365)
                monitorDailyCache[sym] = StockPulseAPIService.historyPoints(from: bars)
            }

            if monitorChartRange == .oneDay, monitorChartFetched[sym]?[.oneDay] == nil {
                let bars = try await StockPulseAPIService.shared.minuteBars(ticker: sym)
                if monitorChartFetched[sym] == nil { monitorChartFetched[sym] = [:] }
                monitorChartFetched[sym]?[.oneDay] = StockPulseAPIService.historyPoints(from: bars)
            }
        } catch {
            monitorChartError = error.localizedDescription
            if monitorDailyCache[sym] == nil, let live = liveHistories[sym] {
                monitorDailyCache[sym] = live
            }
        }
    }

    func clearMonitorChartCache(symbol: String?) {
        guard let symbol else { return }
        let sym = symbol.uppercased()
        monitorChartFetched.removeValue(forKey: sym)
        monitorDailyCache.removeValue(forKey: sym)
    }

    var aiQuery = ""
    var aiResponse = ""
    var aiResponseGeneratedAt: Date?
    var aiLoading = false

    // Analyst tab (brief sections)
    var selectedTab: AppTab = .pulse
    var focusedTicker: String?
    var industrySnapshots: [IndustrySnapshot] = []
    var indexSnapshots: [IndexSnapshot] = []
    var marketWhatsNewBrief: MarketBrief?
    var marketResearchBrief: MarketBrief?
    var marketLoading = false
    var selectedMarketDetail: MarketDetailSelection?
    var marketNews: [NewsArticle] = []
    var marketIndustryNews: [NewsArticle] = []
    var marketNewsLoading = false
    var marketNewsUpdatedAt: Date?
    private var marketBriefGeneratedForRefresh: Date?
    private var marketNewsRefreshTask: Task<Void, Never>?
    private static let marketNewsRefreshInterval: TimeInterval = 15 * 60
    private static let marketBriefCacheTTL: TimeInterval = 24 * 3600
    private static let alertsDisplayLimit = 50

    private func friendlyNetworkError(_ error: Error) -> String {
        if let urlError = error as? URLError, urlError.code == .secureConnectionFailed {
            return "Office network may be blocking api.tryan.app — try cellular or ask IT to whitelist."
        }
        if let apiError = error as? StockPulseAPIError {
            return apiError.localizedDescription
        }
        return error.localizedDescription
    }

    // Search + favorites
    var searchQuery = ""
    var searchResults: [APITickerSearchResult] = []
    var searchLoading = false
    var searchError: String?
    var favoriteSymbols: [String] = []
    var favoriteCount = 0
    var favoriteLimit = 20
    var monitorFocusSectorId: String?
    var monitorHot: [MonitorSymbolRow] = []
    var monitorWarm: [MonitorSymbolRow] = []
    var monitorCold: [MonitorSymbolRow] = []
    var monitorSyncError: String?
    private var searchTask: Task<Void, Never>?
    private var monitorPollTask: Task<Void, Never>?

    // Trade tab (Alpaca)
    var tradingStatus: APITradingStatus?
    var tradingAccount: APITradingAccount?
    var tradePositions: [APITradePosition] = []
    var tradeActivities: [APITradeActivity] = []
    var tradeDecisions: [APITradeDecision] = []
    var tradeLoading = false
    var tradeActionLoading = false
    var tradeError: String?
    private var tradePollTask: Task<Void, Never>?

    var canExecuteTrades: Bool {
        tradingStatus?.connected == true && tradingStatus?.tradingEnabled == true
    }

    var usesLiveData: Bool { !liveHistories.isEmpty }

    var dataThroughLabel: String {
        if let asOf = lastDataAsOf, !asOf.isEmpty {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: asOf) ?? ISO8601DateFormatter().date(from: asOf) {
                let display = DateFormatter()
                display.dateFormat = "MMM dd, yyyy"
                display.timeZone = TimeZone.current
                return display.string(from: date)
            }
            return String(asOf.prefix(10))
        }
        guard let last = lastRefreshed else { return usesLiveData ? "—" : "Not loaded" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: last)
    }

    var dataStatusLabel: String {
        if isRefreshing { return "UPDATING" }
        if usesServerAPI {
            if isCachedData && !usesLiveData { return "CACHED" }
            return usesLiveData ? "SERVER" : "OFFLINE"
        }
        return usesLiveData ? "LIVE" : "OFFLINE"
    }

    func predictionHint(for ticker: String) -> String? {
        aiSuggestions.first { $0.symbol == ticker }?.summary
    }

    func postEventPct(for catalyst: Catalyst) -> Double? {
        guard let history = liveHistories[catalyst.ticker] else { return nil }
        return RippleEngine.postEventChange(history: history, eventDate: catalyst.eventDate)
    }

    func sparklinePoints(ticker: String) -> [(date: Date, pct: Double)] {
        LiveDataBridge.sparklinePoints(ticker: ticker, histories: liveHistories)
    }

    func marketSparkline(ticker: String) -> [(date: Date, pct: Double)] {
        sparklinePoints(ticker: ticker)
    }

    func industrySnapshot(for ticker: String) -> IndustrySnapshot? {
        industrySnapshots.first { snap in
            snap.constituents.contains { $0.ticker == ticker.uppercased() }
        }
    }

    func indexSnapshot(for indexId: String) -> IndexSnapshot? {
        indexSnapshots.first { $0.id == indexId }
    }

    func rippleBadges(for ticker: String) -> [(catalystTicker: String, verdict: RippleVerdict)] {
        watchItems.first { $0.ticker == ticker.uppercased() }?.rippleBadges ?? []
    }

    @MainActor
    func selectMarketTicker(_ ticker: String) {
        let sym = ticker.uppercased()
        selectedMarketDetail = .ticker(sym)
        Task { await loadMarketNews(for: sym) }
        startMarketNewsRefreshLoop()
    }

    @MainActor
    func selectMarketIndex(_ indexId: String) {
        selectedMarketDetail = .index(indexId)
        guard let ticker = IndustryCatalog.indices.first(where: { $0.id == indexId })?.ticker else { return }
        Task { await loadMarketNews(for: ticker, industryPeers: []) }
        startMarketNewsRefreshLoop()
    }

    @MainActor
    func clearMarketSelection() {
        selectedMarketDetail = nil
        marketNews = []
        marketIndustryNews = []
        marketNewsUpdatedAt = nil
        marketNewsRefreshTask?.cancel()
        marketNewsRefreshTask = nil
    }

    @MainActor
    func loadMarketNews(for ticker: String, industryPeers: [String]? = nil, force: Bool = false) async {
        let sym = ticker.uppercased()
        marketNewsLoading = true
        defer { marketNewsLoading = false }

        let peers: [String]
        if let industryPeers {
            peers = industryPeers
        } else if let industry = IndustryCatalog.industry(for: sym) {
            peers = industry.tickers.filter { $0 != sym }
        } else {
            peers = []
        }

        async let tickerNews = NewsService.shared.fetchNews(symbol: sym, limit: 5, force: force)
        async let groupNews = peers.isEmpty
            ? [] as [NewsArticle]
            : NewsService.shared.fetchNews(symbols: Array(peers.prefix(3)), limit: 4, force: force)

        marketNews = await tickerNews
        let peerArticles = await groupNews
        marketIndustryNews = peerArticles.filter { $0.symbol != sym }
        marketNewsUpdatedAt = Date()
    }

    @MainActor
    private func startMarketNewsRefreshLoop() {
        marketNewsRefreshTask?.cancel()
        marketNewsRefreshTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Self.marketNewsRefreshInterval * 1_000_000_000))
                guard !Task.isCancelled, let detail = selectedMarketDetail else { return }
                switch detail {
                case .ticker(let sym):
                    await loadMarketNews(for: sym, force: true)
                case .index(let id):
                    if let ticker = IndustryCatalog.indices.first(where: { $0.id == id })?.ticker {
                        await loadMarketNews(for: ticker, industryPeers: [], force: true)
                    }
                }
            }
        }
    }

    func focusTicker(_ ticker: String, tab: AppTab = .watchlist) {
        focusedTicker = ticker.uppercased()
        selectedTab = tab
    }

    func isFavorite(_ symbol: String) -> Bool {
        favoriteSymbols.contains(symbol.uppercased())
    }

    var isAtFavoriteLimit: Bool { favoriteCount >= favoriteLimit }

    @MainActor
    func syncMonitor(force: Bool = false) async {
        guard StockPulseAPIService.isConfigured else { return }
        do {
            let payload = try await StockPulseAPIService.shared.fetchMonitor()
            applyMonitorPayload(payload)
            monitorSyncError = nil
        } catch {
            if force {
                monitorSyncError = error.localizedDescription
            }
        }
    }

    @MainActor
    func setMonitorFocus(sectorId: String?) async {
        guard StockPulseAPIService.isConfigured else { return }
        do {
            let payload = try await StockPulseAPIService.shared.setMonitorFocus(sectorId: sectorId)
            applyMonitorPayload(payload)
            monitorSyncError = nil
        } catch {
            monitorSyncError = error.localizedDescription
        }
    }

    @MainActor
    func startMonitorPolling() {
        monitorPollTask?.cancel()
        monitorPollTask = Task { @MainActor in
            while !Task.isCancelled {
                await syncMonitor()
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    @MainActor
    func stopMonitorPolling() {
        monitorPollTask?.cancel()
        monitorPollTask = nil
    }

    @MainActor
    func refreshTradeTab() async {
        guard StockPulseAPIService.isConfigured else {
            tradeError = "Set STOCKPULSE_API_BASE_URL in Config.xcconfig"
            return
        }
        tradeLoading = true
        tradeError = nil
        defer { tradeLoading = false }
        do {
            let dash = try await StockPulseAPIService.shared.fetchTradingDashboard()
            tradingStatus = dash.status
            tradingAccount = dash.account
            tradePositions = dash.positions
            tradeActivities = dash.activities
            tradeDecisions = dash.decisions
        } catch {
            tradeError = friendlyNetworkError(error)
        }
    }

    @MainActor
    func startTradePolling() {
        tradePollTask?.cancel()
        tradePollTask = Task { @MainActor in
            while !Task.isCancelled {
                await refreshTradeTab()
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    @MainActor
    func stopTradePolling() {
        tradePollTask?.cancel()
        tradePollTask = nil
    }

    @MainActor
    func scanTradeProposals() async {
        tradeActionLoading = true
        defer { tradeActionLoading = false }
        do {
            _ = try await StockPulseAPIService.shared.proposeTrades()
            await refreshTradeTab()
        } catch {
            tradeError = friendlyNetworkError(error)
        }
    }

    @MainActor
    func executeTradeProposal(_ id: Int) async {
        tradeActionLoading = true
        defer { tradeActionLoading = false }
        do {
            _ = try await StockPulseAPIService.shared.executeTradeDecision(id: id)
            await refreshTradeTab()
        } catch {
            tradeError = friendlyNetworkError(error)
        }
    }

    @MainActor
    func closeTradePosition(_ symbol: String) async {
        tradeActionLoading = true
        defer { tradeActionLoading = false }
        do {
            _ = try await StockPulseAPIService.shared.closeTradePosition(symbol: symbol)
            await refreshTradeTab()
        } catch {
            tradeError = friendlyNetworkError(error)
        }
    }

    @MainActor
    private func applyMonitorPayload(_ payload: APIMonitorPayload) {
        monitorFocusSectorId = payload.focusSectorId
        favoriteCount = payload.favoriteCount
        favoriteLimit = payload.favoriteLimit
        monitorHot = payload.hot.map { mapMonitorSymbol($0) }
        monitorWarm = payload.warm.map { mapMonitorSymbol($0) }
        monitorCold = payload.cold.map { mapMonitorSymbol($0) }
        rebuildWatchItemsFromMonitor()
    }

    private func mapMonitorSymbol(_ row: APIMonitorSymbol) -> MonitorSymbolRow {
        MonitorSymbolRow(
            id: row.symbol,
            symbol: row.symbol,
            name: row.name ?? IndustryCatalog.displayName(for: row.symbol),
            tier: MonitorTier(rawValue: row.tier) ?? .warm,
            sectorId: row.sectorId,
            price: row.price,
            change1D: row.change1dPct,
            change5M: row.change5mPct,
            change30D: row.change30dPct,
            lastUpdated: row.capturedAt,
            lagSeconds: row.lagSeconds,
            isFavorite: row.isFavorite
        )
    }

    @MainActor
    private func rebuildWatchItemsFromMonitor() {
        let ordered = monitorHot + monitorWarm + monitorCold
        guard !ordered.isEmpty else { return }
        watchItems = ordered.map { row in
            let history = liveHistories[row.symbol].map { pts in
                pts.map { PricePoint(date: $0.date, close: $0.close) }
            } ?? []
            let badges = rippleBadgesFromResults(for: row.symbol)
            if history.isEmpty {
                return WatchItem(
                    ticker: row.symbol,
                    history: row.price > 0
                        ? [PricePoint(date: row.lastUpdated ?? Date(), close: row.price)]
                        : [],
                    rippleBadges: badges
                )
            }
            return WatchItem(ticker: row.symbol, history: history, rippleBadges: badges)
        }
    }

    private func rippleBadgesFromResults(for ticker: String) -> [(catalystTicker: String, verdict: RippleVerdict)] {
        let sym = ticker.uppercased()
        var badges: [(String, RippleVerdict)] = []
        for (catalyst, results) in liveRippleResults {
            if let match = results.first(where: { $0.rippleTicker == sym }) {
                badges.append((catalyst, match.verdict))
            }
        }
        return badges
    }

    /// Debounced server search; cancels any in-flight query.
    @MainActor
    func performSearch() {
        searchTask?.cancel()
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 1 else {
            searchResults = []
            searchLoading = false
            searchError = nil
            return
        }
        guard StockPulseAPIService.isConfigured else {
            searchError = "Search needs STOCKPULSE_API_BASE_URL configured."
            return
        }
        searchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            searchLoading = true
            searchError = nil
            defer { searchLoading = false }
            do {
                let results = try await StockPulseAPIService.shared.searchTickers(query: query)
                if Task.isCancelled { return }
                searchResults = results
            } catch {
                if Task.isCancelled { return }
                searchError = error.localizedDescription
                searchResults = []
            }
        }
    }

    @MainActor
    func addFavorite(symbol: String, name: String?) async {
        guard StockPulseAPIService.isConfigured else { return }
        let sym = symbol.uppercased()
        do {
            try await StockPulseAPIService.shared.addFavorite(symbol: sym, name: name)
            if !favoriteSymbols.contains(sym) { favoriteSymbols.append(sym) }
            favoriteCount = min(favoriteCount + 1, favoriteLimit)
            await refresh()
            await syncMonitor(force: true)
        } catch let error as StockPulseAPIError {
            if case .httpStatus(409, _) = error {
                refreshError = "Favorite limit reached (\(favoriteLimit)). Remove one to add another."
            } else {
                refreshError = "Could not add \(sym): \(error.localizedDescription)"
            }
        } catch {
            refreshError = "Could not add \(sym): \(error.localizedDescription)"
        }
    }

    @MainActor
    func removeFavorite(symbol: String) async {
        guard StockPulseAPIService.isConfigured else { return }
        let sym = symbol.uppercased()
        do {
            try await StockPulseAPIService.shared.removeFavorite(symbol: sym)
            favoriteSymbols.removeAll { $0 == sym }
            favoriteCount = max(0, favoriteCount - 1)
            await refresh()
            await syncMonitor(force: true)
        } catch {
            refreshError = "Could not remove \(sym): \(error.localizedDescription)"
        }
    }

    @MainActor
    func loadFromCacheIfAvailable() {
        if let cached = MarketBriefStore.load() {
            marketWhatsNewBrief = cached
        } else if let brief = marketWhatsNewBrief, MarketBriefStore.isErrorBrief(brief.text) {
            marketWhatsNewBrief = nil
            MarketBriefStore.clear()
        }
        guard StockPulseAPIService.isConfigured,
              let data = MarketDataCache.load() else { return }
        do {
            let dashboard = try StockPulseAPIService.shared.decodeDashboard(data)
            applyDashboard(dashboard, fromCache: true)
        } catch {
            MarketDataCache.clear()
        }
    }

    /// Manual refresh on Analyst tab: fetch latest prices and sync pulse brief (no Groq).
    @MainActor
    func refreshMarketTab() async {
        await refresh()
        if usesServerAPI {
            await syncAssistantFeed()
        }
        await generateMarketBrief(force: true)
        if let detail = selectedMarketDetail {
            switch detail {
            case .ticker(let sym):
                await loadMarketNews(for: sym, force: true)
            case .index(let id):
                if let ticker = IndustryCatalog.indices.first(where: { $0.id == id })?.ticker {
                    await loadMarketNews(for: ticker, industryPeers: [], force: true)
                }
            }
        }
    }

    @MainActor
    func generateMarketBrief(force: Bool = false) async {
        if !force {
            guard usesLiveData else { return }
            guard !marketLoading else { return }
            if let brief = marketWhatsNewBrief, !MarketBriefStore.isErrorBrief(brief.text) {
                if marketBriefGeneratedForRefresh == lastRefreshed { return }
                if Date().timeIntervalSince(brief.generatedAt) < Self.marketBriefCacheTTL { return }
            }
        } else if !usesLiveData {
            marketWhatsNewBrief = MarketBrief(
                text: "Market data is not loaded yet. Check your connection and try again.",
                generatedAt: Date()
            )
            return
        }

        guard !marketLoading || force else { return }

        marketLoading = true
        defer { marketLoading = false }

        if force {
            marketBriefGeneratedForRefresh = nil
        }

        if usesServerAPI {
            applyServerPulseMarketBrief(force: force)
            return
        }

        guard AIAnalystService.hasGroqKey else {
            marketWhatsNewBrief = MarketBrief(
                text: "Add GROQ_API_KEY in ios/Config.xcconfig, or configure STOCKPULSE_API_BASE_URL to use server AI.",
                generatedAt: Date()
            )
            return
        }

        let input = MarketBriefInput(
            industrySnapshots: industrySnapshots,
            indexSnapshots: indexSnapshots,
            lastRefreshed: lastRefreshed,
            rippleResultsByCatalyst: liveRippleResults
        )
        let context = MarketBriefContextBuilder.build(from: input)

        do {
            let text = try await AIAnalystService.shared.query(
                prompt: MarketBriefContextBuilder.defaultPrompt,
                context: context
            )
            let brief = MarketBrief(text: text, generatedAt: Date())
            marketWhatsNewBrief = brief
            marketResearchBrief = brief
            marketBriefGeneratedForRefresh = lastRefreshed
            MarketBriefStore.save(brief)
        } catch {
            if force || marketWhatsNewBrief == nil || MarketBriefStore.isErrorBrief(marketWhatsNewBrief?.text ?? "") {
                marketWhatsNewBrief = MarketBrief(
                    text: "Could not generate market brief: \(error.localizedDescription)",
                    generatedAt: Date()
                )
            }
        }
    }

    private func latestPulseOpenReport() -> APIReport? {
        aiReports
            .filter { $0.reportType == "pulse_open" }
            .max(by: { $0.createdAt < $1.createdAt })
    }

    private func latestPulseReport() -> APIReport? {
        aiReports
            .filter { $0.reportType.hasPrefix("pulse") }
            .max(by: { $0.createdAt < $1.createdAt })
    }

    /// Server mode: What's New from pulse_open; Research Watchlist from latest pulse.
    private func applyServerPulseMarketBrief(force: Bool) {
        if !force,
           let brief = marketWhatsNewBrief,
           !MarketBriefStore.isErrorBrief(brief.text),
           Date().timeIntervalSince(brief.generatedAt) < Self.marketBriefCacheTTL {
            if latestPulseReport() != nil {
                applyResearchFromLatestPulse()
            }
            marketBriefGeneratedForRefresh = lastRefreshed
            return
        }
        if let open = latestPulseOpenReport() {
            applyWhatsNewReport(open)
            marketBriefGeneratedForRefresh = lastRefreshed
        } else if let pulse = latestPulseReport() {
            applyWhatsNewReport(pulse)
            marketBriefGeneratedForRefresh = lastRefreshed
        } else if let cached = MarketBriefStore.load(), !MarketBriefStore.isErrorBrief(cached.text) {
            marketWhatsNewBrief = cached
            marketBriefGeneratedForRefresh = lastRefreshed
        } else {
            marketWhatsNewBrief = MarketBrief(
                text: "Market brief will appear after the 10:00 AM ET pulse report on trading days.",
                generatedAt: Date()
            )
        }
        applyResearchFromLatestPulse()
    }

    private func applyResearchFromLatestPulse() {
        guard let pulse = latestPulseReport() else { return }
        applyResearchReport(pulse)
    }

    /// Prefer server pulse or cached brief instead of showing a raw HTTP error.
    private func applyMarketBriefFallback(after error: Error, force: Bool) {
        if let open = latestPulseOpenReport() {
            applyWhatsNewReport(open)
        } else if let pulse = latestPulseReport() {
            applyWhatsNewReport(pulse)
        } else if let cached = MarketBriefStore.load(), !MarketBriefStore.isErrorBrief(cached.text) {
            marketWhatsNewBrief = cached
        }
        applyResearchFromLatestPulse()
        if !force,
           let brief = marketWhatsNewBrief,
           !MarketBriefStore.isErrorBrief(brief.text) {
            return
        }
        let networkHint = (error as? URLError)?.code == .notConnectedToInternet
            ? "Check your connection"
            : error.localizedDescription
        marketWhatsNewBrief = MarketBrief(
            text: "Market brief unavailable (\(networkHint)). Pull down again when you have a stable connection.",
            generatedAt: Date()
        )
    }

    private func reportBodyText(_ report: APIReport) -> String {
        report.title.isEmpty ? report.body : "\(report.title)\n\n\(report.body)"
    }

    private func applyWhatsNewReport(_ report: APIReport) {
        let brief = MarketBrief(text: reportBodyText(report), generatedAt: report.createdAt)
        marketWhatsNewBrief = brief
        MarketBriefStore.save(brief)
    }

    private func applyResearchReport(_ report: APIReport) {
        marketResearchBrief = MarketBrief(text: report.body, generatedAt: report.createdAt)
    }

    private func applyPulseReportToMarketBriefIfNewer() {
        if let open = latestPulseOpenReport() {
            if marketWhatsNewBrief == nil
                || MarketBriefStore.isErrorBrief(marketWhatsNewBrief?.text ?? "")
                || open.createdAt > (marketWhatsNewBrief?.generatedAt ?? .distantPast) {
                applyWhatsNewReport(open)
            }
        }
        if let pulse = latestPulseReport() {
            if marketResearchBrief == nil
                || pulse.createdAt > (marketResearchBrief?.generatedAt ?? .distantPast) {
                applyResearchReport(pulse)
            }
        }
        marketBriefGeneratedForRefresh = lastRefreshed
    }

    @MainActor
    func clearAIChat() {
        aiQuery = ""
        aiResponse = ""
        aiResponseGeneratedAt = nil
    }

    @MainActor
    func askAI() async {
        let prompt = aiQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        aiQuery = ""
        aiLoading = true
        aiResponse = ""
        aiResponseGeneratedAt = nil
        defer { aiLoading = false }

        guard usesServerAPI else {
            guard usesLiveData else {
                aiResponse = "Configure STOCKPULSE_API_BASE_URL for server AI, or load local data."
                return
            }
            do {
                let appContext = AIAppContext(
                    histories: liveHistories,
                    watchItems: watchItems,
                    catalysts: catalysts,
                    rippleResultsByCatalyst: liveRippleResults,
                    selectedCatalystIndex: selectedCatalystIndex,
                    lastRefreshed: lastRefreshed,
                    futureTickers: CatalystCatalog.futureTickers
                )
                let context = await AIAnalystService.shared.buildContext(from: appContext)
                aiResponse = try await AIAnalystService.shared.query(prompt: prompt, context: context)
                aiResponseGeneratedAt = Date()
            } catch {
                aiResponse = "Error: \(error.localizedDescription)"
            }
            return
        }

        do {
            aiResponse = try await StockPulseAPIService.shared.chat(
                prompt: prompt,
                selectedCatalystIndex: selectedCatalystIndex
            )
            aiResponseGeneratedAt = Date()
        } catch {
            aiResponse = "Server AI error: \(error.localizedDescription)"
        }
    }

    @MainActor
    func syncChatPrompts() async {
        if usesServerAPI {
            do {
                let prompts = try await StockPulseAPIService.shared.chatPrompts()
                if prompts.count >= 4 {
                    aiChatPrompts = Array(prompts.prefix(4))
                    return
                }
            } catch {
                // Fall through to local fallback.
            }
        }
        aiChatPrompts = ChatPromptPicker.fallbackPrompts()
    }

    @MainActor
    func syncAssistantFeed() async {
        guard usesServerAPI else {
            await syncChatPrompts()
            return
        }
        isAssistantSyncing = true
        assistantError = nil
        defer { isAssistantSyncing = false }
        await syncChatPrompts()
        do {
            let digest = try await StockPulseAPIService.shared.digest(days: 7)
            applyDigest(digest)
        } catch {
            do {
                async let reports = StockPulseAPIService.shared.reports(limit: 50)
                async let suggestions = StockPulseAPIService.shared.suggestions(limit: 50)
                async let alerts = StockPulseAPIService.shared.alerts(limit: Self.alertsDisplayLimit)
                aiReports = try await reports
                aiSuggestions = try await suggestions
                aiAlerts = try await alerts
                aiDigestDays = DigestBuilder.build(
                    reports: aiReports,
                    alerts: aiAlerts,
                    suggestions: aiSuggestions,
                    days: 7
                )
                applyPulseReportToMarketBriefIfNewer()
            } catch {
                assistantError = friendlyNetworkError(error)
            }
        }
    }

    private func applyDigest(_ digest: APIDigest) {
        let allReports = digest.days.flatMap(\.reports)
        let allAlerts = digest.days.flatMap(\.alerts)
        let allSuggestions = digest.days.flatMap(\.suggestions)
        aiReports = allReports.sorted { $0.createdAt > $1.createdAt }
        aiAlerts = Array(allAlerts.sorted { $0.createdAt > $1.createdAt }.prefix(Self.alertsDisplayLimit))
        aiSuggestions = allSuggestions.sorted { $0.createdAt > $1.createdAt }
        // Re-bucket by US/Eastern so "today" matches the Watchlist labels.
        aiDigestDays = DigestBuilder.build(
            reports: aiReports,
            alerts: aiAlerts,
            suggestions: aiSuggestions,
            days: 7
        )
        applyPulseReportToMarketBriefIfNewer()
    }

    /// Full dashboard fetch (pull-to-refresh, launch).
    @MainActor
    func refresh() async {
        usesServerAPI = StockPulseAPIService.isConfigured
        guard usesServerAPI else {
            await refreshFromLocalMassive()
            return
        }
        isRefreshing = true
        refreshError = nil
        defer { isRefreshing = false }

        do {
            await AppCatalog.shared.syncFromServer()
            catalysts = AppCatalog.shared.catalysts
            if selectedCatalystIndex >= catalysts.count {
                selectedCatalystIndex = max(0, catalysts.count - 1)
            }

            let raw = try await StockPulseAPIService.shared.fetchDashboardRaw()
            MarketDataCache.save(raw)
            let dashboard = try StockPulseAPIService.shared.decodeDashboard(raw)
            applyDashboard(dashboard, fromCache: false)
        } catch {
            if !usesLiveData {
                refreshError = "Server unreachable. Showing cached data if available."
            } else {
                refreshError = friendlyNetworkError(error)
            }
        }

        await syncAssistantFeed()
        await syncMonitor()
    }

    /// Lightweight poll: snapshots only; full dashboard every 5 min if data_as_of unchanged skip.
    @MainActor
    func lightRefresh() async {
        guard usesServerAPI else { return }
        let shouldFullRefresh: Bool
        if let last = lastRefreshed {
            shouldFullRefresh = Date().timeIntervalSince(last) >= 300
        } else {
            shouldFullRefresh = true
        }
        if shouldFullRefresh {
            await refresh()
        } else {
            await syncAssistantFeed()
        }
    }

    @MainActor
    private func applyDashboard(_ dashboard: APIDashboard, fromCache: Bool) {
        isCachedData = fromCache
        serverStale = dashboard.stale
        lastDataAsOf = dashboard.dataAsOf

        var merged: [String: [HistoryPoint]] = [:]
        for (ticker, bars) in dashboard.histories {
            merged[ticker] = StockPulseAPIService.historyPoints(from: bars)
        }
        for (ticker, bars) in dashboard.historiesExtended {
            merged[ticker] = StockPulseAPIService.historyPoints(from: bars)
        }

        guard merged.values.contains(where: { !$0.isEmpty }) else {
            return
        }

        favoriteSymbols = dashboard.favorites.map { $0.uppercased() }
        favoriteCount = favoriteSymbols.count
        liveHistories = merged
        liveRippleResults = mapRippleResults(dashboard.rippleResults)
        var watchTickers = CatalystCatalog.watchlistTickers
        for sym in favoriteSymbols where !watchTickers.contains(sym) {
            watchTickers.append(sym)
        }
        watchItems = LiveDataBridge.watchItems(
            tickers: watchTickers,
            histories: merged,
            catalysts: catalysts
        )
        lastRefreshed = fromCache ? lastRefreshed : Date()
        recomputeMarketSnapshots()
        if !monitorHot.isEmpty || !monitorWarm.isEmpty || !monitorCold.isEmpty {
            rebuildWatchItemsFromMonitor()
        }
    }

    private func mapRippleResults(_ raw: [String: [APIRippleResult]]) -> [String: [RippleResult]] {
        var out: [String: [RippleResult]] = [:]
        for (catalyst, rows) in raw {
            out[catalyst] = rows.map { r in
                RippleResult(
                    catalystTicker: r.catalystTicker,
                    rippleTicker: r.rippleTicker,
                    rippleDescription: r.description,
                    verdict: RippleVerdict(rawValue: r.verdict) ?? .watching,
                    preEventPct: r.preEventPct,
                    postEventPct: r.postEventPct
                )
            }
        }
        if out.isEmpty {
            for catalyst in catalysts {
                out[catalyst.ticker] = RippleEngine.analyze(catalyst: catalyst, histories: liveHistories)
            }
        }
        return out
    }

    @MainActor
    private func refreshFromLocalMassive() async {
        let rawKey = Bundle.main.object(forInfoDictionaryKey: "MASSIVE_API_KEY") as? String ?? ""
        let apiKey = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            refreshError = "Set STOCKPULSE_API_BASE_URL in Config.xcconfig (use https:$(SLASH)$(SLASH)api.tryan.app), then Clean Build."
            return
        }
        isRefreshing = true
        refreshError = nil
        defer { isRefreshing = false }
        do {
            let tickers = CatalystCatalog.allTickers
            let fetched = try await MarketDataService.shared.fetchHistories(tickers: tickers, days: 90)
            guard fetched.values.contains(where: { !$0.isEmpty }) else {
                refreshError = "Massive returned no data."
                return
            }
            liveHistories = fetched
            watchItems = LiveDataBridge.watchItems(
                tickers: CatalystCatalog.watchlistTickers,
                histories: fetched,
                catalysts: catalysts
            )
            var results: [String: [RippleResult]] = [:]
            for catalyst in catalysts {
                results[catalyst.ticker] = RippleEngine.analyze(catalyst: catalyst, histories: fetched)
            }
            liveRippleResults = results
            lastRefreshed = Date()
            recomputeMarketSnapshots()
        } catch {
            refreshError = error.localizedDescription
        }
    }

    private func recomputeMarketSnapshots() {
        industrySnapshots = MarketAnalysisEngine.industrySnapshots(histories: liveHistories)
        indexSnapshots = MarketAnalysisEngine.indexSnapshots(histories: liveHistories)
    }
}
