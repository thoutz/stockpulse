// Services/AIAnalystService.swift
import Foundation

// MARK: - Provider

enum AIProvider {
    case groq   // recommended — fast, cheap, you already use it
    case anthropic
}

// MARK: - AIAnalystService

actor AIAnalystService {
    static let shared = AIAnalystService()

    private let provider: AIProvider
    private let groqKey: String
    private let anthropicKey: String

    private init() {
        self.provider = .groq
        self.groqKey = Bundle.main.object(forInfoDictionaryKey: "GROQ_API_KEY") as? String ?? ""
        self.anthropicKey = Bundle.main.object(forInfoDictionaryKey: "ANTHROPIC_API_KEY") as? String ?? ""
    }

    // MARK: - Build context from live data

    func buildContext(
        histories: [String: [HistoryPoint]],
        rippleResults: [RippleResult],
        catalysts: [Catalyst]
    ) -> String {
        var lines = ["You are a stock market analyst with access to 30 days of price history and ripple correlation data. Answer in 3-5 concise sentences. Be direct and actionable.\n"]

        lines.append("=== CURRENT DATA ===")
        for (ticker, history) in histories.sorted(by: { $0.key < $1.key }) {
            let sorted = history.sorted { $0.date < $1.date }
            guard let first = sorted.first, let last = sorted.last else { continue }
            let chg30 = ((last.close - first.close) / first.close * 100)
            lines.append("\(ticker): $\(String(format: "%.2f", last.close)), 30d: \(String(format: "%+.1f", chg30))%")
        }

        lines.append("\n=== RIPPLE VERDICTS ===")
        for r in rippleResults {
            lines.append("\(r.catalystTicker)→\(r.rippleTicker): \(r.verdict.rawValue) (catalyst post: \(String(format: "%+.1f", r.catalystPostChange))%, ripple post: \(String(format: "%+.1f", r.postEventChange))%)")
        }

        lines.append("\n=== KEY EVENTS ===")
        for catalyst in catalysts {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            lines.append("\(formatter.string(from: catalyst.eventDate)): \(catalyst.ticker) — \(catalyst.eventName)")
            for event in catalyst.events {
                lines.append("  \(formatter.string(from: event.date)): \(event.label)")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Query

    func query(prompt: String, context: String) async throws -> String {
        switch provider {
        case .groq:      return try await queryGroq(prompt: prompt, context: context)
        case .anthropic: return try await queryAnthropic(prompt: prompt, context: context)
        }
    }

    // MARK: - Groq

    private func queryGroq(prompt: String, context: String) async throws -> String {
        struct Request: Encodable {
            let model: String; let messages: [Message]; let max_tokens: Int
            struct Message: Encodable { let role: String; let content: String }
        }
        struct Response: Decodable {
            struct Choice: Decodable { struct Msg: Decodable { let content: String }; let message: Msg }
            let choices: [Choice]
        }

        let body = Request(
            model: "llama-3.3-70b-versatile",
            messages: [
                .init(role: "system", content: context),
                .init(role: "user", content: prompt),
            ],
            max_tokens: 500
        )

        var req = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/chat/completions")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(groqKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: req)
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.choices.first?.message.content ?? "No response."
    }

    // MARK: - Anthropic

    private func queryAnthropic(prompt: String, context: String) async throws -> String {
        struct Request: Encodable {
            let model: String; let max_tokens: Int; let system: String; let messages: [Message]
            struct Message: Encodable { let role: String; let content: String }
        }
        struct Response: Decodable {
            struct Block: Decodable { let type: String; let text: String? }
            let content: [Block]
        }

        let body = Request(
            model: "claude-sonnet-4-20250514",
            max_tokens: 500,
            system: context,
            messages: [.init(role: "user", content: prompt)]
        )

        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue(anthropicKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: req)
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.content.first(where: { $0.type == "text" })?.text ?? "No response."
    }
}
