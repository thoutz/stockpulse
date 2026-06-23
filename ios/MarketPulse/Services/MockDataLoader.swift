import Foundation

enum MockDataLoader {
    private struct MockFile: Decodable {
        let dates: [String]
        let prices: [String: [Double]]
    }

    /// Synchronous mock load for ViewModel property initialization (first frame).
    static func load() -> [String: [HistoryPoint]] {
        (try? loadHistories()) ?? [:]
    }

    static func loadHistories() throws -> [String: [HistoryPoint]] {
        guard let url = Bundle.main.url(forResource: "MockData", withExtension: "json") else {
            throw MockDataError.missingFile
        }
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(MockFile.self, from: data)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = Calendar.current.timeZone

        var histories: [String: [HistoryPoint]] = [:]
        for (ticker, closes) in decoded.prices {
            let count = min(decoded.dates.count, closes.count)
            var points: [HistoryPoint] = []
            points.reserveCapacity(count)
            for i in 0..<count {
                guard let date = formatter.date(from: decoded.dates[i]) else { continue }
                let close = closes[i]
                points.append(HistoryPoint(
                    date: date,
                    open: close,
                    high: close,
                    low: close,
                    close: close,
                    volume: 0
                ))
            }
            histories[ticker] = points
        }
        return histories
    }
}

enum MockDataError: LocalizedError {
    case missingFile

    var errorDescription: String? {
        switch self {
        case .missingFile: return "MockData.json not found in bundle."
        }
    }
}
