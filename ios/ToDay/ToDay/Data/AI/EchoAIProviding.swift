import Foundation

// MARK: - Chat Message

enum EchoChatRole: String, Codable, Sendable {
    case system
    case user
    case assistant
}

struct EchoChatMessage: Codable, Sendable, Identifiable {
    let id: UUID
    let role: EchoChatRole
    let content: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        role: EchoChatRole,
        content: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

// MARK: - Context

struct EchoContext: Sendable {
    let userProfile: String?
    let recentSummaries: [String]
    let conversationMemory: String?
    let todayData: String?
    let personality: EchoPersonality

    init(
        userProfile: String? = nil,
        recentSummaries: [String] = [],
        conversationMemory: String? = nil,
        todayData: String? = nil,
        personality: EchoPersonality = .gentle
    ) {
        self.userProfile = userProfile
        self.recentSummaries = recentSummaries
        self.conversationMemory = conversationMemory
        self.todayData = todayData
        self.personality = personality
    }
}

// MARK: - Personality

enum EchoPersonality: String, Codable, CaseIterable, Sendable {
    case gentle    // 温柔内敛
    case cheerful  // 积极阳光
    case rational  // 克制理性

    var displayName: String {
        switch self {
        case .gentle:   return "温柔内敛"
        case .cheerful: return "积极阳光"
        case .rational: return "克制理性"
        }
    }

    var systemPromptPrefix: String {
        switch self {
        case .gentle:
            return """
            你是 Echo，用户生活中安静而深思的老朋友。你的风格温和、简洁，句句到点上。\
            不主动给建议，除非用户问到。用中文回应。
            """
        case .cheerful:
            return """
            你是 Echo，用户身边热情贴心的好朋友。你积极、鼓励，适量使用 emoji，\
            主动分享对用户生活的感受。用中文回应。
            """
        case .rational:
            return """
            你是 Echo，用户信赖的成熟导师。你理性、条理清晰、数据驱动，\
            少用情绪化表达，注重客观分析。用中文回应。
            """
        }
    }
}

// MARK: - User Tier

enum EchoUserTier: String, Codable, Sendable {
    case free   // Apple Foundation Models (local)
    case pro    // DeepSeek API (cloud)
}

// MARK: - Errors

enum EchoAIError: Error, LocalizedError, Sendable {
    case providerUnavailable(String)
    case networkError(Error)
    case invalidResponse
    case rateLimited
    case apiKeyMissing
    case modelNotSupported

    var errorDescription: String? {
        switch self {
        case .providerUnavailable(let reason):
            return "AI 服务不可用：\(reason)"
        case .networkError(let error):
            return "网络错误：\(error.localizedDescription)"
        case .invalidResponse:
            return "AI 返回了无效的响应"
        case .rateLimited:
            return "请求过于频繁，请稍后再试"
        case .apiKeyMissing:
            return "缺少 API Key，请在设置中配置"
        case .modelNotSupported:
            return "当前设备不支持本地 AI 模型"
        }
    }
}

// MARK: - Protocol

protocol EchoAIProviding: Sendable {
    /// Chat-style response given a list of messages
    func respond(messages: [EchoChatMessage]) async throws -> String

    /// Summarize a day's data into a concise paragraph
    func summarize(prompt: String) async throws -> String

    /// Generate or update user profile from daily summaries
    func generateProfile(prompt: String) async throws -> String

    /// Whether this provider is currently available on device
    var isAvailable: Bool { get }
}
