import Foundation

private struct MassiveAggResponse: Decodable {
    let results: [MassiveBar]?
    let status: String?
    let error: String?
}

private struct MassiveBar: Decodable {
    let t: Int64
    let o: Double
    let h: Double
    let l: Double
    let c: Double
    let v: Double
}

enum MarketDataError: LocalizedError {
    case missingAPIKey
    case rateLimited(String)
    case apiMessage(String)
    case noBars(symbol: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add MASSIVE_API_KEY in ios/Config.xcconfig, then rebuild."
        case .rateLimited(let message):
            return message
        case .apiMessage(let message):
            return message
        case .noBars(let symbol):
            return "No daily bars returned for \(symbol)."
        }
    }
}

/// Daily OHLCV from Massive (formerly Polygon.io). Free Stocks Basic: 5 calls/min, EOD, 2yr history.
actor MarketDataService {
    static let shared = MarketDataService()

    private let apiKey: String
    private let baseURL = "https://api.massive.com"
    private var cache: [String: (data: [HistoryPoint], fetchedAt: Date)] = [:]
    private let cacheMaxAge: TimeInterval = 300
    private let callsPerMinute = 5

    private init() {
        let raw = Bundle.main.object(forInfoDictionaryKey: "MASSIVE_API_KEY") as? String ?? ""
        self.apiKey = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func fetchHistory(ticker: String, days: Int = 30) async throws -> [HistoryPoint] {
        if apiKey.isEmpty { throw MarketDataError.missingAPIKey }

        if let cached = cache[ticker], Date().timeIntervalSince(cached.fetchedAt) < cacheMaxAge {
            return cached.data
        }

        let calendar = Calendar.current
        let to = Date()
        let from = calendar.date(byAdding: .day, value: -days, to: to)!

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let fromStr = formatter.string(from: from)
        let toStr = formatter.string(from: to)

        let path = "\(baseURL)/v2/aggs/ticker/\(ticker)/range/1/day/\(fromStr)/\(toStr)"
        var components = URLComponents(string: path)!
        components.queryItems = [
            URLQueryItem(name: "adjusted", value: "true"),
            URLQueryItem(name: "sort", value: "asc"),
            URLQueryItem(name: "limit", value: String(days + 5)),
            URLQueryItem(name: "apiKey", value: apiKey),
        ]
        guard let url = components.url else { throw URLError(.badURL) }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        if http.statusCode == 429 {
            throw MarketDataError.rateLimited("Massive rate limit (5 calls/min on free tier). Wait and try again.")
        }
        guard http.statusCode == 200 else {
            throw MarketDataError.apiMessage("Massive HTTP \(http.statusCode) for \(ticker)")
        }

        let decoded = try JSONDecoder().decode(MassiveAggResponse.self, from: data)
        if let err = decoded.error, !err.isEmpty {
            throw MarketDataError.apiMessage(err)
        }
        if decoded.status == "ERROR" {
            throw MarketDataError.apiMessage("Massive error for \(ticker)")
        }

        let points = (decoded.results ?? []).map { bar -> HistoryPoint in
            let date = Date(timeIntervalSince1970: Double(bar.t) / 1000)
            return HistoryPoint(date: date, open: bar.o, high: bar.h, low: bar.l, close: bar.c, volume: Int64(bar.v))
        }

        guard !points.isEmpty else { throw MarketDataError.noBars(symbol: ticker) }

        cache[ticker] = (data: points, fetchedAt: Date())
        return points
    }

    /// Fetches in batches of 5 (free-tier calls/min), then pauses before the next batch.
    func fetchHistories(tickers: [String], days: Int = 30) async throws -> [String: [HistoryPoint]] {
        if apiKey.isEmpty { throw MarketDataError.missingAPIKey }

        var results: [String: [HistoryPoint]] = [:]
        let batchSize = callsPerMinute

        for batchStart in stride(from: 0, to: tickers.count, by: batchSize) {
            let end = min(batchStart + batchSize, tickers.count)
            let batch = Array(tickers[batchStart..<end])

            try await withThrowingTaskGroup(of: (String, [HistoryPoint]).self) { group in
                for ticker in batch {
                    group.addTask {
                        let points = try await self.fetchHistory(ticker: ticker, days: days)
                        return (ticker, points)
                    }
                }
                for try await (ticker, points) in group {
                    results[ticker] = points
                }
            }

            if end < tickers.count {
                try await Task.sleep(nanoseconds: 60_000_000_000)
            }
        }
        return results
    }
}
