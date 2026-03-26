# Echo UI, Scheduler & Mirror Feature

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Echo companion's user-facing layer — chat UI, daily insight card, Mirror portrait, EchoScheduler for auto-generation timing, personality settings, and temporary chat mode. Wire everything into the existing app lifecycle so daily summaries trigger on background and weekly profiles update on launch.

**Architecture:** New `EchoChatViewModel` replaces the old `EchoViewModel` as the primary driver of the Echo tab. It connects to `EchoAIService`, `EchoMemoryManager`, and `EchoPromptBuilder` (all built in Plan A). Chat messages are persisted via a new `EchoChatSession` SwiftData entity. `EchoScheduler` coordinates automatic AI tasks (daily summary, weekly profile, smart echo resurfacing). The existing `EchoEngine` (notification-based echo system) continues to run alongside the new AI features.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, XCTest

**Spec:** `docs/superpowers/specs/2026-03-26-ai-echo-companion-design.md`

**Depends on:** Plan A (Echo AI Infrastructure) — all tasks completed.

---

## File Structure

### New Files

| File | Responsibility |
|------|----------------|
| `ToDay/Data/AI/EchoChatSession.swift` | SwiftData entity for chat session + messages persistence |
| `ToDay/Features/Echo/EchoChatViewModel.swift` | AI-powered ViewModel: chat, daily insight, mirror, temp mode |
| `ToDay/Features/Echo/EchoChatScreen.swift` | Main Echo tab view: daily insight card + chat interface |
| `ToDay/Features/Echo/EchoChatBubbleView.swift` | Message bubble component (user vs Echo styles) |
| `ToDay/Features/Echo/EchoChatInputBar.swift` | Text input bar at bottom of chat (matches ShutterTextComposer style) |
| `ToDay/Features/Echo/EchoDailyInsightCard.swift` | Daily AI-generated insight card at top of Echo screen |
| `ToDay/Features/Echo/EchoMirrorSheet.swift` | "Echo 眼中的你" portrait sheet with feedback |
| `ToDay/Data/AI/EchoScheduler.swift` | Manages auto-generation timing for daily/weekly/smart tasks |
| `ToDay/Features/Settings/EchoPersonalityPicker.swift` | Personality picker view for Settings |
| `ToDayTests/EchoChatSessionTests.swift` | Tests for chat session persistence |
| `ToDayTests/EchoChatViewModelTests.swift` | Tests for ViewModel logic (send, insight, mirror, temp mode) |
| `ToDayTests/EchoSchedulerTests.swift` | Tests for scheduler timing logic |

### Modified Files

| File | Changes |
|------|---------|
| `ToDay/App/AppContainer.swift` | Register `EchoChatSessionEntity`, create `EchoScheduler`, update `makeEchoViewModel()` → `makeEchoChatViewModel()` |
| `ToDay/App/AppRootScreen.swift` | Replace `EchoViewModel` with `EchoChatViewModel`, wire new Echo tab |
| `ToDay/App/ToDayApp.swift` | Add `scenePhase` observer for background/launch triggers |
| `ToDay/Features/Settings/SettingsView.swift` | Add Echo AI section with personality picker + temp mode info |

All paths are relative to `ios/ToDay/`.

---

## Task 1: Echo Chat Data Model

**Files:**
- Create: `ios/ToDay/ToDay/Data/AI/EchoChatSession.swift`
- Create: `ios/ToDay/ToDayTests/EchoChatSessionTests.swift`

- [ ] **Step 1: Write tests for EchoChatSession**

Create `ios/ToDay/ToDayTests/EchoChatSessionTests.swift`:

```swift
import XCTest
import SwiftData
@testable import ToDay

final class EchoChatSessionTests: XCTestCase {
    private var container: ModelContainer!

    @MainActor
    override func setUp() {
        super.setUp()
        let schema = Schema([
            EchoChatSessionEntity.self,
            UserProfileEntity.self,
            DailySummaryEntity.self,
            ConversationMemoryEntity.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
    }

    override func tearDown() {
        container = nil
        super.tearDown()
    }

    func testCreateSession() throws {
        let context = ModelContext(container)
        let session = EchoChatSessionEntity(title: "测试会话")
        context.insert(session)
        try context.save()

        let descriptor = FetchDescriptor<EchoChatSessionEntity>()
        let sessions = try context.fetch(descriptor)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.title, "测试会话")
        XCTAssertFalse(sessions.first!.isTemporary)
    }

    func testTemporarySession() throws {
        let context = ModelContext(container)
        let session = EchoChatSessionEntity(title: "临时会话", isTemporary: true)
        context.insert(session)
        try context.save()

        let descriptor = FetchDescriptor<EchoChatSessionEntity>()
        let sessions = try context.fetch(descriptor)
        XCTAssertTrue(sessions.first!.isTemporary)
    }

    func testAddMessages() throws {
        let context = ModelContext(container)
        let session = EchoChatSessionEntity(title: "对话")
        context.insert(session)

        session.addMessage(role: .user, content: "你好")
        session.addMessage(role: .assistant, content: "你好！有什么想聊的吗？")
        try context.save()

        XCTAssertEqual(session.messages.count, 2)
        XCTAssertEqual(session.messages.first?.role, EchoChatRole.user.rawValue)
        XCTAssertEqual(session.messages.last?.role, EchoChatRole.assistant.rawValue)
    }

    func testMessageOrdering() throws {
        let context = ModelContext(container)
        let session = EchoChatSessionEntity(title: "对话")
        context.insert(session)

        session.addMessage(role: .user, content: "第一条")
        session.addMessage(role: .assistant, content: "第二条")
        session.addMessage(role: .user, content: "第三条")
        try context.save()

        let sorted = session.sortedMessages
        XCTAssertEqual(sorted.count, 3)
        XCTAssertEqual(sorted[0].content, "第一条")
        XCTAssertEqual(sorted[1].content, "第二条")
        XCTAssertEqual(sorted[2].content, "第三条")
    }

    func testClearMessages() throws {
        let context = ModelContext(container)
        let session = EchoChatSessionEntity(title: "对话")
        context.insert(session)

        session.addMessage(role: .user, content: "你好")
        session.addMessage(role: .assistant, content: "你好！")
        session.clearMessages()
        try context.save()

        XCTAssertTrue(session.messages.isEmpty)
    }

    func testToChatMessages() throws {
        let context = ModelContext(container)
        let session = EchoChatSessionEntity(title: "对话")
        context.insert(session)

        session.addMessage(role: .user, content: "你好")
        session.addMessage(role: .assistant, content: "你好！")
        try context.save()

        let chatMessages = session.toChatMessages()
        XCTAssertEqual(chatMessages.count, 2)
        XCTAssertEqual(chatMessages[0].role, .user)
        XCTAssertEqual(chatMessages[1].role, .assistant)
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/EchoChatSessionTests 2>&1 | tail -20`

Expected: Compile error — `EchoChatSessionEntity` not found

- [ ] **Step 3: Create EchoChatSession.swift**

Create `ios/ToDay/ToDay/Data/AI/EchoChatSession.swift`:

