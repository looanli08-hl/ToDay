# Echo AI Infrastructure Layer

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the complete AI infrastructure layer for the Echo companion system — protocol-based AI providers, four-layer memory persistence, prompt assembly, daily summary generation, weekly profile updates, and wire everything into AppContainer.

**Architecture:** Protocol-oriented design with `EchoAIProviding` as the unified AI interface. Two concrete providers: `AppleLocalAIProvider` (free tier, `#available(iOS 26, *)`) and `DeepSeekAIProvider` (Pro tier, URLSession HTTP). `EchoAIService` routes to the correct provider based on user tier. Memory uses three new SwiftData entities (`UserProfileEntity`, `DailySummaryEntity`, `ConversationMemoryEntity`) managed by `EchoMemoryManager`. `EchoPromptBuilder` assembles context from the four memory layers + personality templates. Background tasks handle daily summaries and weekly profile updates.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, XCTest, Foundation Models (iOS 26), URLSession

**Spec:** `docs/superpowers/specs/2026-03-26-ai-echo-companion-design.md`

---

## File Structure

### New Files

| File | Responsibility |
|------|----------------|
| `ToDay/Data/AI/EchoAIProviding.swift` | `EchoAIProviding` protocol + `EchoChatMessage`, `EchoContext`, `EchoAIError` types |
| `ToDay/Data/AI/AppleLocalAIProvider.swift` | Free-tier provider using Foundation Models (`#available(iOS 26, *)`) |
| `ToDay/Data/AI/DeepSeekAIProvider.swift` | Pro-tier provider using DeepSeek API via URLSession |
| `ToDay/Data/AI/EchoAIService.swift` | Router that picks provider based on `EchoUserTier` |
| `ToDay/Data/AI/EchoMemoryEntities.swift` | SwiftData entities: `UserProfileEntity`, `DailySummaryEntity`, `ConversationMemoryEntity` |
| `ToDay/Data/AI/EchoMemoryManager.swift` | CRUD for four-layer memory system |
| `ToDay/Data/AI/EchoPromptBuilder.swift` | Assembles system prompt + context from memory layers + personality |
| `ToDay/Data/AI/EchoDailySummaryGenerator.swift` | Summarizes a day's data via AI |
| `ToDay/Data/AI/EchoWeeklyProfileUpdater.swift` | Updates user profile from daily summaries via AI |
| `ToDayTests/EchoAIServiceTests.swift` | Tests for AI service routing + mock provider |
| `ToDayTests/EchoMemoryManagerTests.swift` | Tests for memory CRUD with in-memory ModelContainer |
| `ToDayTests/EchoPromptBuilderTests.swift` | Tests for prompt assembly |
| `ToDayTests/EchoDailySummaryGeneratorTests.swift` | Tests for daily summary generation |

### Modified Files

| File | Changes |
|------|---------|
| `ToDay/App/AppContainer.swift` | Register 3 new SwiftData entities, create `EchoAIService`, `EchoMemoryManager`, `EchoPromptBuilder` singletons |

All paths are relative to `ios/ToDay/`.

---

## Task 1: EchoAIProviding Protocol + Supporting Types

**Files:**
- Create: `ios/ToDay/ToDay/Data/AI/EchoAIProviding.swift`

- [ ] **Step 1: Create the AI directory**

```bash
mkdir -p ios/ToDay/ToDay/Data/AI
```

- [ ] **Step 2: Create EchoAIProviding.swift**

Create `ios/ToDay/ToDay/Data/AI/EchoAIProviding.swift`:

```swift
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
```

- [ ] **Step 3: Regenerate Xcode project and build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
cd ios/ToDay && git add ToDay/Data/AI/EchoAIProviding.swift
git commit -m "feat(echo-ai): add EchoAIProviding protocol with supporting types"
```

---

## Task 2: AppleLocalAIProvider

**Files:**
- Create: `ios/ToDay/ToDay/Data/AI/AppleLocalAIProvider.swift`

- [ ] **Step 1: Create AppleLocalAIProvider.swift**

Create `ios/ToDay/ToDay/Data/AI/AppleLocalAIProvider.swift`:

```swift
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
```

- [ ] **Step 2: Build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
cd ios/ToDay && git add ToDay/Data/AI/AppleLocalAIProvider.swift
git commit -m "feat(echo-ai): add AppleLocalAIProvider with iOS 26 availability gate"
```

---

## Task 3: DeepSeekAIProvider

**Files:**
- Create: `ios/ToDay/ToDay/Data/AI/DeepSeekAIProvider.swift`

- [ ] **Step 1: Create DeepSeekAIProvider.swift**

Create `ios/ToDay/ToDay/Data/AI/DeepSeekAIProvider.swift`:

```swift
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
```

- [ ] **Step 2: Build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
cd ios/ToDay && git add ToDay/Data/AI/DeepSeekAIProvider.swift
git commit -m "feat(echo-ai): add DeepSeekAIProvider with URLSession HTTP calls"
```

---

## Task 4: EchoAIService Router

**Files:**
- Create: `ios/ToDay/ToDay/Data/AI/EchoAIService.swift`
- Create: `ios/ToDay/ToDayTests/EchoAIServiceTests.swift`

- [ ] **Step 1: Write tests for EchoAIService**

Create `ios/ToDay/ToDayTests/EchoAIServiceTests.swift`:

```swift
import XCTest
@testable import ToDay

// MARK: - Mock AI Provider

final class MockAIProvider: EchoAIProviding, @unchecked Sendable {
    var respondResult: String = "mock response"
    var summarizeResult: String = "mock summary"
    var profileResult: String = "mock profile"
    var shouldFail = false
    var isAvailable: Bool = true

    private(set) var respondCallCount = 0
    private(set) var summarizeCallCount = 0
    private(set) var profileCallCount = 0

    func respond(messages: [EchoChatMessage]) async throws -> String {
        respondCallCount += 1
        if shouldFail { throw EchoAIError.invalidResponse }
        return respondResult
    }

    func summarize(prompt: String) async throws -> String {
        summarizeCallCount += 1
        if shouldFail { throw EchoAIError.invalidResponse }
        return summarizeResult
    }

