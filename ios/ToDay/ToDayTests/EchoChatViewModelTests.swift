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

    // MARK: - todayDataSummary wiring (AIC-02)

    /// GREEN: when todayDataSummary is set on EchoChatViewModel, sendMessage must pass it
    /// through to the AI provider via buildMessages(todayDataSummary:).
    ///
    /// Mechanism: MockAIProvider.lastReceivedMessages captures the full messages array.
    /// The system message assembled by buildMessages includes 【今日数据】 when
    /// todayDataSummary is non-nil. The assertion checks that the summary text appears
    /// in the captured system message content.
    @MainActor
    func testSendMessagePassesTodayDataSummaryToPrompt() async {
        let vm = EchoChatViewModel(
            aiService: mockAI,
            memoryManager: memoryManager,
            promptBuilder: promptBuilder,
            container: container
        )
        mockAI.respondResult = "好的，我知道了。"

        // Set the live timeline summary on the VM
        vm.todayDataSummary = "步行 30 分钟，今日步数 8500"

        await vm.sendMessage("我今天走了多少步？")

        // The system message in lastReceivedMessages must contain the todayDataSummary text.
        let systemMessage = mockAI.lastReceivedMessages?.first { $0.role == .system }
        XCTAssertNotNil(systemMessage, "AI provider must receive a system message")
        XCTAssertTrue(
            systemMessage?.content.contains("步行 30 分钟") ?? false,
            "System message must contain todayDataSummary content"
        )
    }
}