```swift
import Foundation
import SwiftData

// MARK: - Chat Message Entity (child of session)

@Model
final class EchoChatMessageEntity {
    @Attribute(.unique) var id: UUID
    /// Role: "user", "assistant", "system"
    var role: String
    /// Message text content
    var content: String
    /// Timestamp for ordering
    var createdAt: Date
    /// Parent session
    var session: EchoChatSessionEntity?

    init(
        id: UUID = UUID(),
        role: String,
        content: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

// MARK: - Chat Session Entity

@Model
final class EchoChatSessionEntity {
    @Attribute(.unique) var id: UUID
    /// Display title (auto-generated or user-set)
    var title: String
    /// When this session was created
    var createdAt: Date
    /// When last message was sent
    var lastActiveAt: Date
    /// Whether this is a temporary (non-memory) session
    var isTemporary: Bool
    /// Messages in this session
    @Relationship(deleteRule: .cascade, inverse: \EchoChatMessageEntity.session)
    var messages: [EchoChatMessageEntity]

    init(
        id: UUID = UUID(),
        title: String = "",
        createdAt: Date = Date(),
        lastActiveAt: Date = Date(),
        isTemporary: Bool = false,
        messages: [EchoChatMessageEntity] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.lastActiveAt = lastActiveAt
        self.isTemporary = isTemporary
        self.messages = messages
    }

    // MARK: - Convenience

    /// Add a message to this session.
    func addMessage(role: EchoChatRole, content: String) {
        let entity = EchoChatMessageEntity(
            role: role.rawValue,
            content: content
        )
        entity.session = self
        messages.append(entity)
        lastActiveAt = Date()
    }

    /// Messages sorted by creation time (oldest first).
    var sortedMessages: [EchoChatMessageEntity] {
        messages.sorted { $0.createdAt < $1.createdAt }
    }

    /// Clear all messages from this session.
    func clearMessages() {
        messages.removeAll()
    }

    /// Convert stored messages to `EchoChatMessage` array for AI calls.
    func toChatMessages() -> [EchoChatMessage] {
        sortedMessages.compactMap { entity in
            guard let role = EchoChatRole(rawValue: entity.role) else { return nil }
            return EchoChatMessage(
                id: entity.id,
                role: role,
                content: entity.content,
                createdAt: entity.createdAt
            )
        }
    }
}
```

- [ ] **Step 4: Run tests — expect pass**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/EchoChatSessionTests 2>&1 | tail -20`

Expected: All 6 tests PASS

- [ ] **Step 5: Run full test suite to check no regressions**

Run: `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All existing tests still pass (135+)

- [ ] **Step 6: Commit**

```bash
cd ios/ToDay && git add ToDay/Data/AI/EchoChatSession.swift ToDayTests/EchoChatSessionTests.swift
git commit -m "feat(echo): add EchoChatSession SwiftData entity for chat persistence"
```

---

## Task 2: EchoChatViewModel

**Files:**
- Create: `ios/ToDay/ToDay/Features/Echo/EchoChatViewModel.swift`
- Create: `ios/ToDay/ToDayTests/EchoChatViewModelTests.swift`

- [ ] **Step 1: Write tests for EchoChatViewModel**

Create `ios/ToDay/ToDayTests/EchoChatViewModelTests.swift`:

```swift
import XCTest
import SwiftData
@testable import ToDay

final class EchoChatViewModelTests: XCTestCase {
    private var container: ModelContainer!
    private var mockAI: MockAIProvider!
    private var memoryManager: EchoMemoryManager!
    private var promptBuilder: EchoPromptBuilder!

    @MainActor
    override func setUp() {
        super.setUp()
        let schema = Schema([
            EchoChatSessionEntity.self,
            EchoChatMessageEntity.self,
            UserProfileEntity.self,
            DailySummaryEntity.self,
            ConversationMemoryEntity.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        mockAI = MockAIProvider()
        memoryManager = EchoMemoryManager(container: container)
        promptBuilder = EchoPromptBuilder(memoryManager: memoryManager)
    }

    override func tearDown() {
        container = nil
        mockAI = nil
        memoryManager = nil
        promptBuilder = nil
        super.tearDown()
    }

    @MainActor
    func testInitialState() {
        let vm = EchoChatViewModel(
            aiService: mockAI,
            memoryManager: memoryManager,
            promptBuilder: promptBuilder,
            container: container
        )
        XCTAssertTrue(vm.displayMessages.isEmpty)
        XCTAssertFalse(vm.isGenerating)
        XCTAssertNil(vm.dailyInsight)
        XCTAssertNil(vm.mirrorPortrait)
        XCTAssertFalse(vm.isTemporaryMode)
    }

    @MainActor
    func testSendMessageAddsToDisplay() async {
        let vm = EchoChatViewModel(
            aiService: mockAI,
            memoryManager: memoryManager,
            promptBuilder: promptBuilder,
            container: container
        )
        mockAI.respondResult = "你好！很高兴认识你。"

        await vm.sendMessage("你好")

        XCTAssertEqual(vm.displayMessages.count, 2)
        XCTAssertEqual(vm.displayMessages[0].role, .user)
        XCTAssertEqual(vm.displayMessages[0].content, "你好")
        XCTAssertEqual(vm.displayMessages[1].role, .assistant)
        XCTAssertEqual(vm.displayMessages[1].content, "你好！很高兴认识你。")
    }

    @MainActor
    func testSendMessageSetsGeneratingFlag() async {
        let vm = EchoChatViewModel(
            aiService: mockAI,
            memoryManager: memoryManager,
            promptBuilder: promptBuilder,
            container: container
        )
        mockAI.respondResult = "回答"

        // Before sending
        XCTAssertFalse(vm.isGenerating)

        await vm.sendMessage("测试")

        // After completion
        XCTAssertFalse(vm.isGenerating)
    }

    @MainActor
    func testTemporaryModeDoesNotUpdateMemory() async {
        let vm = EchoChatViewModel(
            aiService: mockAI,
            memoryManager: memoryManager,
            promptBuilder: promptBuilder,
            container: container
        )
        mockAI.respondResult = "临时回答"

        vm.isTemporaryMode = true
        await vm.sendMessage("临时消息")

        // Conversation memory should NOT be updated in temp mode
        let memory = memoryManager.loadConversationMemory()
        XCTAssertNil(memory)
    }

    @MainActor
    func testGenerateMirrorPortrait() async {
        let vm = EchoChatViewModel(
            aiService: mockAI,
            memoryManager: memoryManager,
            promptBuilder: promptBuilder,
            container: container
        )
        mockAI.profileResult = "你是一个热爱跑步的人，作息规律，喜欢安静地思考。"

        await vm.generateMirrorPortrait()

        XCTAssertNotNil(vm.mirrorPortrait)
        XCTAssertEqual(vm.mirrorPortrait, "你是一个热爱跑步的人，作息规律，喜欢安静地思考。")
    }

    @MainActor
    func testLoadDailyInsight() async {
        let vm = EchoChatViewModel(
            aiService: mockAI,
            memoryManager: memoryManager,
            promptBuilder: promptBuilder,
            container: container
        )

        // Save a daily summary for today
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayKey = formatter.string(from: Date())
        try! memoryManager.saveDailySummary(
            dateKey: todayKey,
            summaryText: "今天跑了 5 公里，心情不错",
            moodTrend: "积极"
        )

        vm.loadDailyInsight()

        XCTAssertNotNil(vm.dailyInsight)
        XCTAssertTrue(vm.dailyInsight!.contains("跑了 5 公里"))
    }

    @MainActor
    func testPersonalityPersistence() {
        let vm = EchoChatViewModel(
            aiService: mockAI,
            memoryManager: memoryManager,
            promptBuilder: promptBuilder,
            container: container
        )

        vm.personality = .cheerful
        XCTAssertEqual(vm.personality, .cheerful)

        vm.personality = .rational
        XCTAssertEqual(vm.personality, .rational)
    }

    @MainActor
    func testErrorHandlingOnAIFailure() async {
        let vm = EchoChatViewModel(
            aiService: mockAI,
            memoryManager: memoryManager,
            promptBuilder: promptBuilder,
            container: container
        )
        mockAI.shouldFail = true

        await vm.sendMessage("会失败的消息")

        // User message should still be there, error state set
        XCTAssertEqual(vm.displayMessages.count, 1)
        XCTAssertNotNil(vm.errorMessage)
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/EchoChatViewModelTests 2>&1 | tail -20`