    func generateProfile(prompt: String) async throws -> String {
        profileCallCount += 1
        if shouldFail { throw EchoAIError.invalidResponse }
        return profileResult
    }
}

// MARK: - Tests

final class EchoAIServiceTests: XCTestCase {
    private var freeProvider: MockAIProvider!
    private var proProvider: MockAIProvider!
    private var service: EchoAIService!

    override func setUp() {
        super.setUp()
        freeProvider = MockAIProvider()
        proProvider = MockAIProvider()
        service = EchoAIService(
            freeProvider: freeProvider,
            proProvider: proProvider
        )
    }

    func testFreeUserUsesLocalProvider() async throws {
        service.currentTier = .free
        freeProvider.respondResult = "local answer"

        let messages = [EchoChatMessage(role: .user, content: "你好")]
        let result = try await service.respond(messages: messages)

        XCTAssertEqual(result, "local answer")
        XCTAssertEqual(freeProvider.respondCallCount, 1)
        XCTAssertEqual(proProvider.respondCallCount, 0)
    }

    func testProUserUsesDeepSeekProvider() async throws {
        service.currentTier = .pro
        proProvider.respondResult = "pro answer"

        let messages = [EchoChatMessage(role: .user, content: "你好")]
        let result = try await service.respond(messages: messages)

        XCTAssertEqual(result, "pro answer")
        XCTAssertEqual(proProvider.respondCallCount, 1)
        XCTAssertEqual(freeProvider.respondCallCount, 0)
    }

    func testFallbackWhenPreferredProviderUnavailable() async throws {
        service.currentTier = .pro
        proProvider.isAvailable = false
        freeProvider.respondResult = "fallback answer"

        let messages = [EchoChatMessage(role: .user, content: "你好")]
        let result = try await service.respond(messages: messages)

        XCTAssertEqual(result, "fallback answer")
        XCTAssertEqual(freeProvider.respondCallCount, 1)
    }

    func testThrowsWhenNoProviderAvailable() async {
        service.currentTier = .pro
        proProvider.isAvailable = false
        freeProvider.isAvailable = false

        let messages = [EchoChatMessage(role: .user, content: "你好")]
        do {
            _ = try await service.respond(messages: messages)
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(error is EchoAIError)
        }
    }

    func testSummarizeRoutesToCorrectProvider() async throws {
        service.currentTier = .free
        freeProvider.summarizeResult = "today was good"

        let result = try await service.summarize(prompt: "summarize today")
        XCTAssertEqual(result, "today was good")
        XCTAssertEqual(freeProvider.summarizeCallCount, 1)
    }

    func testGenerateProfileRoutesToCorrectProvider() async throws {
        service.currentTier = .pro
        proProvider.profileResult = "user likes running"

        let result = try await service.generateProfile(prompt: "generate profile")
        XCTAssertEqual(result, "user likes running")
        XCTAssertEqual(proProvider.profileCallCount, 1)
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/EchoAIServiceTests 2>&1 | tail -20`

Expected: Compile error — `EchoAIService` not found

- [ ] **Step 3: Create EchoAIService.swift**

Create `ios/ToDay/ToDay/Data/AI/EchoAIService.swift`:

```swift
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
```

- [ ] **Step 4: Run tests — expect pass**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/EchoAIServiceTests 2>&1 | tail -20`

Expected: All 6 tests PASS

- [ ] **Step 5: Run full test suite to check no regressions**

Run: `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All existing tests still pass

- [ ] **Step 6: Commit**

```bash
cd ios/ToDay && git add ToDay/Data/AI/EchoAIService.swift ToDayTests/EchoAIServiceTests.swift
git commit -m "feat(echo-ai): add EchoAIService router with tier-based provider selection"
```

---

## Task 5: Memory SwiftData Entities

**Files:**
- Create: `ios/ToDay/ToDay/Data/AI/EchoMemoryEntities.swift`

- [ ] **Step 1: Create EchoMemoryEntities.swift**

Create `ios/ToDay/ToDay/Data/AI/EchoMemoryEntities.swift`:

```swift
import Foundation
import SwiftData

// MARK: - Layer 1: User Profile (Long-term Memory)

/// AI-generated user portrait — personality traits, habits, routines.
/// Updated weekly. Carried as context in every conversation.
@Model
final class UserProfileEntity {
    @Attribute(.unique) var id: UUID
    /// AI-generated user description (~200 chars)
    var profileText: String
    /// Last time the profile was updated
    var lastUpdatedAt: Date
    /// Number of times the profile has been regenerated
    var generationCount: Int
    /// Raw daily summary IDs used to generate this version
    var sourceSummaryIDs: [UUID]

    init(
        id: UUID = UUID(),
        profileText: String = "",
        lastUpdatedAt: Date = Date(),
        generationCount: Int = 0,
        sourceSummaryIDs: [UUID] = []
    ) {
        self.id = id
        self.profileText = profileText
        self.lastUpdatedAt = lastUpdatedAt
        self.generationCount = generationCount
        self.sourceSummaryIDs = sourceSummaryIDs
    }
}

// MARK: - Layer 2: Daily Summary (Short-term Memory)

/// One summary per day — generated at bedtime or on strong-emotion trigger.
/// Recent 7 days are included as context.
@Model
final class DailySummaryEntity {
    @Attribute(.unique) var id: UUID
    /// Date string formatted as "yyyy-MM-dd"
    var dateKey: String
    /// AI-generated summary of the day
    var summaryText: String
    /// Detected mood trend (e.g. "平静", "低落", "兴奋")
    var moodTrend: String?
    /// Key highlights extracted by AI
    var highlights: [String]
    /// When this summary was generated
    var createdAt: Date
    /// Whether this was triggered by strong emotion (vs. scheduled)
    var isEmotionTriggered: Bool

    init(
        id: UUID = UUID(),
        dateKey: String,
        summaryText: String,
        moodTrend: String? = nil,
        highlights: [String] = [],
        createdAt: Date = Date(),
        isEmotionTriggered: Bool = false
    ) {
        self.id = id
        self.dateKey = dateKey
        self.summaryText = summaryText
        self.moodTrend = moodTrend
        self.highlights = highlights
        self.createdAt = createdAt
        self.isEmotionTriggered = isEmotionTriggered
    }
}

// MARK: - Layer 4: Conversation Memory

/// Summarized history of Echo-user conversations.
/// Updated after each conversation session.
@Model
final class ConversationMemoryEntity {
    @Attribute(.unique) var id: UUID
    /// Compressed summary of conversation history (~200 chars)
    var memorySummary: String
    /// Number of conversation turns summarized
    var turnCount: Int
    /// Topics discussed (for quick lookup)
    var topics: [String]
    /// Last conversation date
    var lastConversationAt: Date
    /// When this memory was last updated
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        memorySummary: String = "",
        turnCount: Int = 0,
        topics: [String] = [],
        lastConversationAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.memorySummary = memorySummary
        self.turnCount = turnCount
        self.topics = topics
        self.lastConversationAt = lastConversationAt
        self.updatedAt = updatedAt
    }
}
```

- [ ] **Step 2: Build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED (entities are defined but not yet registered in ModelContainer — that's Task 10)

- [ ] **Step 3: Commit**

```bash
cd ios/ToDay && git add ToDay/Data/AI/EchoMemoryEntities.swift
git commit -m "feat(echo-ai): add SwiftData entities for user profile, daily summary, conversation memory"
```

---

## Task 6: EchoMemoryManager

**Files:**
- Create: `ios/ToDay/ToDay/Data/AI/EchoMemoryManager.swift`
- Create: `ios/ToDay/ToDayTests/EchoMemoryManagerTests.swift`

- [ ] **Step 1: Write tests for EchoMemoryManager**

Create `ios/ToDay/ToDayTests/EchoMemoryManagerTests.swift`:

```swift
import XCTest
import SwiftData
@testable import ToDay

final class EchoMemoryManagerTests: XCTestCase {
    private var container: ModelContainer!
    private var manager: EchoMemoryManager!

