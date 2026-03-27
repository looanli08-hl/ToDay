import Foundation

/// Pro-tier AI provider using DeepSeek API via URLSession.
///
/// API endpoint: `https://api.deepseek.com/chat/completions`
/// Model: `deepseek-chat`
/// Authentication: Bearer token from user settings.
final class DeepSeekAIProvider: EchoAIProviding, @unchecked Sendable {

    private let session: URLSession
    private let baseURL = URL(string: "https://api.deepseek.com/chat/completions")!
    private let model = "deepseek-chat"

    /// UserDefaults key where the user's DeepSeek API key is stored.
    static let apiKeyDefaultsKey = "today.echo.deepseekAPIKey"

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - API Key

    var apiKey: String? {
        UserDefaults.standard.string(forKey: Self.apiKeyDefaultsKey)
    }

    // MARK: - EchoAIProviding

    var isAvailable: Bool {
        apiKey != nil && !apiKey!.isEmpty
    }

    func respond(messages: [EchoChatMessage]) async throws -> String {
        let apiMessages = messages.map { msg in
            DeepSeekMessage(role: msg.role.deepSeekRole, content: msg.content)
        }
        return try await callAPI(messages: apiMessages)
    }

    func summarize(prompt: String) async throws -> String {
        let messages = [
            DeepSeekMessage(role: "system", content: "你是一个生活数据分析助手。根据提供的数据，生成简洁的中文摘要。"),
            DeepSeekMessage(role: "user", content: prompt)
        ]
        return try await callAPI(messages: messages)
    }

    func generateProfile(prompt: String) async throws -> String {
        let messages = [
            DeepSeekMessage(role: "system", content: "你是一个用户画像分析师。根据提供的每日摘要，生成或更新用户画像描述。用中文回应，控制在 200 字以内。"),
            DeepSeekMessage(role: "user", content: prompt)
        ]
        return try await callAPI(messages: messages)
    }

    // MARK: - API Call

    private func callAPI(messages: [DeepSeekMessage]) async throws -> String {
        guard let key = apiKey, !key.isEmpty else {
            throw EchoAIError.apiKeyMissing
        }

        let requestBody = DeepSeekRequest(
            model: model,
            messages: messages,
            temperature: 0.7,
            max_tokens: 1024
        )

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        request.timeoutInterval = 30

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw EchoAIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EchoAIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 429:
            throw EchoAIError.rateLimited
        default:
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            throw EchoAIError.providerUnavailable("HTTP \(httpResponse.statusCode): \(body)")
        }

        let decoded = try JSONDecoder().decode(DeepSeekResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw EchoAIError.invalidResponse
        }
        return content
    }
}

// MARK: - DeepSeek API Types

private struct DeepSeekRequest: Encodable {
    let model: String
    let messages: [DeepSeekMessage]
    let temperature: Double
    let max_tokens: Int
}

private struct DeepSeekMessage: Codable {
    let role: String
    let content: String
}

private struct DeepSeekResponse: Decodable {
    let choices: [DeepSeekChoice]
}

private struct DeepSeekChoice: Decodable {
    let message: DeepSeekChoiceMessage
}

private struct DeepSeekChoiceMessage: Decodable {
    let content: String
}

// MARK: - Role Mapping

private extension EchoChatRole {
    var deepSeekRole: String {
        switch self {
        case .system:    return "system"
        case .user:      return "user"
        case .assistant: return "assistant"
        }
    }
}