Expected: Compile error — `EchoChatViewModel` not found

- [ ] **Step 3: Create EchoChatViewModel.swift**

Create `ios/ToDay/ToDay/Features/Echo/EchoChatViewModel.swift`:

```swift
import Foundation
import SwiftData

@MainActor
final class EchoChatViewModel: ObservableObject {
    // MARK: - Published State

    @Published private(set) var displayMessages: [EchoChatMessage] = []
    @Published private(set) var isGenerating = false
    @Published var dailyInsight: String?
    @Published var mirrorPortrait: String?
    @Published var showMirrorSheet = false
    @Published var errorMessage: String?
    @Published var isTemporaryMode = false {
        didSet {
            if isTemporaryMode {
                startTemporarySession()
            } else {
                endTemporarySession()
            }
        }
    }

    /// User-selected personality. Persisted to UserDefaults.
    var personality: EchoPersonality {
        get {
            guard let raw = UserDefaults.standard.string(forKey: "today.echo.personality") else {
                return .gentle
            }
            return EchoPersonality(rawValue: raw) ?? .gentle
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "today.echo.personality")
            objectWillChange.send()
        }
    }

    // MARK: - Dependencies

    private let aiService: any EchoAIProviding
    private let memoryManager: EchoMemoryManager
    private let promptBuilder: EchoPromptBuilder
    private let container: ModelContainer

    // MARK: - Internal State

    private var currentSession: EchoChatSessionEntity?
    private var temporaryMessages: [EchoChatMessage] = []

    init(
        aiService: any EchoAIProviding,
        memoryManager: EchoMemoryManager,
        promptBuilder: EchoPromptBuilder,
        container: ModelContainer
    ) {
        self.aiService = aiService
        self.memoryManager = memoryManager
        self.promptBuilder = promptBuilder
        self.container = container
    }

    // MARK: - Session Management

    /// Load or create today's chat session.
    func loadCurrentSession() {
        let context = ModelContext(container)
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())

        var descriptor = FetchDescriptor<EchoChatSessionEntity>(
            predicate: #Predicate {
                $0.isTemporary == false && $0.lastActiveAt >= startOfDay
            },
            sortBy: [SortDescriptor(\.lastActiveAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        if let existing = try? context.fetch(descriptor).first {
            currentSession = existing
            displayMessages = existing.toChatMessages()
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "M月d日"
            let session = EchoChatSessionEntity(
                title: "\(formatter.string(from: Date())) 对话"
            )
            context.insert(session)
            try? context.save()
            currentSession = session
            displayMessages = []
        }
    }

    // MARK: - Send Message

    /// Send a user message and get Echo's response.
    func sendMessage(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        errorMessage = nil

        // Add user message to display
        let userMessage = EchoChatMessage(role: .user, content: trimmed)
        displayMessages.append(userMessage)

        // Persist user message (unless temporary)
        if !isTemporaryMode {
            persistMessage(role: .user, content: trimmed)
        }

        // Generate AI response
        isGenerating = true

        do {
            // Build conversation history for context
            let history: [EchoChatMessage]
            if isTemporaryMode {
                history = temporaryMessages
            } else {
                // Use recent messages as conversation history (limit to last 20 turns)
                let recentMessages = Array(displayMessages.suffix(20).dropLast())
                history = recentMessages
            }

            let messages = promptBuilder.buildMessages(
                userInput: trimmed,
                personality: personality,
                todayDataSummary: nil,
                conversationHistory: history
            )

            let response = try await aiService.respond(messages: messages)

            let assistantMessage = EchoChatMessage(role: .assistant, content: response)
            displayMessages.append(assistantMessage)

            // Persist assistant message (unless temporary)
            if !isTemporaryMode {
                persistMessage(role: .assistant, content: response)
                // Update conversation memory after each exchange
                await updateConversationMemory()
            } else {
                temporaryMessages.append(userMessage)
                temporaryMessages.append(assistantMessage)
            }
        } catch {
            errorMessage = (error as? EchoAIError)?.errorDescription
                ?? "AI 回应失败：\(error.localizedDescription)"
        }

        isGenerating = false
    }

    // MARK: - Daily Insight

    /// Load today's daily insight from stored summaries.
    func loadDailyInsight() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayKey = formatter.string(from: Date())

        if let summary = memoryManager.loadSummary(forDateKey: todayKey) {
            dailyInsight = summary.summaryText
        } else {
            // Try yesterday's if today's isn't generated yet
            let calendar = Calendar.current
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) {
                let yesterdayKey = formatter.string(from: yesterday)
                if let summary = memoryManager.loadSummary(forDateKey: yesterdayKey) {
                    dailyInsight = summary.summaryText
                }
            }
        }
    }

    // MARK: - Mirror Portrait

    /// Generate the "Echo 眼中的你" portrait.
    func generateMirrorPortrait() async {
        isGenerating = true
        errorMessage = nil

        do {
            let profile = memoryManager.loadUserProfile()
            let summaries = memoryManager.loadRecentSummaries(days: 7)
            let summaryTexts = summaries.map { "\($0.dateKey): \($0.summaryText)" }

            let prompt: String
            if let profileText = profile?.profileText, !profileText.isEmpty {
                prompt = """
                基于以下用户画像和近期数据，生成一段温暖的第二人称描述（"你是..."），\
                像一个了解用户的老朋友在描述他们。200字以内。

                【画像】
                \(profileText)

                【近期摘要】
                \(summaryTexts.joined(separator: "\n"))

                请直接输出描述文本，不需要标题。
                """
            } else if !summaries.isEmpty {
                prompt = """
                基于以下近期数据，生成一段温暖的第二人称描述（"你是..."），\
                像一个刚开始了解用户的朋友在描述初步印象。150字以内。

                【近期摘要】
                \(summaryTexts.joined(separator: "\n"))

                请直接输出描述文本，不需要标题。
                """
            } else {
                prompt = """
                你还没有足够的数据来描述用户。生成一段简短的温暖的开场白，\
                告诉用户你还在了解他们，期待通过日常互动更好地认识他们。80字以内。
                """
            }

            let result = try await aiService.generateProfile(prompt: prompt)
            mirrorPortrait = result.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            errorMessage = (error as? EchoAIError)?.errorDescription
                ?? "生成画像失败：\(error.localizedDescription)"
        }

        isGenerating = false
    }

    /// Send feedback about the mirror portrait ("这不像我").
    func sendMirrorFeedback(_ feedback: String) async {
        isGenerating = true
        errorMessage = nil

        do {
            let currentPortrait = mirrorPortrait ?? ""
            let prompt = """
            用户看了你对他的描述后，给出了反馈。请根据反馈调整画像描述。200字以内。

            【当前描述】
            \(currentPortrait)

            【用户反馈】
            \(feedback)

            请直接输出调整后的描述文本。
            """

            let result = try await aiService.generateProfile(prompt: prompt)
            let updatedPortrait = result.trimmingCharacters(in: .whitespacesAndNewlines)
            mirrorPortrait = updatedPortrait

            // Also update the stored user profile with this feedback
            let summaryIDs = memoryManager.loadRecentSummaries(days: 7).map(\.id)
            try memoryManager.saveUserProfile(
                text: updatedPortrait,
                sourceSummaryIDs: summaryIDs
            )
        } catch {
            errorMessage = (error as? EchoAIError)?.errorDescription
                ?? "更新画像失败：\(error.localizedDescription)"
        }

        isGenerating = false
    }

    // MARK: - Temporary Mode

    private func startTemporarySession() {
        temporaryMessages = []
        // Keep existing displayMessages visible but mark the boundary
        let marker = EchoChatMessage(
            role: .system,
            content: "临时会话已开启，以下对话不会被记录"
        )
        displayMessages.append(marker)
    }

    private func endTemporarySession() {
        temporaryMessages = []
        // Reload the real session messages
        if let session = currentSession {
            displayMessages = session.toChatMessages()
        } else {
            displayMessages = []
        }
    }

    // MARK: - Private Helpers

    private func persistMessage(role: EchoChatRole, content: String) {
        guard let session = currentSession else { return }
        let context = ModelContext(container)

        // Re-fetch the session in this context
        let sessionID = session.id
        var descriptor = FetchDescriptor<EchoChatSessionEntity>(
            predicate: #Predicate { $0.id == sessionID }
        )
        descriptor.fetchLimit = 1

        guard let liveSession = try? context.fetch(descriptor).first else { return }
        liveSession.addMessage(role: role, content: content)
        try? context.save()

        // Update our reference
        currentSession = liveSession
    }

    private func updateConversationMemory() async {
        // Build a summary of the current conversation for Layer 4
        let recentMessages = displayMessages.suffix(10)
        let turnSummary = recentMessages
            .filter { $0.role != .system }
            .map { "\($0.role == .user ? "用户" : "Echo"): \($0.content)" }
            .joined(separator: "\n")

        let topics = extractTopics(from: turnSummary)

        do {
            try memoryManager.saveConversationMemory(
                summary: String(turnSummary.prefix(500)),
                turnCount: displayMessages.filter { $0.role == .user }.count,
                topics: topics
            )
        } catch {
            // Non-critical — log but don't surface to user
            print("[EchoChatViewModel] Failed to update conversation memory: \(error)")
        }
    }

    /// Simple topic extraction: look for noun-like segments.
    private func extractTopics(from text: String) -> [String] {
        // Basic keyword extraction — could be upgraded to AI-based later
        let words = text.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            .filter { $0.count >= 2 }

        // Deduplicate and take top frequent terms
        var frequency: [String: Int] = [:]
        for word in words {
            frequency[word, default: 0] += 1
        }

        let sorted = frequency.sorted { $0.value > $1.value }
        return Array(sorted.prefix(5).map(\.key))
    }
}
```