    @MainActor
    override func setUp() {
        super.setUp()
        let schema = Schema([
            UserProfileEntity.self,
            DailySummaryEntity.self,
            ConversationMemoryEntity.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        manager = EchoMemoryManager(container: container)
    }

    override func tearDown() {
        container = nil
        manager = nil
        super.tearDown()
    }

    // MARK: - User Profile

    func testSaveAndLoadUserProfile() throws {
        try manager.saveUserProfile(
            text: "这是一个热爱跑步的人",
            sourceSummaryIDs: [UUID()]
        )
        let profile = manager.loadUserProfile()
        XCTAssertNotNil(profile)
        XCTAssertEqual(profile?.profileText, "这是一个热爱跑步的人")
        XCTAssertEqual(profile?.generationCount, 1)
    }

    func testUpdateUserProfileIncrementsCount() throws {
        let summaryID = UUID()
        try manager.saveUserProfile(text: "v1", sourceSummaryIDs: [summaryID])
        try manager.saveUserProfile(text: "v2", sourceSummaryIDs: [summaryID])

        let profile = manager.loadUserProfile()
        XCTAssertEqual(profile?.profileText, "v2")
        XCTAssertEqual(profile?.generationCount, 2)
    }

    // MARK: - Daily Summary

    func testSaveAndLoadDailySummary() throws {
        try manager.saveDailySummary(
            dateKey: "2026-03-26",
            summaryText: "今天跑了 5 公里",
            moodTrend: "积极",
            highlights: ["跑步", "读书"]
        )

        let summaries = manager.loadRecentSummaries(days: 7)
        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries.first?.dateKey, "2026-03-26")
        XCTAssertEqual(summaries.first?.summaryText, "今天跑了 5 公里")
    }

    func testLoadRecentSummariesRespectsDayLimit() throws {
        for i in 1...10 {
            let dateKey = String(format: "2026-03-%02d", i)
            try manager.saveDailySummary(dateKey: dateKey, summaryText: "Day \(i)")
        }

        let recent = manager.loadRecentSummaries(days: 3)
        XCTAssertEqual(recent.count, 3)
    }

    func testUpsertDailySummaryByDateKey() throws {
        try manager.saveDailySummary(dateKey: "2026-03-26", summaryText: "v1")
        try manager.saveDailySummary(dateKey: "2026-03-26", summaryText: "v2")

        let summaries = manager.loadRecentSummaries(days: 7)
        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries.first?.summaryText, "v2")
    }

    // MARK: - Conversation Memory

    func testSaveAndLoadConversationMemory() throws {
        try manager.saveConversationMemory(
            summary: "聊了跑步和读书",
            turnCount: 5,
            topics: ["跑步", "读书"]
        )

        let memory = manager.loadConversationMemory()
        XCTAssertNotNil(memory)
        XCTAssertEqual(memory?.memorySummary, "聊了跑步和读书")
        XCTAssertEqual(memory?.turnCount, 5)
    }

    func testUpdateConversationMemoryReplaces() throws {
        try manager.saveConversationMemory(summary: "v1", turnCount: 3, topics: ["A"])
        try manager.saveConversationMemory(summary: "v2", turnCount: 8, topics: ["A", "B"])

        let memory = manager.loadConversationMemory()
        XCTAssertEqual(memory?.memorySummary, "v2")
        XCTAssertEqual(memory?.turnCount, 8)
        XCTAssertEqual(memory?.topics, ["A", "B"])
    }

    // MARK: - Delete

