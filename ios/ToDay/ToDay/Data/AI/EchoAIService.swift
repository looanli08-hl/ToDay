import Foundation

/// Routes all AI requests to the DeepSeek provider.
final class EchoAIService: EchoAIProviding, @unchecked Sendable {

    private let provider: any EchoAIProviding

    init(provider: any EchoAIProviding = DeepSeekAIProvider()) {
        self.provider = provider
    }

    // MARK: - EchoAIProviding

    var isAvailable: Bool {
        provider.isAvailable
    }

    func respond(messages: [EchoChatMessage]) async throws -> String {
        guard provider.isAvailable else {
            throw EchoAIError.providerUnavailable("AI 服务暂不可用")
        }
        return try await provider.respond(messages: messages)
    }

    func summarize(prompt: String) async throws -> String {
        guard provider.isAvailable else {
            throw EchoAIError.providerUnavailable("AI 服务暂不可用")
        }
        return try await provider.summarize(prompt: prompt)
    }

    func generateProfile(prompt: String) async throws -> String {
        guard provider.isAvailable else {
            throw EchoAIError.providerUnavailable("AI 服务暂不可用")
        }
        return try await provider.generateProfile(prompt: prompt)
    }
}