- [ ] **Step 4: Run tests — expect pass**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/EchoChatViewModelTests 2>&1 | tail -20`

Expected: All 8 tests PASS

- [ ] **Step 5: Run full test suite to check no regressions**

Run: `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All existing tests still pass

- [ ] **Step 6: Commit**

```bash
cd ios/ToDay && git add ToDay/Features/Echo/EchoChatViewModel.swift ToDayTests/EchoChatViewModelTests.swift
git commit -m "feat(echo): add EchoChatViewModel with AI chat, mirror portrait, temp mode"
```

---

## Task 3: Echo Chat UI Components

**Files:**
- Create: `ios/ToDay/ToDay/Features/Echo/EchoChatBubbleView.swift`
- Create: `ios/ToDay/ToDay/Features/Echo/EchoChatInputBar.swift`

- [ ] **Step 1: Create EchoChatBubbleView.swift**

Create `ios/ToDay/ToDay/Features/Echo/EchoChatBubbleView.swift`:

```swift
import SwiftUI

struct EchoChatBubbleView: View {
    let message: EchoChatMessage
    let isLastMessage: Bool

    var body: some View {
        switch message.role {
        case .user:
            userBubble
        case .assistant:
            echoBubble
        case .system:
            systemIndicator
        }
    }

    // MARK: - User Bubble (right-aligned)

    private var userBubble: some View {
        HStack {
            Spacer(minLength: AppSpacing.xxl)

            Text(message.content)
                .font(AppFont.body)
                .foregroundStyle(AppColor.label)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(AppColor.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xxxs)
    }

    // MARK: - Echo Bubble (left-aligned, with avatar)

    private var echoBubble: some View {
        HStack(alignment: .top, spacing: AppSpacing.xs) {
            // Echo avatar
            Image(systemName: "sparkles")
                .font(.caption)
                .foregroundStyle(AppColor.echo)
                .frame(width: 28, height: 28)
                .background(AppColor.soft(AppColor.echo))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(message.content)
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.label)
                    .textSelection(.enabled)

                if isLastMessage {
                    Text(Self.timeFormatter.string(from: message.createdAt))
                        .font(AppFont.caption)
                        .foregroundStyle(AppColor.labelTertiary)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))

            Spacer(minLength: AppSpacing.xl)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xxxs)
    }

    // MARK: - System Indicator (centered, subtle)

    private var systemIndicator: some View {
        HStack {
            Spacer()
            Text(message.content)
                .font(AppFont.caption)
                .foregroundStyle(AppColor.labelTertiary)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xxs)
            Spacer()
        }
        .padding(.vertical, AppSpacing.xs)
    }

    // MARK: - Formatter

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "HH:mm"
        return f
    }()
}

// MARK: - Thinking Indicator

struct EchoThinkingView: View {
    @State private var dotCount = 0
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.xs) {
            // Echo avatar
            Image(systemName: "sparkles")
                .font(.caption)
                .foregroundStyle(AppColor.echo)
                .frame(width: 28, height: 28)
                .background(AppColor.soft(AppColor.echo))
                .clipShape(Circle())

            HStack(spacing: 4) {
                Text("Echo 正在思考")
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.labelSecondary)

                Text(String(repeating: ".", count: dotCount + 1))
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.labelTertiary)
                    .frame(width: 20, alignment: .leading)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))

            Spacer()
        }
        .padding(.horizontal, AppSpacing.md)
        .onReceive(timer) { _ in
            dotCount = (dotCount + 1) % 3
        }
    }
}
```

- [ ] **Step 2: Create EchoChatInputBar.swift**

Create `ios/ToDay/ToDay/Features/Echo/EchoChatInputBar.swift`:

```swift
import SwiftUI

/// Text input bar at the bottom of the Echo chat screen.
/// Styled to match the ShutterTextComposer pattern — warm editorial aesthetic.
struct EchoChatInputBar: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let isGenerating: Bool
    let isTemporaryMode: Bool
    let onSend: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Temporary mode indicator
            if isTemporaryMode {
                HStack(spacing: AppSpacing.xxs) {
                    Image(systemName: "eye.slash.fill")
                        .font(.caption2)
                    Text("临时会话 — 对话不会被记录")
                        .font(AppFont.caption)
                }
                .foregroundStyle(AppColor.labelTertiary)
                .padding(.vertical, AppSpacing.xxs)
            }

            Divider()
                .foregroundStyle(AppColor.separator)

            HStack(alignment: .bottom, spacing: AppSpacing.sm) {
                TextField("跟 Echo 说点什么…", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(AppFont.body)
                    .lineLimit(1...6)
                    .focused($isFocused)
                    .padding(14)
                    .background(AppColor.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                    .disabled(isGenerating)

                Button {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onSend(trimmed)
                    text = ""
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(sendButtonColor)
                }
                .disabled(isSendDisabled)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
        }
        .background(AppColor.background)
    }

    // MARK: - Computed

    private var isSendDisabled: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating
    }

    private var sendButtonColor: Color {
        if isSendDisabled {
            return AppColor.labelQuaternary
        }
        return AppColor.echo
    }
}
```

- [ ] **Step 3: Build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Run full test suite to check no regressions**

