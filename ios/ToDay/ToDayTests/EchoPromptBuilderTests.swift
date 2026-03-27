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
