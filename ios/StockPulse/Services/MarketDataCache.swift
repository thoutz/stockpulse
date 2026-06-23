import Foundation

/// Persists last successful `/api/dashboard` response for instant cold launch.
enum MarketDataCache {
    private static let fileName = "last_dashboard.json"

    private static var cacheURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(fileName)
    }

    static func save(_ data: Data) {
        try? data.write(to: cacheURL, options: .atomic)
    }

    static func load() -> Data? {
        try? Data(contentsOf: cacheURL)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: cacheURL)
    }
}