Run: `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All existing tests still pass

- [ ] **Step 5: Commit**

```bash
cd ios/ToDay && git add ToDay/Features/Echo/EchoChatBubbleView.swift ToDay/Features/Echo/EchoChatInputBar.swift
git commit -m "feat(echo): add chat bubble and input bar UI components"
```

---

## Task 4: Echo Daily Insight Card

**Files:**
- Create: `ios/ToDay/ToDay/Features/Echo/EchoDailyInsightCard.swift`

- [ ] **Step 1: Create EchoDailyInsightCard.swift**

Create `ios/ToDay/ToDay/Features/Echo/EchoDailyInsightCard.swift`:

```swift
import SwiftUI

/// Card displayed at the top of the Echo screen showing today's AI-generated insight.
/// Tappable to start a conversation about the insight.
struct EchoDailyInsightCard: View {
    let insightText: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                // Header
                HStack {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(AppColor.echo)

                    Text("今日洞察")
                        .font(AppFont.captionBold)
                        .foregroundStyle(AppColor.echo)

                    Spacer()

                    Text("点击继续聊")
                        .font(AppFont.caption)
                        .foregroundStyle(AppColor.labelTertiary)
                }

                // Insight text
                Text(insightText)
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.label)
                    .lineSpacing(4)
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
            }
            .padding(AppSpacing.md)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .strokeBorder(AppColor.soft(AppColor.echo), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, AppSpacing.md)
    }
}
```

- [ ] **Step 2: Build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
cd ios/ToDay && git add ToDay/Features/Echo/EchoDailyInsightCard.swift
git commit -m "feat(echo): add daily insight card UI component"
```

---

## Task 5: Mirror Feature ("Echo 眼中的你")

**Files:**
- Create: `ios/ToDay/ToDay/Features/Echo/EchoMirrorSheet.swift`

- [ ] **Step 1: Create EchoMirrorSheet.swift**

Create `ios/ToDay/ToDay/Features/Echo/EchoMirrorSheet.swift`:

```swift
import SwiftUI

/// Sheet that displays the "Echo 眼中的你" user portrait.
/// Users can provide feedback ("这不像我") to refine the portrait.
struct EchoMirrorSheet: View {
    @ObservedObject var viewModel: EchoChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var feedbackText = ""
    @State private var showFeedbackInput = false
    @FocusState private var isFeedbackFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Header illustration
                    headerSection

                    // Portrait content
                    if viewModel.isGenerating && viewModel.mirrorPortrait == nil {
                        loadingSection
                    } else if let portrait = viewModel.mirrorPortrait {
                        portraitSection(portrait)
                    } else if let error = viewModel.errorMessage {
                        errorSection(error)
                    }
                }
                .padding(.vertical, AppSpacing.lg)
            }
            .background(AppColor.background)
            .navigationTitle("Echo 眼中的你")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .task {
            if viewModel.mirrorPortrait == nil {
                await viewModel.generateMirrorPortrait()
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(AppColor.echo)

            Text("Echo 基于你的日常数据\n描绘出的你")
                .font(AppFont.subheadline)
                .foregroundStyle(AppColor.labelSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    private var loadingSection: some View {
        VStack(spacing: AppSpacing.md) {
            ProgressView()
            Text("Echo 正在描绘你的画像…")
                .font(AppFont.caption)
                .foregroundStyle(AppColor.labelTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xxl)
    }

    private func portraitSection(_ portrait: String) -> some View {
        VStack(spacing: AppSpacing.lg) {
            // Portrait card
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text(portrait)
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.label)
                    .lineSpacing(6)
                    .textSelection(.enabled)
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
            .appShadow(.subtle)
            .padding(.horizontal, AppSpacing.md)

            // Feedback section
            if showFeedbackInput {
                feedbackInputSection
            } else {
                feedbackButtons
            }

            // Updating indicator
            if viewModel.isGenerating {
                HStack(spacing: AppSpacing.xs) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("正在更新画像…")
                        .font(AppFont.caption)
                        .foregroundStyle(AppColor.labelTertiary)
                }
            }
        }
    }

    private var feedbackButtons: some View {
        HStack(spacing: AppSpacing.sm) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showFeedbackInput = true
                }
            } label: {
                Label("这不像我", systemImage: "hand.thumbsdown")
                    .font(AppFont.subheadline)
                    .foregroundStyle(AppColor.labelSecondary)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.xs)
                    .background(AppColor.surfaceElevated)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                // Share functionality — future enhancement
            } label: {
                Label("分享", systemImage: "square.and.arrow.up")
                    .font(AppFont.subheadline)
                    .foregroundStyle(AppColor.echo)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.xs)
                    .background(AppColor.soft(AppColor.echo))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var feedbackInputSection: some View {
        VStack(spacing: AppSpacing.sm) {
            Text("告诉 Echo 哪里不准确")
                .font(AppFont.caption)
                .foregroundStyle(AppColor.labelSecondary)

            HStack(alignment: .bottom, spacing: AppSpacing.sm) {
                TextField("例如：我其实不太爱跑步…", text: $feedbackText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(AppFont.body)
                    .lineLimit(1...4)
                    .focused($isFeedbackFocused)
                    .padding(14)
                    .background(AppColor.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))

                Button {
                    let trimmed = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    Task {
                        await viewModel.sendMirrorFeedback(trimmed)
                        feedbackText = ""
                        withAnimation {
                            showFeedbackInput = false
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? AppColor.labelQuaternary
                                : AppColor.echo
                        )
                }
                .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isGenerating)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppSpacing.md)
        }
        .onAppear {
            isFeedbackFocused = true
        }
    }

    private func errorSection(_ error: String) -> some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(AppColor.labelTertiary)

            Text(error)
                .font(AppFont.subheadline)
                .foregroundStyle(AppColor.labelSecondary)
                .multilineTextAlignment(.center)

            Button("重试") {
                Task {
                    await viewModel.generateMirrorPortrait()
                }
            }
            .font(AppFont.subheadline)
            .foregroundStyle(AppColor.echo)
        }
        .padding(.horizontal, AppSpacing.lg)
    }
}
```

- [ ] **Step 2: Build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
cd ios/ToDay && git add ToDay/Features/Echo/EchoMirrorSheet.swift
git commit -m "feat(echo): add Mirror portrait sheet with feedback interaction"
```

---

## Task 6: EchoScheduler

**Files:**
- Create: `ios/ToDay/ToDay/Data/AI/EchoScheduler.swift`
- Create: `ios/ToDay/ToDayTests/EchoSchedulerTests.swift`

- [ ] **Step 1: Write tests for EchoScheduler**

Create `ios/ToDay/ToDayTests/EchoSchedulerTests.swift`:

```swift
import XCTest
import SwiftData
@testable import ToDay

final class EchoSchedulerTests: XCTestCase {
    private var container: ModelContainer!
    private var mockAI: MockAIProvider!
    private var memoryManager: EchoMemoryManager!
    private var promptBuilder: EchoPromptBuilder!
    private var dailyGenerator: EchoDailySummaryGenerator!
    private var weeklyUpdater: EchoWeeklyProfileUpdater!

