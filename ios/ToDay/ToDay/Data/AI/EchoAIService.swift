import Foundation

/// Routes AI requests to the correct provider based on user's subscription tier.
///
/// Falls back to the free provider when the preferred provider is unavailable
/// (e.g., no API key configured for DeepSeek).
final class EchoAIService: @unchecked Sendable {

    private let freeProvider: any EchoAIProviding
    private let proProvider: any EchoAIProviding

    /// Current user tier. Persisted to UserDefaults.
    var currentTier: EchoUserTier {
        get {
            guard let raw = UserDefaults.standard.string(forKey: "today.echo.userTier") else {
                return .free
            }
            return EchoUserTier(rawValue: raw) ?? .free
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "today.echo.userTier")
        }
    }

    init(
        freeProvider: any EchoAIProviding = AppleLocalAIProvider(),
        proProvider: any EchoAIProviding = DeepSeekAIProvider()
    ) {
        self.freeProvider = freeProvider
        self.proProvider = proProvider
    }

    // MARK: - Routing

    func respond(messages: [EchoChatMessage]) async throws -> String {
        let provider = try resolveProvider()
        return try await provider.respond(messages: messages)
    }

    func summarize(prompt: String) async throws -> String {
        let provider = try resolveProvider()
        return try await provider.summarize(prompt: prompt)
    }

    func generateProfile(prompt: String) async throws -> String {
        let provider = try resolveProvider()
        return try await provider.generateProfile(prompt: prompt)
    }

    /// Returns the active provider, with fallback logic.
    var activeProvider: (any EchoAIProviding)? {
        let preferred = preferredProvider
        if preferred.isAvailable { return preferred }
        let fallback = fallbackProvider
        if fallback.isAvailable { return fallback }
        return nil
    }

    // MARK: - Private

    private var preferredProvider: any EchoAIProviding {
        switch currentTier {
        case .free: return freeProvider
        case .pro:  return proProvider
        }
    }

    private var fallbackProvider: any EchoAIProviding {
        switch currentTier {
        case .free: return proProvider
        case .pro:  return freeProvider
        }
    }

    private func resolveProvider() throws -> any EchoAIProviding {
        if let provider = activeProvider {
            return provider
        }
        throw EchoAIError.providerUnavailable("没有可用的 AI 服务")
    }
}
