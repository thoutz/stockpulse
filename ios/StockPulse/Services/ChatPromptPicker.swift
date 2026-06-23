import CryptoKit
import Foundation

enum ChatPromptPicker {
    static let fallbackPool = [
        "Summarize my watchlist for today",
        "Which ripple network looks strongest?",
        "Compare the top two movers this week",
        "What's the broad market telling us today?",
        "Which catalyst has the best ripple confirmation?",
        "Did NVDA earnings actually lift AMD?",
        "Which space stock has best risk/reward?",
        "Summarize the full watchlist",
    ]

    static func fallbackPrompts(count: Int = 4, now: Date = Date()) -> [String] {
        pick(from: fallbackPool, count: count, dateKey: etDateKey(from: now))
    }

    static func etDateKey(from date: Date = Date()) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year ?? 1970, comps.month ?? 1, comps.day ?? 1)
    }

    static func pick(from pool: [String], count: Int, dateKey: String) -> [String] {
        guard !pool.isEmpty else { return [] }
        var order = Array(pool.indices)
        for i in stride(from: order.count - 1, through: 1, by: -1) {
            let digest = SHA256.hash(data: Data("\(dateKey):sort:\(i)".utf8))
            let value = digest.withUnsafeBytes { raw in
                raw.load(as: UInt64.self)
            }
            let j = Int(value % UInt64(i + 1))
            order.swapAt(i, j)
        }
        var picked: [String] = []
        for idx in order.prefix(count) {
            let prompt = pool[idx]
            if !picked.contains(prompt) {
                picked.append(prompt)
            }
        }
        var fallbackIndex = 0
        while picked.count < count {
            let candidate = fallbackPool[fallbackIndex % fallbackPool.count]
            fallbackIndex += 1
            if !picked.contains(candidate) {
                picked.append(candidate)
            }
        }
        return Array(picked.prefix(count))
    }
}