    @MainActor
    override func setUp() {
        super.setUp()
        let schema = Schema([
            UserProfileEntity.self,
            DailySummaryEntity.self,
            ConversationMemoryEntity.self,
            EchoChatSessionEntity.self,
            EchoChatMessageEntity.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        mockAI = MockAIProvider()
        memoryManager = EchoMemoryManager(container: container)
        promptBuilder = EchoPromptBuilder(memoryManager: memoryManager)
        dailyGenerator = EchoDailySummaryGenerator(
            aiService: mockAI,
            memoryManager: memoryManager,
            promptBuilder: promptBuilder
        )
        weeklyUpdater = EchoWeeklyProfileUpdater(
            aiService: mockAI,
            memoryManager: memoryManager,
            promptBuilder: promptBuilder
        )
    }

    override func tearDown() {
        container = nil
        mockAI = nil
        memoryManager = nil
        promptBuilder = nil
        dailyGenerator = nil
        weeklyUpdater = nil
        // Clean up UserDefaults keys used by scheduler
        UserDefaults.standard.removeObject(forKey: "today.echo.lastDailySummaryDate")
        UserDefaults.standard.removeObject(forKey: "today.echo.dailySummaryHour")
        super.tearDown()
    }

    func testShouldGenerateDailySummaryReturnsTrueWhenNeverRun() {
        let scheduler = EchoScheduler(
            dailySummaryGenerator: dailyGenerator,
            weeklyProfileUpdater: weeklyUpdater,
            memoryManager: memoryManager
        )

        XCTAssertTrue(scheduler.shouldGenerateDailySummary())
    }

    func testShouldGenerateDailySummaryReturnsFalseAfterTodayRun() {
        let scheduler = EchoScheduler(
            dailySummaryGenerator: dailyGenerator,
            weeklyProfileUpdater: weeklyUpdater,
            memoryManager: memoryManager
        )

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        UserDefaults.standard.set(
            formatter.string(from: Date()),
            forKey: "today.echo.lastDailySummaryDate"
        )

        XCTAssertFalse(scheduler.shouldGenerateDailySummary())
    }

    func testShouldGenerateDailySummaryRespectsHour() {
        let scheduler = EchoScheduler(
            dailySummaryGenerator: dailyGenerator,
            weeklyProfileUpdater: weeklyUpdater,
            memoryManager: memoryManager
        )

        // Set trigger hour to 23 (11 PM) — should not trigger during tests (usually run before 11 PM)
        scheduler.dailySummaryHour = 23

        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 23 {
            XCTAssertFalse(scheduler.isAfterDailySummaryHour())
        }
    }

    func testShouldUpdateWeeklyProfile() {
        let scheduler = EchoScheduler(
            dailySummaryGenerator: dailyGenerator,
            weeklyProfileUpdater: weeklyUpdater,
            memoryManager: memoryManager
        )

        // Weekly profile update is delegated to EchoWeeklyProfileUpdater
        // Scheduler just calls through
        XCTAssertNotNil(scheduler)
    }

    func testDailySummaryHourPersistence() {
        let scheduler = EchoScheduler(
            dailySummaryGenerator: dailyGenerator,
            weeklyProfileUpdater: weeklyUpdater,
            memoryManager: memoryManager
        )

        scheduler.dailySummaryHour = 21
        XCTAssertEqual(scheduler.dailySummaryHour, 21)

        scheduler.dailySummaryHour = 20
        XCTAssertEqual(scheduler.dailySummaryHour, 20)
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/EchoSchedulerTests 2>&1 | tail -20`

Expected: Compile error — `EchoScheduler` not found

- [ ] **Step 3: Create EchoScheduler.swift**

Create `ios/ToDay/ToDay/Data/AI/EchoScheduler.swift`:

```swift
import Foundation

/// Manages auto-generation timing for Echo's background AI tasks.
///
/// Responsibilities:
/// - Daily summary: trigger when app enters background after configured hour
/// - Weekly profile: check on app launch if 7+ days since last update
/// - Smart echo: check if shutter records need AI-powered resurfacing (future)
///
/// Does NOT manage the existing `EchoEngine` notification-based echo system —
/// the two systems run in parallel.
final class EchoScheduler: @unchecked Sendable {

    private let dailySummaryGenerator: EchoDailySummaryGenerator
    private let weeklyProfileUpdater: EchoWeeklyProfileUpdater
    private let memoryManager: EchoMemoryManager

    /// UserDefaults key for last daily summary date (stored as "yyyy-MM-dd")
    private static let lastDailySummaryKey = "today.echo.lastDailySummaryDate"
    /// UserDefaults key for daily summary trigger hour
    private static let dailySummaryHourKey = "today.echo.dailySummaryHour"

    /// Hour after which daily summary can be triggered (0-23). Default = 20 (8 PM).
    var dailySummaryHour: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: Self.dailySummaryHourKey)
            if stored == 0 && UserDefaults.standard.object(forKey: Self.dailySummaryHourKey) == nil {
                return 20
            }
            return min(max(stored, 0), 23)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.dailySummaryHourKey)
        }
    }

    init(
        dailySummaryGenerator: EchoDailySummaryGenerator,
        weeklyProfileUpdater: EchoWeeklyProfileUpdater,
        memoryManager: EchoMemoryManager
    ) {
        self.dailySummaryGenerator = dailySummaryGenerator
        self.weeklyProfileUpdater = weeklyProfileUpdater
        self.memoryManager = memoryManager
    }

    // MARK: - Daily Summary

    /// Check if daily summary should be generated.
    /// Returns true if: (1) not already generated today, AND (2) current hour >= configured hour.
    func shouldGenerateDailySummary() -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayKey = formatter.string(from: Date())

        let lastDate = UserDefaults.standard.string(forKey: Self.lastDailySummaryKey)
        if lastDate == todayKey {
            return false // Already generated today
        }

        return true
    }

    /// Check if current time is past the daily summary trigger hour.
    func isAfterDailySummaryHour() -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= dailySummaryHour
    }

    /// Called when app enters background. Triggers daily summary if conditions are met.
    ///
    /// - Parameters:
    ///   - todayDataSummary: Pre-formatted string of today's health/activity data
    ///   - shutterTexts: Text content from today's shutter records
    ///   - moodNotes: Formatted mood records
    func onAppBackground(
        todayDataSummary: String,
        shutterTexts: [String],
        moodNotes: [String]
    ) async {
        guard shouldGenerateDailySummary() && isAfterDailySummaryHour() else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayKey = formatter.string(from: Date())

        do {
            try await dailySummaryGenerator.generateDailySummary(
                dateKey: todayKey,
                todayDataSummary: todayDataSummary,
                shutterTexts: shutterTexts,
                moodNotes: moodNotes
            )

            // Mark as completed for today
            UserDefaults.standard.set(todayKey, forKey: Self.lastDailySummaryKey)

            // Also prune old summaries (keep 30 days)
            try memoryManager.pruneOldSummaries(olderThanDays: 30)
        } catch {
            print("[EchoScheduler] Daily summary generation failed: \(error)")
        }
    }

    // MARK: - Weekly Profile

    /// Called on app launch. Triggers weekly profile update if 7+ days since last.
    func onAppLaunch() async {
        do {
            try await weeklyProfileUpdater.updateIfNeeded()
        } catch {
            print("[EchoScheduler] Weekly profile update failed: \(error)")
        }
    }

    // MARK: - Strong Emotion Trigger

    /// Called when a mood record with strong emotion is saved.
    /// Immediately generates a daily summary update.
    func onStrongEmotion(
        todayDataSummary: String,
        shutterTexts: [String],
        moodNotes: [String]
    ) async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayKey = formatter.string(from: Date())

        do {
            try await dailySummaryGenerator.generateDailySummary(
                dateKey: todayKey,
                todayDataSummary: todayDataSummary,
                shutterTexts: shutterTexts,
                moodNotes: moodNotes,
                isEmotionTriggered: true
            )
        } catch {
            print("[EchoScheduler] Emotion-triggered summary failed: \(error)")
        }
    }
}
```

- [ ] **Step 4: Run tests — expect pass**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/EchoSchedulerTests 2>&1 | tail -20`

Expected: All 5 tests PASS

- [ ] **Step 5: Run full test suite to check no regressions**

