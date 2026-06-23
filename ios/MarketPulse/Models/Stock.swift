// Models/Stock.swift
import Foundation
import SwiftData

// MARK: - Stock

@Model
class Stock {
    var ticker: String
    var name: String
    var sector: String
    var isWatched: Bool
    var addedAt: Date
    @Relationship(deleteRule: .cascade) var history: [HistoryPoint]

    init(ticker: String, name: String, sector: String = "") {
        self.ticker = ticker
        self.name = name
        self.sector = sector
        self.isWatched = true
        self.addedAt = Date()
        self.history = []
    }

    var currentPrice: Double { history.sorted { $0.date < $1.date }.last?.close ?? 0 }
    var previousPrice: Double {
        let sorted = history.sorted { $0.date < $1.date }
        guard sorted.count >= 2 else { return currentPrice }
        return sorted[sorted.count - 2].close
    }
    var change1D: Double {
        guard previousPrice > 0 else { return 0 }
        return ((currentPrice - previousPrice) / previousPrice) * 100
    }
    var change30D: Double {
        let sorted = history.sorted { $0.date < $1.date }
        guard let first = sorted.first, first.close > 0 else { return 0 }
        return ((currentPrice - first.close) / first.close) * 100
    }
    var high30D: Double { history.map(\.high).max() ?? 0 }
    var low30D: Double { history.map(\.low).min() ?? 0 }

    func normalizedHistory(from baseline: Date? = nil) -> [(date: Date, pctChange: Double)] {
        let sorted = history.sorted { $0.date < $1.date }
        let baselinePrice: Double
        if let baseline {
            baselinePrice = sorted.first(where: { $0.date >= baseline })?.close ?? sorted.first?.close ?? 1
        } else {
            baselinePrice = sorted.first?.close ?? 1
        }
        guard baselinePrice > 0 else { return [] }
        return sorted.map { pt in
            (date: pt.date, pctChange: ((pt.close - baselinePrice) / baselinePrice) * 100)
        }
    }
}

// MARK: - HistoryPoint

@Model
class HistoryPoint {
    var date: Date
    var open: Double
    var high: Double
    var low: Double
    var close: Double
    var volume: Int64

    init(date: Date, open: Double, high: Double, low: Double, close: Double, volume: Int64 = 0) {
        self.date = date
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
    }
}
