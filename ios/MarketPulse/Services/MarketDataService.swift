// Services/MarketDataService.swift
import Foundation

// MARK: - Polygon Response Models

private struct PolygonAggResponse: Decodable {
    let results: [PolygonBar]?
    let status: String
    let ticker: String?
}

private struct PolygonBar: Decodable {
    let t: Int64   // timestamp ms
    let o: Double  // open
    let h: Double  // high
    let l: Double  // low
    let c: Double  // close
    let v: Double  // volume
}

// MARK: - MarketDataService

actor MarketDataService {
    static let shared = MarketDataService()

    private let apiKey: String
    private let baseURL = "https://api.polygon.io"
    private var cache: [String: (data: [HistoryPoint], fetchedAt: Date)] = [:]
    private let cacheMaxAge: TimeInterval = 300 // 5 minutes

    private init() {
        // Load from xcconfig / Info.plist
        self.apiKey = Bundle.main.object(forInfoDictionaryKey: "POLYGON_API_KEY") as? String ?? ""
    }

    // MARK: - Fetch daily bars (30 days)

    func fetchHistory(ticker: String, days: Int = 30) async throws -> [HistoryPoint] {
        // Cache check
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

        let urlStr = "\(baseURL)/v2/aggs/ticker/\(ticker)/range/1/day/\(fromStr)/\(toStr)?adjusted=true&sort=asc&limit=\(days + 5)&apiKey=\(apiKey)"
        guard let url = URL(string: urlStr) else { throw URLError(.badURL) }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(PolygonAggResponse.self, from: data)
        let points = (decoded.results ?? []).map { bar -> HistoryPoint in
            let date = Date(timeIntervalSince1970: Double(bar.t) / 1000)
            return HistoryPoint(date: date, open: bar.o, high: bar.h, low: bar.l, close: bar.c, volume: Int64(bar.v))
        }

        cache[ticker] = (data: points, fetchedAt: Date())
        return points
    }

    // MARK: - Fetch multiple tickers concurrently

    func fetchHistories(tickers: [String], days: Int = 30) async throws -> [String: [HistoryPoint]] {
        try await withThrowingTaskGroup(of: (String, [HistoryPoint]).self) { group in
            for ticker in tickers {
                group.addTask {
                    let points = try await self.fetchHistory(ticker: ticker, days: days)
                    return (ticker, points)
                }
            }
            var results: [String: [HistoryPoint]] = [:]
            for try await (ticker, points) in group {
                results[ticker] = points
            }
            return results
        }
    }

    // MARK: - Latest quote (for real-time price)

    func fetchLatestPrice(ticker: String) async throws -> Double {
        let urlStr = "\(baseURL)/v2/last/trade/\(ticker)?apiKey=\(apiKey)"
        guard let url = URL(string: urlStr) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        struct Response: Decodable { struct Result: Decodable { let p: Double }; let results: Result }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.results.p
    }
}