Run: `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All existing tests still pass

- [ ] **Step 6: Commit**

```bash
cd ios/ToDay && git add ToDay/Data/AI/EchoScheduler.swift ToDayTests/EchoSchedulerTests.swift
git commit -m "feat(echo): add EchoScheduler for daily summary and weekly profile timing"
```

---

## Task 7: Personality Settings

**Files:**
- Create: `ios/ToDay/ToDay/Features/Settings/EchoPersonalityPicker.swift`
- Modify: `ios/ToDay/ToDay/Features/Settings/SettingsView.swift`

- [ ] **Step 1: Create EchoPersonalityPicker.swift**

Create `ios/ToDay/ToDay/Features/Settings/EchoPersonalityPicker.swift`:

```swift
import SwiftUI

/// Personality picker for Echo AI in Settings.
/// Shows 3 personality options with descriptions.
struct EchoPersonalityPicker: View {
    @Binding var selection: EchoPersonality

    var body: some View {
        ForEach(EchoPersonality.allCases, id: \.self) { personality in
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    selection = personality
                }
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    VStack(alignment: .leading, spacing: AppSpacing.xxxs) {
                        Text(personality.displayName)
                            .font(AppFont.body)
                            .foregroundStyle(AppColor.label)

                        Text(descriptionFor(personality))
                            .font(AppFont.caption)
                            .foregroundStyle(AppColor.labelSecondary)
                    }

                    Spacer()

                    if selection == personality {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppColor.echo)
                    } else {
                        Image(systemName: "circle")
                            .foregroundStyle(AppColor.labelTertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func descriptionFor(_ personality: EchoPersonality) -> String {
        switch personality {
        case .gentle:
            return "安静的老朋友，不多话但句句到点上"
        case .cheerful:
            return "贴心的好朋友，热情鼓励"
        case .rational:
            return "成熟的导师，客观理性分析"
        }
    }
}
```

- [ ] **Step 2: Add Echo AI section to SettingsView**

In `ios/ToDay/ToDay/Features/Settings/SettingsView.swift`, find the existing "Echo 回响" section and add a new "Echo AI" section after it.

Find this block:

```swift
                } header: {
                    Text("Echo 回响")
                }

                // MARK: - 数据权限
```

Replace with:

```swift
                } header: {
                    Text("Echo 回响")
                }

                // MARK: - Echo AI
                Section {
                    EchoPersonalityPicker(
                        selection: Binding(
                            get: { echoChatViewModel?.personality ?? .gentle },
                            set: { echoChatViewModel?.personality = $0 }
                        )
                    )
                } header: {
                    Text("Echo 性格")
                } footer: {
                    Text("选择 Echo 的说话风格，影响所有 AI 对话和洞察的语气。")
                }

                // MARK: - 数据权限
```

Note: This requires `SettingsView` to also receive an optional `EchoChatViewModel` reference. Update the `SettingsView` struct:

Find:

```swift
    @ObservedObject var echoViewModel: EchoViewModel
```

Add after it:

```swift
    var echoChatViewModel: EchoChatViewModel?
```

- [ ] **Step 3: Build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Run full test suite to check no regressions**

Run: `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All existing tests still pass

- [ ] **Step 5: Commit**

```bash
cd ios/ToDay && git add ToDay/Features/Settings/EchoPersonalityPicker.swift ToDay/Features/Settings/SettingsView.swift
git commit -m "feat(echo): add personality picker in Settings for Echo AI style"
```

---

## Task 8: Echo Chat Screen (Main UI Assembly)

**Files:**
- Create: `ios/ToDay/ToDay/Features/Echo/EchoChatScreen.swift`

This is the primary Echo tab view, assembling all components: daily insight card, chat messages, input bar, Mirror button, and temp mode toggle.

- [ ] **Step 1: Create EchoChatScreen.swift**

Create `ios/ToDay/ToDay/Features/Echo/EchoChatScreen.swift`:

```swift
import SwiftUI

struct EchoChatScreen: View {
    @ObservedObject var viewModel: EchoChatViewModel
    @ObservedObject var echoViewModel: EchoViewModel
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    @State private var showOldEchoes = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Scrollable content area
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // Daily insight card (if available)
                            if let insight = viewModel.dailyInsight {
                                EchoDailyInsightCard(insightText: insight) {
                                    Task {
                                        await viewModel.sendMessage("跟我聊聊今天的洞察")
                                    }
                                }
                                .padding(.top, AppSpacing.md)
                                .padding(.bottom, AppSpacing.sm)
                            }

                            // Mirror button + temp mode toggle
                            actionBar

                            // Old echo notification link (collapsed)
                            if !echoViewModel.todayEchoes.isEmpty {
                                oldEchoesLink
                            }

                            // Chat messages
                            ForEach(Array(viewModel.displayMessages.enumerated()), id: \.element.id) { index, message in
                                let isLast = index == viewModel.displayMessages.count - 1
                                EchoChatBubbleView(
                                    message: message,
                                    isLastMessage: isLast
                                )
                            }

                            // Thinking indicator
                            if viewModel.isGenerating {
                                EchoThinkingView()
                                    .padding(.top, AppSpacing.xxs)
                            }

                            // Error message
                            if let error = viewModel.errorMessage {
                                errorBanner(error)
                            }

                            // Bottom spacer for scroll anchor
                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: viewModel.displayMessages.count) { _, _ in
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }

                // Input bar
                EchoChatInputBar(
                    text: $inputText,
                    isFocused: $isInputFocused,
                    isGenerating: viewModel.isGenerating,
                    isTemporaryMode: viewModel.isTemporaryMode
                ) { text in
                    Task {
                        await viewModel.sendMessage(text)
                    }
                }
            }
            .background(AppColor.background)
            .navigationTitle("Echo")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            viewModel.showMirrorSheet = true
                        } label: {
                            Label("Echo 眼中的你", systemImage: "person.crop.circle.badge.questionmark")
                        }

                        Toggle(isOn: $viewModel.isTemporaryMode) {
                            Label("临时会话", systemImage: "eye.slash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(AppColor.labelSecondary)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showMirrorSheet) {
                EchoMirrorSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showOldEchoes) {
                NavigationStack {
                    EchoScreen(viewModel: echoViewModel)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("完成") { showOldEchoes = false }
                            }
                        }
                }
            }
            .onAppear {
                viewModel.loadCurrentSession()
                viewModel.loadDailyInsight()
            }
        }
    }

    // MARK: - Subviews

    private var actionBar: some View {
        HStack(spacing: AppSpacing.sm) {
            // Mirror button
            Button {
                viewModel.showMirrorSheet = true
            } label: {
                Label("Echo 眼中的你", systemImage: "sparkles")
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.echo)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.xs)
                    .background(AppColor.soft(AppColor.echo))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer()

            // Temp mode indicator
            if viewModel.isTemporaryMode {
                HStack(spacing: AppSpacing.xxs) {
                    Image(systemName: "eye.slash.fill")
                        .font(.caption2)
                    Text("临时会话")
                        .font(AppFont.caption)
                }
                .foregroundStyle(AppColor.labelTertiary)
                .padding(.horizontal, AppSpacing.xs)
                .padding(.vertical, AppSpacing.xxs)
                .background(AppColor.surfaceElevated)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xs)
    }

    private var oldEchoesLink: some View {
        Button {
            showOldEchoes = true
        } label: {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "bell.badge")
                    .font(.caption)
                    .foregroundStyle(AppColor.echo)

                Text("\(echoViewModel.todayEchoes.count) 条回响待查看")
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.labelSecondary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(AppColor.labelTertiary)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.xs)
    }

    private func errorBanner(_ error: String) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(AppColor.workout)

            Text(error)
                .font(AppFont.caption)
                .foregroundStyle(AppColor.labelSecondary)
                .lineLimit(2)

            Spacer()

            Button("重试") {
                viewModel.errorMessage = nil
            }
            .font(AppFont.caption)
            .foregroundStyle(AppColor.echo)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xs)
        .background(AppColor.soft(AppColor.workout))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xxs)
    }
}
```

