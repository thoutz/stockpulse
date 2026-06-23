import Foundation

enum AIProvider {
    case groq
    case anthropic
}

actor AIAnalystService {
    static let shared = AIAnalystService()

    private let provider: AIProvider
    private let groqKey: String
    private let anthropicKey: String

    nonisolated static var hasGroqKey: Bool {
        let raw = Bundle.main.object(forInfoDictionaryKey: "GROQ_API_KEY") as? String ?? ""
        return !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private init() {
        self.provider = .groq
        let groqRaw = Bundle.main.object(forInfoDictionaryKey: "GROQ_API_KEY") as? String ?? ""
        let anthropicRaw = Bundle.main.object(forInfoDictionaryKey: "ANTHROPIC_API_KEY") as? String ?? ""
        self.groqKey = groqRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        self.anthropicKey = anthropicRaw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func buildContext(from appContext: AIAppContext) -> String {
        AIContextBuilder.build(from: appContext)
    }

    func query(prompt: String, context: String) async throws -> String {
        switch provider {
        case .groq:
            guard !groqKey.isEmpty else {
                throw NSError(domain: "AIAnalyst", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Add GROQ_API_KEY in ios/Config.xcconfig, then rebuild."])
            }
            return try await queryGroq(prompt: prompt, context: context)
        case .anthropic:
            guard !anthropicKey.isEmpty else {
                throw NSError(domain: "AIAnalyst", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Add ANTHROPIC_API_KEY in ios/Config.xcconfig, then rebuild."])
            }
            return try await queryAnthropic(prompt: prompt, context: context)
        }
    }

    private func queryGroq(prompt: String, context: String) async throws -> String {
        struct Request: Encodable {
            let model: String
            let messages: [Message]
            let max_tokens: Int
            let temperature: Double
            struct Message: Encodable { let role: String; let content: String }
        }
        struct Response: Decodable {
            struct Choice: Decodable {
                struct Msg: Decodable { let content: String }
                let message: Msg
            }
            let choices: [Choice]
        }

        let body = Request(
            model: "llama-3.3-70b-versatile",
            messages: [
                .init(role: "system", content: context),
                .init(role: "user", content: prompt),
            ],
            max_tokens: 1200,
            temperature: 0.4
        )

        var req = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/chat/completions")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(groqKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let snippet = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "AIAnalyst", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "Groq error \(http.statusCode): \(snippet.prefix(200))"])
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.choices.first?.message.content ?? "No response."
    }

    private func queryAnthropic(prompt: String, context: String) async throws -> String {
        struct Request: Encodable {
            let model: String
            let max_tokens: Int
            let system: String
            let messages: [Message]
            struct Message: Encodable { let role: String; let content: String }
        }
        struct Response: Decodable {
            struct Block: Decodable { let type: String; let text: String? }
            let content: [Block]
        }

        let body = Request(
            model: "claude-sonnet-4-20250514",
            max_tokens: 1200,
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
