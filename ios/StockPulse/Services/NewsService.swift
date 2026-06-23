import Foundation

private struct MassiveNewsResponse: Decodable {
    let results: [MassiveNewsArticle]?
    let status: String?
}

private struct MassiveNewsArticle: Decodable {
    let id: String?
    let title: String?
    let description: String?
    let articleUrl: String?
    let publishedUtc: String?
    let publisher: MassivePublisher?

    enum CodingKeys: String, CodingKey {
        case id, title, description
        case articleUrl = "article_url"
        case publishedUtc = "published_utc"
        case publisher
    }
}

private struct MassivePublisher: Decodable {
    let name: String?
}

/// Fetches ticker news from StockPulse API or Massive reference news.
actor NewsService {
    static let shared = NewsService()

    private var cache: [String: (articles: [NewsArticle], fetchedAt: Date)] = [:]
    private let cacheTTL: TimeInterval = 15 * 60

    private let massiveKey: String
    private let isoDecoder: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private init() {
        let raw = Bundle.main.object(forInfoDictionaryKey: "MASSIVE_API_KEY") as? String ?? ""
        massiveKey = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func fetchNews(symbols: [String], limit: Int = 6, force: Bool = false) async -> [NewsArticle] {
        let normalized = Array(Set(symbols.map { $0.uppercased() })).sorted()
        guard !normalized.isEmpty else { return [] }

        if !force, let cached = cachedArticles(for: normalized) {
            return cached
        }

        let articles: [NewsArticle]
        if StockPulseAPIService.isConfigured {
            articles = await fetchFromServer(symbols: normalized, limit: limit)
        } else if !massiveKey.isEmpty {
            articles = await fetchFromMassive(symbols: normalized, limit: limit)
        } else {
            articles = []
        }

        let stamp = Date()
        for symbol in normalized {
            let symbolArticles = articles.filter { $0.symbol == symbol }
            cache[symbol] = (symbolArticles, stamp)
        }
        return articles
    }

    func fetchNews(symbol: String, limit: Int = 6, force: Bool = false) async -> [NewsArticle] {
        await fetchNews(symbols: [symbol], limit: limit, force: force)
            .filter { $0.symbol == symbol.uppercased() }
    }

    // MARK: - Private

    private func cachedArticles(for symbols: [String]) -> [NewsArticle]? {
        let now = Date()
        var merged: [NewsArticle] = []
        var seen = Set<String>()
        for symbol in symbols {
            guard let entry = cache[symbol],
                  now.timeIntervalSince(entry.fetchedAt) < cacheTTL else {
                return nil
            }
            for article in entry.articles where seen.insert(article.id).inserted {
                merged.append(article)
            }
        }
        return merged.sorted { $0.publishedAt > $1.publishedAt }
    }

    private func fetchFromServer(symbols: [String], limit: Int) async -> [NewsArticle] {
        do {
            let rows = try await StockPulseAPIService.shared.news(
                symbols: symbols,
                limit: limit
            )
            return rows.compactMap(mapAPINews)
        } catch {
            return []
        }
    }

    private func fetchFromMassive(symbols: [String], limit: Int) async -> [NewsArticle] {
        var merged: [NewsArticle] = []
        var seen = Set<String>()
        for symbol in symbols.prefix(3) {
            let batch = await fetchMassiveNews(symbol: symbol, limit: limit)
            for article in batch where seen.insert(article.id).inserted {
                merged.append(article)
            }
        }
        return merged.sorted { $0.publishedAt > $1.publishedAt }.prefix(limit).map { $0 }
    }

    private func fetchMassiveNews(symbol: String, limit: Int) async -> [NewsArticle] {
        var components = URLComponents(string: "https://api.massive.com/v2/reference/news")!
        components.queryItems = [
            URLQueryItem(name: "ticker", value: symbol),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "order", value: "desc"),
            URLQueryItem(name: "sort", value: "published_utc"),
            URLQueryItem(name: "apiKey", value: massiveKey),
        ]
        guard let url = components.url else { return [] }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }
            let decoded = try JSONDecoder().decode(MassiveNewsResponse.self, from: data)
            return (decoded.results ?? []).compactMap { item in
                guard let headline = item.title, !headline.isEmpty else { return nil }
                let urlString = item.articleUrl ?? "massive://news/\(item.id ?? headline)"
                guard let articleURL = URL(string: urlString) else { return nil }
                let published = parseDate(item.publishedUtc) ?? Date()
                return NewsArticle(
                    id: item.id ?? urlString,
                    symbol: symbol.uppercased(),
                    headline: headline,
                    summary: item.description,
                    source: item.publisher?.name,
                    url: articleURL,
                    publishedAt: published,
                    sentimentScore: nil
                )
            }
        } catch {
            return []
        }
    }

    private func mapAPINews(_ row: APINewsItem) -> NewsArticle? {
        guard let url = URL(string: row.url) else { return nil }
        return NewsArticle(
            id: row.url,
            symbol: row.symbol,
            headline: row.headline,
            summary: row.summary,
            source: row.source,
            url: url,
            publishedAt: row.publishedAt,
            sentimentScore: row.sentimentScore
        )
    }

    private func parseDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        if let date = isoDecoder.date(from: raw) { return date }
        let plain = ISO8601DateFormatter()
        return plain.date(from: raw)
    }
}