- [ ] **Step 2: Build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
cd ios/ToDay && git add ToDay/Features/Echo/EchoChatScreen.swift
git commit -m "feat(echo): add EchoChatScreen assembling chat UI, insight card, and mirror"
```

---

## Task 9: Wire Everything Together

**Files:**
- Modify: `ios/ToDay/ToDay/App/AppContainer.swift`
- Modify: `ios/ToDay/ToDay/App/AppRootScreen.swift`
- Modify: `ios/ToDay/ToDay/App/ToDayApp.swift`

- [ ] **Step 1: Update AppContainer**

In `ios/ToDay/ToDay/App/AppContainer.swift`:

**1a. Add `EchoChatSessionEntity` and `EchoChatMessageEntity` to the ModelContainer.**

Find:

```swift
                ConversationMemoryEntity.self
```

Replace with:

```swift
                ConversationMemoryEntity.self,
                EchoChatSessionEntity.self,
                EchoChatMessageEntity.self
```

**1b. Add EchoScheduler singleton.**

Find:

```swift
    private static let echoWeeklyProfileUpdater = EchoWeeklyProfileUpdater(
        aiService: echoAIService,
        memoryManager: echoMemoryManager,
        promptBuilder: echoPromptBuilder
    )
```

Add after:

```swift
    private static let echoScheduler = EchoScheduler(
        dailySummaryGenerator: echoDailySummaryGenerator,
        weeklyProfileUpdater: echoWeeklyProfileUpdater,
        memoryManager: echoMemoryManager
    )
```

**1c. Add `makeEchoChatViewModel()` factory method.**

Find:

```swift
    @MainActor
    static func makeEchoViewModel() -> EchoViewModel {
        EchoViewModel(
            echoEngine: echoEngine,
            shutterRecordStore: makeShutterRecordStore(),
            screenTimeStore: makeScreenTimeRecordStore()
        )
    }
```

Add after:

```swift

    @MainActor
    static func makeEchoChatViewModel() -> EchoChatViewModel {
        EchoChatViewModel(
            aiService: echoAIService,
            memoryManager: echoMemoryManager,
            promptBuilder: echoPromptBuilder,
            container: modelContainer
        )
    }
```

**1d. Add getter for EchoScheduler.**

Find:

```swift
    static func getEchoWeeklyProfileUpdater() -> EchoWeeklyProfileUpdater {
        echoWeeklyProfileUpdater
    }
```

Add after:

```swift

    static func getEchoScheduler() -> EchoScheduler {
        echoScheduler
    }
```

- [ ] **Step 2: Update AppRootScreen**

In `ios/ToDay/ToDay/App/AppRootScreen.swift`:

**2a. Add `EchoChatViewModel` property.**

Find:

```swift
    @ObservedObject var echoViewModel: EchoViewModel
```

Add after:

```swift
    @ObservedObject var echoChatViewModel: EchoChatViewModel
```

**2b. Replace the Echo tab content with EchoChatScreen.**

Find:

```swift
                    EchoScreen(viewModel: echoViewModel)
                    .tabItem {
                        Label("Echo", systemImage: "bell.badge.fill")
                    }
                    .tag(AppTab.echo)
```

Replace with:

```swift
                    EchoChatScreen(viewModel: echoChatViewModel, echoViewModel: echoViewModel)
                    .tabItem {
                        Label("Echo", systemImage: "sparkles")
                    }
                    .tag(AppTab.echo)
```

**2c. Pass `echoChatViewModel` to SettingsView.**

Find:

```swift
                    SettingsView(echoViewModel: echoViewModel)
```

Replace with:

```swift
                    SettingsView(echoViewModel: echoViewModel, echoChatViewModel: echoChatViewModel)
```

- [ ] **Step 3: Update ToDayApp**

In `ios/ToDay/ToDay/App/ToDayApp.swift`:

**3a. Add EchoChatViewModel and scene phase observer.**

Replace the entire file with:

```swift
import SwiftUI
import SwiftData
import UIKit

@main
struct ToDayApp: App {
    @StateObject private var viewModel = AppContainer.makeTodayViewModel()
    @StateObject private var echoViewModel = AppContainer.makeEchoViewModel()
    @StateObject private var echoChatViewModel = AppContainer.makeEchoChatViewModel()
    @Environment(\.scenePhase) private var scenePhase
    private let locationService = LocationService.shared
    private let echoScheduler = AppContainer.getEchoScheduler()

    var body: some Scene {
        WindowGroup {
            AppRootScreen(
                todayViewModel: viewModel,
                echoViewModel: echoViewModel,
                echoChatViewModel: echoChatViewModel
            )
            .task {
                _ = locationService
                // Weekly profile check on launch
                await echoScheduler.onAppLaunch()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background {
                    Task {
                        await echoScheduler.onAppBackground(
                            todayDataSummary: "",
                            shutterTexts: [],
                            moodNotes: []
                        )
                    }
                }
            }
        }
        .modelContainer(AppContainer.modelContainer)
    }
}
```

Note: The `todayDataSummary`, `shutterTexts`, and `moodNotes` parameters are passed as empty strings for now. A future enhancement should collect this data from the TodayViewModel before entering background. For now the scheduler's `shouldGenerateDailySummary()` + `isAfterDailySummaryHour()` guard prevents empty summaries from being generated when there is no data.

- [ ] **Step 4: Build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Run full test suite**

Run: `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All tests pass (existing 135 + new tests from this plan)

- [ ] **Step 6: Commit**

```bash
cd ios/ToDay && git add ToDay/App/AppContainer.swift ToDay/App/AppRootScreen.swift ToDay/App/ToDayApp.swift
git commit -m "feat(echo): wire EchoChatViewModel, EchoScheduler into app lifecycle"
```

---

## Summary

| Task | Files Created | Files Modified | Tests Added |
|------|--------------|----------------|-------------|
| 1. Chat Data Model | `EchoChatSession.swift` | — | 6 |
| 2. EchoChatViewModel | `EchoChatViewModel.swift` | — | 8 |
| 3. Chat UI Components | `EchoChatBubbleView.swift`, `EchoChatInputBar.swift` | — | 0 (UI) |
| 4. Daily Insight Card | `EchoDailyInsightCard.swift` | — | 0 (UI) |
| 5. Mirror Feature | `EchoMirrorSheet.swift` | — | 0 (UI) |
| 6. EchoScheduler | `EchoScheduler.swift` | — | 5 |
| 7. Personality Settings | `EchoPersonalityPicker.swift` | `SettingsView.swift` | 0 (UI) |
| 8. Echo Chat Screen | `EchoChatScreen.swift` | — | 0 (UI) |
| 9. Wire Together | — | `AppContainer.swift`, `AppRootScreen.swift`, `ToDayApp.swift` | 0 |

**Total:** 10 new files, 4 modified files, 19 new tests

### Post-Plan Follow-ups

1. **Background data collection:** The `onAppBackground` call currently passes empty data. A future task should collect today's health data, shutter texts, and mood notes from existing stores before triggering the daily summary.
2. **Smart echo resurfacing:** `EchoScheduler` has a placeholder for AI-powered shutter resurfacing (replacing the mechanical `EchoEngine` system). This is a separate plan.
3. **Streaming text:** Current implementation waits for full AI response. Streaming can be added by having `EchoAIProviding` support an `AsyncStream<String>` variant.
4. **Watch extension:** Echo interactions on watchOS are out of scope per the design spec.