    func testDeleteAllMemory() throws {
        try manager.saveUserProfile(text: "test", sourceSummaryIDs: [])
        try manager.saveDailySummary(dateKey: "2026-03-26", summaryText: "test")
        try manager.saveConversationMemory(summary: "test", turnCount: 1, topics: [])

        try manager.deleteAllMemory()

        XCTAssertNil(manager.loadUserProfile())
        XCTAssertTrue(manager.loadRecentSummaries(days: 30).isEmpty)
        XCTAssertNil(manager.loadConversationMemory())
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/EchoMemoryManagerTests 2>&1 | tail -20`

Expected: Compile error — `EchoMemoryManager` not found

- [ ] **Step 3: Create EchoMemoryManager.swift**

Create `ios/ToDay/ToDay/Data/AI/EchoMemoryManager.swift`:

```swift
import Foundation
import SwiftData

/// Manages CRUD operations for Echo's four-layer memory system.
///
/// - Layer 1: User Profile (long-term, updated weekly)
/// - Layer 2: Daily Summary (short-term, updated daily)
/// - Layer 3: Today Data (real-time, sourced from existing data stores — not persisted here)
/// - Layer 4: Conversation Memory (updated after each conversation)
final class EchoMemoryManager: @unchecked Sendable {

    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    // MARK: - Layer 1: User Profile

    func loadUserProfile() -> UserProfileEntity? {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<UserProfileEntity>(
            sortBy: [SortDescriptor(\.lastUpdatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        descriptor.includePendingChanges = false
        return try? context.fetch(descriptor).first
    }

    /// Save or update the user profile. Increments generation count on update.
    func saveUserProfile(text: String, sourceSummaryIDs: [UUID]) throws {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<UserProfileEntity>(
            sortBy: [SortDescriptor(\.lastUpdatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            existing.profileText = text
            existing.lastUpdatedAt = Date()
            existing.generationCount += 1
            existing.sourceSummaryIDs = sourceSummaryIDs
        } else {
            let entity = UserProfileEntity(
                profileText: text,
                lastUpdatedAt: Date(),
                generationCount: 1,
                sourceSummaryIDs: sourceSummaryIDs
            )
            context.insert(entity)
        }

        if context.hasChanges {
            try context.save()
        }
    }

    // MARK: - Layer 2: Daily Summary

    func loadRecentSummaries(days: Int) -> [DailySummaryEntity] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<DailySummaryEntity>(
            sortBy: [SortDescriptor(\.dateKey, order: .reverse)]
        )
        descriptor.fetchLimit = days
        descriptor.includePendingChanges = false
        return (try? context.fetch(descriptor)) ?? []
    }

    func loadSummary(forDateKey dateKey: String) -> DailySummaryEntity? {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<DailySummaryEntity>(
            predicate: #Predicate { $0.dateKey == dateKey }
        )
        descriptor.fetchLimit = 1
        descriptor.includePendingChanges = false
        return try? context.fetch(descriptor).first
    }

    /// Save or upsert a daily summary. If one already exists for the dateKey, it is updated.
    func saveDailySummary(
        dateKey: String,
        summaryText: String,
        moodTrend: String? = nil,
        highlights: [String] = [],
        isEmotionTriggered: Bool = false
    ) throws {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<DailySummaryEntity>(
            predicate: #Predicate { $0.dateKey == dateKey }
        )
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            existing.summaryText = summaryText
            existing.moodTrend = moodTrend
            existing.highlights = highlights
            existing.createdAt = Date()
            existing.isEmotionTriggered = isEmotionTriggered
        } else {
            let entity = DailySummaryEntity(
                dateKey: dateKey,
                summaryText: summaryText,
                moodTrend: moodTrend,
                highlights: highlights,
                isEmotionTriggered: isEmotionTriggered
            )
            context.insert(entity)
        }

        if context.hasChanges {
            try context.save()
        }
    }

    // MARK: - Layer 4: Conversation Memory

    func loadConversationMemory() -> ConversationMemoryEntity? {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<ConversationMemoryEntity>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        descriptor.includePendingChanges = false
        return try? context.fetch(descriptor).first
    }

    /// Save or replace the conversation memory. Only one instance is kept.
    func saveConversationMemory(
        summary: String,
        turnCount: Int,
        topics: [String]
    ) throws {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<ConversationMemoryEntity>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            existing.memorySummary = summary
            existing.turnCount = turnCount
            existing.topics = topics
            existing.lastConversationAt = Date()
            existing.updatedAt = Date()
        } else {
            let entity = ConversationMemoryEntity(
                memorySummary: summary,
                turnCount: turnCount,
                topics: topics
            )
            context.insert(entity)
        }

        if context.hasChanges {
            try context.save()
        }
    }

    // MARK: - Cleanup

    /// Delete all Echo memory data (used for "reset Echo" in settings).
    func deleteAllMemory() throws {
        let context = ModelContext(container)

        let profiles = try context.fetch(FetchDescriptor<UserProfileEntity>())
        for p in profiles { context.delete(p) }

        let summaries = try context.fetch(FetchDescriptor<DailySummaryEntity>())
        for s in summaries { context.delete(s) }

        let memories = try context.fetch(FetchDescriptor<ConversationMemoryEntity>())
        for m in memories { context.delete(m) }

        if context.hasChanges {
            try context.save()
        }
    }

    /// Delete daily summaries older than a given number of days.
    func pruneOldSummaries(olderThanDays days: Int) throws {
        let calendar = Calendar.current
        guard let cutoffDate = calendar.date(byAdding: .day, value: -days, to: Date()) else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let cutoffKey = formatter.string(from: cutoffDate)

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<DailySummaryEntity>(
            predicate: #Predicate { $0.dateKey < cutoffKey }
        )
        let old = try context.fetch(descriptor)
        for entity in old {
            context.delete(entity)
        }
        if context.hasChanges {
            try context.save()
        }
    }
}
```

- [ ] **Step 4: Run tests — expect pass**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/EchoMemoryManagerTests 2>&1 | tail -20`

Expected: All 8 tests PASS

- [ ] **Step 5: Run full test suite**

Run: `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
cd ios/ToDay && git add ToDay/Data/AI/EchoMemoryManager.swift ToDayTests/EchoMemoryManagerTests.swift
git commit -m "feat(echo-ai): add EchoMemoryManager with CRUD for four-layer memory"
```

---

## Task 7: EchoPromptBuilder

**Files:**
- Create: `ios/ToDay/ToDay/Data/AI/EchoPromptBuilder.swift`
- Create: `ios/ToDay/ToDayTests/EchoPromptBuilderTests.swift`

- [ ] **Step 1: Write tests for EchoPromptBuilder**

Create `ios/ToDay/ToDayTests/EchoPromptBuilderTests.swift`:

```swift
import XCTest
import SwiftData
@testable import ToDay

final class EchoPromptBuilderTests: XCTestCase {
    private var container: ModelContainer!
    private var memoryManager: EchoMemoryManager!
    private var builder: EchoPromptBuilder!

    @MainActor
    override func setUp() {
        super.setUp()
        let schema = Schema([
            UserProfileEntity.self,
            DailySummaryEntity.self,
            ConversationMemoryEntity.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        memoryManager = EchoMemoryManager(container: container)
        builder = EchoPromptBuilder(memoryManager: memoryManager)
    }

    func testBuildSystemPromptIncludesPersonality() {
        let messages = builder.buildMessages(
            userInput: "你好",
            personality: .gentle,
            todayDataSummary: nil
        )

        let systemMessage = messages.first { $0.role == .system }
        XCTAssertNotNil(systemMessage)
        XCTAssertTrue(systemMessage!.content.contains("温和"))
    }

    func testBuildSystemPromptIncludesUserProfile() throws {
        try memoryManager.saveUserProfile(text: "热爱跑步的工程师", sourceSummaryIDs: [])

        let messages = builder.buildMessages(
            userInput: "你好",
            personality: .cheerful,
            todayDataSummary: nil
        )

        let systemMessage = messages.first { $0.role == .system }
        XCTAssertNotNil(systemMessage)
        XCTAssertTrue(systemMessage!.content.contains("热爱跑步的工程师"))
    }

    func testBuildSystemPromptIncludesDailySummaries() throws {
        try memoryManager.saveDailySummary(dateKey: "2026-03-25", summaryText: "昨天跑了 10 公里")
        try memoryManager.saveDailySummary(dateKey: "2026-03-26", summaryText: "今天去了咖啡馆")

        let messages = builder.buildMessages(
            userInput: "你好",
            personality: .rational,
            todayDataSummary: nil
        )

        let systemMessage = messages.first { $0.role == .system }
        XCTAssertNotNil(systemMessage)
        XCTAssertTrue(systemMessage!.content.contains("昨天跑了 10 公里"))
        XCTAssertTrue(systemMessage!.content.contains("今天去了咖啡馆"))
    }

    func testBuildMessagesIncludesUserInput() {
        let messages = builder.buildMessages(
            userInput: "今天状态怎么样？",
            personality: .gentle,
            todayDataSummary: nil
        )

        let userMessage = messages.last { $0.role == .user }
        XCTAssertNotNil(userMessage)
        XCTAssertEqual(userMessage!.content, "今天状态怎么样？")
    }

    func testBuildMessagesIncludesTodayData() {
        let messages = builder.buildMessages(
            userInput: "你好",
            personality: .gentle,
            todayDataSummary: "步数 8000，心率平均 72"
        )

        let systemMessage = messages.first { $0.role == .system }
        XCTAssertNotNil(systemMessage)
        XCTAssertTrue(systemMessage!.content.contains("步数 8000"))
    }

    func testBuildMessagesIncludesConversationMemory() throws {
        try memoryManager.saveConversationMemory(
            summary: "之前聊过关于跑步计划的话题",
            turnCount: 10,
            topics: ["跑步"]
        )

        let messages = builder.buildMessages(
            userInput: "你好",
            personality: .gentle,
            todayDataSummary: nil
        )

        let systemMessage = messages.first { $0.role == .system }
        XCTAssertNotNil(systemMessage)
        XCTAssertTrue(systemMessage!.content.contains("之前聊过关于跑步计划的话题"))
    }

    func testBuildSummaryPrompt() {
        let prompt = builder.buildDailySummaryPrompt(
            todayDataSummary: "步数 8000, 跑步 30 分钟, 心情：开心",
            shutterTexts: ["今天天气真好", "想去旅行"],
            moodNotes: ["开心：工作顺利"]
        )

        XCTAssertTrue(prompt.contains("步数 8000"))
        XCTAssertTrue(prompt.contains("今天天气真好"))
        XCTAssertTrue(prompt.contains("开心：工作顺利"))
    }

    func testBuildProfilePrompt() {
        let prompt = builder.buildProfileUpdatePrompt(
            currentProfile: "热爱跑步",
            recentSummaries: ["周一：跑步 5 公里", "周二：读书 2 小时", "周三：加班到 11 点"]
        )

        XCTAssertTrue(prompt.contains("热爱跑步"))
        XCTAssertTrue(prompt.contains("周一：跑步 5 公里"))
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/EchoPromptBuilderTests 2>&1 | tail -20`

Expected: Compile error — `EchoPromptBuilder` not found

- [ ] **Step 3: Create EchoPromptBuilder.swift**

Create `ios/ToDay/ToDay/Data/AI/EchoPromptBuilder.swift`:

```swift
import Foundation

/// Assembles the full prompt sent to an AI provider by combining:
/// - Personality template (system prompt prefix)
/// - User profile (Layer 1)
/// - Recent daily summaries (Layer 2)
/// - Today's data (Layer 3)
/// - Conversation memory (Layer 4)
/// - User's current input
final class EchoPromptBuilder: @unchecked Sendable {

    private let memoryManager: EchoMemoryManager

    init(memoryManager: EchoMemoryManager) {
        self.memoryManager = memoryManager
    }

    // MARK: - Chat Message Assembly

    /// Build the full message array for a chat-style AI call.
    func buildMessages(
        userInput: String,
        personality: EchoPersonality,
        todayDataSummary: String?,
        conversationHistory: [EchoChatMessage] = []
    ) -> [EchoChatMessage] {
        var messages: [EchoChatMessage] = []

        // System message with full context
        let systemContent = buildSystemPrompt(
            personality: personality,
            todayDataSummary: todayDataSummary
        )
        messages.append(EchoChatMessage(role: .system, content: systemContent))

        // Append conversation history (prior turns)
        messages.append(contentsOf: conversationHistory)

        // Current user input
        messages.append(EchoChatMessage(role: .user, content: userInput))

        return messages
    }

    // MARK: - System Prompt

    func buildSystemPrompt(
        personality: EchoPersonality,
        todayDataSummary: String?
    ) -> String {
        var parts: [String] = []

        // 1. Personality
        parts.append(personality.systemPromptPrefix)

        // 2. User Profile (Layer 1)
        if let profile = memoryManager.loadUserProfile(),
           !profile.profileText.isEmpty {
            parts.append("【用户画像】\n\(profile.profileText)")
        }

        // 3. Recent Summaries (Layer 2)
        let summaries = memoryManager.loadRecentSummaries(days: 7)
        if !summaries.isEmpty {
            let summaryTexts = summaries.map { "\($0.dateKey): \($0.summaryText)" }
            parts.append("【近期动态】\n\(summaryTexts.joined(separator: "\n"))")
        }

        // 4. Conversation Memory (Layer 4)
        if let memory = memoryManager.loadConversationMemory(),
           !memory.memorySummary.isEmpty {
            parts.append("【对话记忆】\n\(memory.memorySummary)")
        }

        // 5. Today Data (Layer 3)
        if let todayData = todayDataSummary, !todayData.isEmpty {
            parts.append("【今日数据】\n\(todayData)")
        }

        return parts.joined(separator: "\n\n")
    }

    // MARK: - Daily Summary Prompt

    /// Build a prompt for the daily summary generator.
    func buildDailySummaryPrompt(
        todayDataSummary: String,
        shutterTexts: [String],
        moodNotes: [String]
    ) -> String {
        var parts: [String] = []

        parts.append("请根据以下数据，生成一段简洁的中文日记摘要（100-150字）。摘要应包含关键活动、情绪和值得记住的细节。")

        parts.append("【健康与活动数据】\n\(todayDataSummary)")

        if !shutterTexts.isEmpty {
            parts.append("【快门记录】\n\(shutterTexts.joined(separator: "\n"))")
        }

        if !moodNotes.isEmpty {
            parts.append("【心情记录】\n\(moodNotes.joined(separator: "\n"))")
        }

        parts.append("请输出摘要正文，不需要标题或日期。同时在最后一行单独输出情绪趋势关键词（如：平静/积极/低落/混合）。")

        return parts.joined(separator: "\n\n")
    }

    // MARK: - Profile Update Prompt

    /// Build a prompt for the weekly profile updater.
    func buildProfileUpdatePrompt(
        currentProfile: String?,
        recentSummaries: [String]
    ) -> String {
        var parts: [String] = []

        parts.append("请根据以下一周的每日摘要，生成或更新用户画像。画像应描述这个人的性格特征、生活习惯、作息规律和兴趣爱好。控制在 200 字以内。")

        if let current = currentProfile, !current.isEmpty {
            parts.append("【当前画像】\n\(current)")
            parts.append("请在此基础上更新，保留准确的部分，修正不再符合的描述，补充新发现的特征。")
        } else {
            parts.append("这是首次生成画像，请尽可能从有限数据中提取特征。")
        }

        parts.append("【近期每日摘要】\n\(recentSummaries.joined(separator: "\n"))")

        parts.append("请直接输出画像文本，不需要标题。")

        return parts.joined(separator: "\n\n")
    }
}
```

- [ ] **Step 4: Run tests — expect pass**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/EchoPromptBuilderTests 2>&1 | tail -20`

Expected: All 8 tests PASS

- [ ] **Step 5: Run full test suite**

Run: `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
cd ios/ToDay && git add ToDay/Data/AI/EchoPromptBuilder.swift ToDayTests/EchoPromptBuilderTests.swift
git commit -m "feat(echo-ai): add EchoPromptBuilder for context assembly and prompt generation"
```

---

## Task 8: Daily Summary Generator

**Files:**
- Create: `ios/ToDay/ToDay/Data/AI/EchoDailySummaryGenerator.swift`
- Create: `ios/ToDay/ToDayTests/EchoDailySummaryGeneratorTests.swift`

- [ ] **Step 1: Write tests for EchoDailySummaryGenerator**

Create `ios/ToDay/ToDayTests/EchoDailySummaryGeneratorTests.swift`:

```swift
import XCTest
import SwiftData
@testable import ToDay

final class EchoDailySummaryGeneratorTests: XCTestCase {
    private var container: ModelContainer!
    private var memoryManager: EchoMemoryManager!
    private var promptBuilder: EchoPromptBuilder!
    private var mockAI: MockAIProvider!
    private var generator: EchoDailySummaryGenerator!

    @MainActor
    override func setUp() {
        super.setUp()
        let schema = Schema([
            UserProfileEntity.self,
            DailySummaryEntity.self,
            ConversationMemoryEntity.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        memoryManager = EchoMemoryManager(container: container)
        promptBuilder = EchoPromptBuilder(memoryManager: memoryManager)
        mockAI = MockAIProvider()
        generator = EchoDailySummaryGenerator(
            aiService: mockAI,
            memoryManager: memoryManager,
            promptBuilder: promptBuilder
        )
    }

    func testGenerateDailySummary() async throws {
        mockAI.summarizeResult = "今天走了 8000 步，心情平静。跑步 30 分钟，晚上早睡。\n平静"

        try await generator.generateDailySummary(
            dateKey: "2026-03-26",
            todayDataSummary: "步数 8000, 跑步 30 分钟",
            shutterTexts: ["想去旅行"],
            moodNotes: ["平静：周末放松"]
        )

        let summary = memoryManager.loadSummary(forDateKey: "2026-03-26")
        XCTAssertNotNil(summary)
        XCTAssertTrue(summary!.summaryText.contains("今天走了 8000 步"))
        XCTAssertEqual(summary!.moodTrend, "平静")
        XCTAssertEqual(mockAI.summarizeCallCount, 1)
    }

    func testGenerateDailySummaryOverwritesExisting() async throws {
        mockAI.summarizeResult = "第一版摘要\n积极"
        try await generator.generateDailySummary(
            dateKey: "2026-03-26",
            todayDataSummary: "v1",
            shutterTexts: [],
            moodNotes: []
        )

        mockAI.summarizeResult = "第二版摘要\n低落"
        try await generator.generateDailySummary(
            dateKey: "2026-03-26",
            todayDataSummary: "v2",
            shutterTexts: [],
            moodNotes: []
        )

        let summary = memoryManager.loadSummary(forDateKey: "2026-03-26")
        XCTAssertTrue(summary!.summaryText.contains("第二版摘要"))
    }

    func testParseMoodTrendFromLastLine() async throws {
        mockAI.summarizeResult = "今天状态不错，跑了步读了书。\n积极"

        try await generator.generateDailySummary(
            dateKey: "2026-03-26",
            todayDataSummary: "test",
            shutterTexts: [],
            moodNotes: []
        )

        let summary = memoryManager.loadSummary(forDateKey: "2026-03-26")
        XCTAssertEqual(summary!.moodTrend, "积极")
    }

    func testGenerateSummaryWhenAIFails() async {
        mockAI.shouldFail = true

        do {
            try await generator.generateDailySummary(
                dateKey: "2026-03-26",
                todayDataSummary: "test",
                shutterTexts: [],
                moodNotes: []
            )
            XCTFail("Expected error")
        } catch {
            // Expected: AI failure propagates
            XCTAssertTrue(error is EchoAIError)
        }

        // No summary should be saved
        let summary = memoryManager.loadSummary(forDateKey: "2026-03-26")
        XCTAssertNil(summary)
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/EchoDailySummaryGeneratorTests 2>&1 | tail -20`

Expected: Compile error — `EchoDailySummaryGenerator` not found

- [ ] **Step 3: Create EchoDailySummaryGenerator.swift**

Create `ios/ToDay/ToDay/Data/AI/EchoDailySummaryGenerator.swift`:

```swift
import Foundation

/// Generates a daily summary by feeding the day's data to AI and persisting the result.
///
/// Called at bedtime (via EchoScheduler, future task) or on strong-emotion trigger.
/// The summary is stored as a `DailySummaryEntity` and used by `EchoPromptBuilder`
/// as Layer 2 (short-term memory) context.
final class EchoDailySummaryGenerator: @unchecked Sendable {

    private let aiService: any EchoAIProviding
    private let memoryManager: EchoMemoryManager
    private let promptBuilder: EchoPromptBuilder

    init(
        aiService: any EchoAIProviding,
        memoryManager: EchoMemoryManager,
        promptBuilder: EchoPromptBuilder
    ) {
        self.aiService = aiService
        self.memoryManager = memoryManager
        self.promptBuilder = promptBuilder
    }

    /// Generate and persist a daily summary for the given date.
    ///
    /// - Parameters:
    ///   - dateKey: Date string "yyyy-MM-dd"
    ///   - todayDataSummary: Pre-formatted string of health/activity data
    ///   - shutterTexts: Text content from today's shutter records
    ///   - moodNotes: Formatted mood records ("mood: note")
    ///   - isEmotionTriggered: Whether this was triggered by a strong emotion event
    func generateDailySummary(
        dateKey: String,
        todayDataSummary: String,
        shutterTexts: [String],
        moodNotes: [String],
        isEmotionTriggered: Bool = false
    ) async throws {
        let prompt = promptBuilder.buildDailySummaryPrompt(
            todayDataSummary: todayDataSummary,
            shutterTexts: shutterTexts,
            moodNotes: moodNotes
        )

        let rawResponse = try await aiService.summarize(prompt: prompt)
        let (summaryText, moodTrend) = parseSummaryResponse(rawResponse)

        try memoryManager.saveDailySummary(
            dateKey: dateKey,
            summaryText: summaryText,
            moodTrend: moodTrend,
            highlights: extractHighlights(from: summaryText),
            isEmotionTriggered: isEmotionTriggered
        )
    }

    // MARK: - Parsing

    /// Parse the AI response: body text + mood trend on the last line.
    ///
    /// Expected format:
    /// ```
    /// 今天走了 8000 步，心情不错...
    /// 平静
    /// ```
    private func parseSummaryResponse(_ response: String) -> (summaryText: String, moodTrend: String?) {
        let lines = response.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }

        guard lines.count >= 2 else {
            return (response.trimmingCharacters(in: .whitespacesAndNewlines), nil)
        }

        let moodLine = lines.last!.trimmingCharacters(in: .whitespacesAndNewlines)
        let knownMoods = ["平静", "积极", "低落", "混合", "兴奋", "焦虑", "疲惫", "满足"]

        if knownMoods.contains(moodLine) {
            let summaryText = lines.dropLast().joined(separator: "\n")
            return (summaryText, moodLine)
        }

        return (response.trimmingCharacters(in: .whitespacesAndNewlines), nil)
    }

    /// Extract short highlights from the summary text.
    /// Simple heuristic: split by Chinese punctuation, take first few segments.
    private func extractHighlights(from text: String) -> [String] {
        let separators = CharacterSet(charactersIn: "，。；！？、")
        let segments = text.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count >= 4 }

        return Array(segments.prefix(3))
    }
}
```

- [ ] **Step 4: Run tests — expect pass**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/EchoDailySummaryGeneratorTests 2>&1 | tail -20`

Expected: All 4 tests PASS

- [ ] **Step 5: Run full test suite**

Run: `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
cd ios/ToDay && git add ToDay/Data/AI/EchoDailySummaryGenerator.swift ToDayTests/EchoDailySummaryGeneratorTests.swift
git commit -m "feat(echo-ai): add EchoDailySummaryGenerator for nightly data summarization"
```

---

## Task 9: Weekly Profile Updater

**Files:**
- Create: `ios/ToDay/ToDay/Data/AI/EchoWeeklyProfileUpdater.swift`

- [ ] **Step 1: Create EchoWeeklyProfileUpdater.swift**

Create `ios/ToDay/ToDay/Data/AI/EchoWeeklyProfileUpdater.swift`:

```swift
import Foundation

/// Updates the user profile (Layer 1 memory) from accumulated daily summaries.
///
/// Intended to run once per week (triggered by EchoScheduler, future task).
/// Takes the current profile + recent daily summaries and asks AI to generate
/// an updated portrait of the user.
final class EchoWeeklyProfileUpdater: @unchecked Sendable {

    private let aiService: any EchoAIProviding
    private let memoryManager: EchoMemoryManager
    private let promptBuilder: EchoPromptBuilder

    /// UserDefaults key for last profile update date
    private static let lastUpdateKey = "today.echo.lastProfileUpdate"

    init(
        aiService: any EchoAIProviding,
        memoryManager: EchoMemoryManager,
        promptBuilder: EchoPromptBuilder
    ) {
        self.aiService = aiService
        self.memoryManager = memoryManager
        self.promptBuilder = promptBuilder
    }

    // MARK: - Public

    /// Check if a profile update is due (7+ days since last update) and run it.
    /// Returns `true` if an update was performed.
    @discardableResult
    func updateIfNeeded() async throws -> Bool {
        guard shouldUpdate() else { return false }
        try await updateProfile()
        return true
    }

    /// Force a profile update regardless of timing.
    func updateProfile() async throws {
        let currentProfile = memoryManager.loadUserProfile()?.profileText
        let summaries = memoryManager.loadRecentSummaries(days: 7)

        guard !summaries.isEmpty else {
            // Not enough data yet — skip silently
            return
        }

        let summaryTexts = summaries.map { "\($0.dateKey): \($0.summaryText)" }
        let summaryIDs = summaries.map(\.id)

        let prompt = promptBuilder.buildProfileUpdatePrompt(
            currentProfile: currentProfile,
            recentSummaries: summaryTexts
        )

        let newProfile = try await aiService.generateProfile(prompt: prompt)

        try memoryManager.saveUserProfile(
            text: newProfile.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceSummaryIDs: summaryIDs
        )

        // Record update time
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastUpdateKey)
    }

    // MARK: - Private

    private func shouldUpdate() -> Bool {
        let lastUpdate = UserDefaults.standard.double(forKey: Self.lastUpdateKey)
        guard lastUpdate > 0 else {
            // Never updated — check if we have enough data
            let summaries = memoryManager.loadRecentSummaries(days: 3)
            return summaries.count >= 3
        }

        let lastDate = Date(timeIntervalSince1970: lastUpdate)
        let daysSinceUpdate = Calendar.current.dateComponents(
            [.day], from: lastDate, to: Date()
        ).day ?? 0

        return daysSinceUpdate >= 7
    }
}
```

- [ ] **Step 2: Build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
cd ios/ToDay && git add ToDay/Data/AI/EchoWeeklyProfileUpdater.swift
git commit -m "feat(echo-ai): add EchoWeeklyProfileUpdater for weekly user portrait generation"
```

---

## Task 10: Wire into AppContainer

**Files:**
- Modify: `ios/ToDay/ToDay/App/AppContainer.swift`

- [ ] **Step 1: Add new SwiftData entities to ModelContainer**

In `ios/ToDay/ToDay/App/AppContainer.swift`, find the `makeModelContainer()` function and add the three new entities to the `ModelContainer(for:)` call.

Find:
```swift
    private static func makeModelContainer() -> ModelContainer {
        do {
            let container = try ModelContainer(
                for: MoodRecordEntity.self,
                DayTimelineEntity.self,
                ShutterRecordEntity.self,
                SpendingRecordEntity.self,
                ScreenTimeRecordEntity.self,
                EchoItemEntity.self
            )
```

Replace with:
```swift
    private static func makeModelContainer() -> ModelContainer {
        do {
            let container = try ModelContainer(
                for: MoodRecordEntity.self,
                DayTimelineEntity.self,
                ShutterRecordEntity.self,
                SpendingRecordEntity.self,
                ScreenTimeRecordEntity.self,
                EchoItemEntity.self,
                UserProfileEntity.self,
                DailySummaryEntity.self,
                ConversationMemoryEntity.self
            )
```

- [ ] **Step 2: Add AI infrastructure singletons**

In `ios/ToDay/ToDay/App/AppContainer.swift`, after the existing `echoItemStore` line, add the AI infrastructure instances.

Find:
```swift
    private static let echoItemStore = SwiftDataEchoItemStore(container: modelContainer)
```

After that line, add:
```swift
    // MARK: - Echo AI Infrastructure
    private static let echoAIService = EchoAIService()
    private static let echoMemoryManager = EchoMemoryManager(container: modelContainer)
    private static let echoPromptBuilder = EchoPromptBuilder(memoryManager: echoMemoryManager)
    private static let echoDailySummaryGenerator = EchoDailySummaryGenerator(
        aiService: echoAIService,
        memoryManager: echoMemoryManager,
        promptBuilder: echoPromptBuilder
    )
    private static let echoWeeklyProfileUpdater = EchoWeeklyProfileUpdater(
        aiService: echoAIService,
        memoryManager: echoMemoryManager,
        promptBuilder: echoPromptBuilder
    )
```

- [ ] **Step 3: Add public accessors**

In `ios/ToDay/ToDay/App/AppContainer.swift`, after the existing `getEchoEngine()` function, add:

```swift
    static func getEchoAIService() -> EchoAIService {
        echoAIService
    }

    static func getEchoMemoryManager() -> EchoMemoryManager {
        echoMemoryManager
    }

    static func getEchoPromptBuilder() -> EchoPromptBuilder {
        echoPromptBuilder
    }

    static func getEchoDailySummaryGenerator() -> EchoDailySummaryGenerator {
        echoDailySummaryGenerator
    }

    static func getEchoWeeklyProfileUpdater() -> EchoWeeklyProfileUpdater {
        echoWeeklyProfileUpdater
    }
```

- [ ] **Step 4: Regenerate project and build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Run full test suite**

Run: `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All tests pass (including all new tests from Tasks 4, 6, 7, 8)

- [ ] **Step 6: Commit**

```bash
cd ios/ToDay && git add ToDay/App/AppContainer.swift
git commit -m "feat(echo-ai): wire AI infrastructure into AppContainer with SwiftData entities"
```
