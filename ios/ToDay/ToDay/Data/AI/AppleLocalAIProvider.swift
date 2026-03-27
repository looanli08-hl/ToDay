import Foundation

/// Free-tier AI provider using Apple Foundation Models (on-device, iOS 26+).
///
/// Wrapped entirely in `#available(iOS 26, *)` checks so the project compiles
/// on iOS 17+ without issue. On devices / simulators running < iOS 26,
/// `isAvailable` returns `false` and all methods throw `.modelNotSupported`.
final class AppleLocalAIProvider: EchoAIProviding, @unchecked Sendable {

    // MARK: - Availability

    var isAvailable: Bool {
        if #available(iOS 26, *) {
            return _checkModelAvailability()
        }
        return false
    }

    // MARK: - EchoAIProviding

    func respond(messages: [EchoChatMessage]) async throws -> String {
        guard #available(iOS 26, *) else {
            throw EchoAIError.modelNotSupported
        }
        return try await _respond(messages: messages)
    }

    func summarize(prompt: String) async throws -> String {
        guard #available(iOS 26, *) else {
            throw EchoAIError.modelNotSupported
        }
        return try await _generateText(prompt: prompt)
    }

    func generateProfile(prompt: String) async throws -> String {
        guard #available(iOS 26, *) else {
            throw EchoAIError.modelNotSupported
        }
        return try await _generateText(prompt: prompt)
    }

    // MARK: - iOS 26 Implementation

    @available(iOS 26, *)
    private func _checkModelAvailability() -> Bool {
        // FoundationModels availability check.
        // When FoundationModels SDK is available, use:
        //   import FoundationModels
        //   return SystemLanguageModel.isAvailable
        // For now, return true on iOS 26+ as a placeholder.
        return true
    }

    @available(iOS 26, *)
    private func _respond(messages: [EchoChatMessage]) async throws -> String {
        // TODO: Replace with real FoundationModels API when SDK is available.
        // Expected usage:
        //   import FoundationModels
        //   let model = SystemLanguageModel()
        //   let session = model.makeSession(instructions: systemPrompt)
        //   let response = try await session.respond(to: userMessage)
        //   return response.content
        //
        // Placeholder: echo back the last user message to unblock development.
        guard let lastUserMessage = messages.last(where: { $0.role == .user }) else {
            throw EchoAIError.invalidResponse
        }
        return "[本地 AI] 收到：\(lastUserMessage.content)"
    }

    @available(iOS 26, *)
    private func _generateText(prompt: String) async throws -> String {
        // TODO: Replace with real FoundationModels API when SDK is available.
        // Placeholder implementation for development.
        return "[本地 AI] 已处理请求"
    }
}
