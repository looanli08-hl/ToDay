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
            ConversationMemoryEntity.self,
            DayTimelineEntity.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        memoryManager = EchoMemoryManager(container: container)
        // Pass the test container as timelineContainer so loadRecentTimelineSummaries
        // reads from our in-memory store instead of AppContainer.modelContainer singleton.
        builder = EchoPromptBuilder(memoryManager: memoryManager, timelineContainer: container)
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

    // MARK: - Pattern Insight Prompt

    func testBuildPatternInsightPromptContainsPlaceName() {
        let pattern = DetectedPattern(
            kind: .quietTime,
            placeName: "北大图书馆",
            timeOfDay: .morning,
            streakLength: 5,
            recentDates: ["2026-03-30", "2026-03-31", "2026-04-01", "2026-04-02", "2026-04-03"]
        )

        let prompt = builder.buildPatternInsightPrompt(pattern)

        XCTAssertTrue(prompt.contains("北大图书馆"), "Prompt should contain the place name")
    }

    func testBuildPatternInsightPromptContainsStreakLength() {
        let pattern = DetectedPattern(
            kind: .quietTime,
            placeName: "星巴克",
            timeOfDay: .afternoon,
            streakLength: 7,
            recentDates: []
        )

        let prompt = builder.buildPatternInsightPrompt(pattern)

        XCTAssertTrue(prompt.contains("7"), "Prompt should contain the streak length")
    }

    func testBuildPatternInsightPromptContainsMorningLabel() {
        let pattern = DetectedPattern(
            kind: .quietTime,
            placeName: "咖啡馆",
            timeOfDay: .morning,
            streakLength: 3,
            recentDates: []
        )

        let prompt = builder.buildPatternInsightPrompt(pattern)

        XCTAssertTrue(prompt.contains("早上"), "Prompt should use '早上' for morning")
    }

    func testBuildPatternInsightPromptContainsAfternoonLabel() {
        let pattern = DetectedPattern(
            kind: .quietTime,
            placeName: "图书馆",
            timeOfDay: .afternoon,
            streakLength: 3,
            recentDates: []
        )

        let prompt = builder.buildPatternInsightPrompt(pattern)

        XCTAssertTrue(prompt.contains("下午"), "Prompt should use '下午' for afternoon")
    }

    func testBuildPatternInsightPromptContainsEveningLabel() {
        let pattern = DetectedPattern(
            kind: .quietTime,
            placeName: "健身房",
            timeOfDay: .evening,
            streakLength: 4,
            recentDates: []
        )

        let prompt = builder.buildPatternInsightPrompt(pattern)

        XCTAssertTrue(prompt.contains("晚上"), "Prompt should use '晚上' for evening")
    }

    func testBuildPatternInsightPromptContainsAntiPrescriptiveInstruction() {
        let pattern = DetectedPattern(
            kind: .quietTime,
            placeName: "书房",
            timeOfDay: .evening,
            streakLength: 5,
            recentDates: []
        )

        let prompt = builder.buildPatternInsightPrompt(pattern)

        XCTAssertTrue(prompt.contains("只描述规律，不评价，不建议"), "Prompt must contain the anti-prescriptive instruction")
    }

    // MARK: - Thread Message Tests (AIC-02)

    /// GREEN: buildThreadMessages for .freeChat must include 【近期生活时间线】 in system prompt
    /// when DayTimelineEntity records exist.
    ///
    /// The builder is initialized with timelineContainer = container (test container),
    /// so loadRecentTimelineSummaries reads from the in-memory store, not the singleton.
    @MainActor
    func testBuildThreadMessagesForFreeChatIncludesTimeline() {
        // Seed a DayTimelineEntity with a non-mood entry (required for eventSummary to be non-empty)
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!
        let walkEntry = InferredEvent(
            kind: .activeWalk,
            startDate: yesterday,
            endDate: yesterday.addingTimeInterval(1800),
            confidence: .high,
            displayName: "图书馆步行"
        )
        let mockTimeline = DayTimeline(
            date: yesterday,
            summary: "昨天步行 30 分钟，去了图书馆",
            source: .mock,
            stats: [],
            entries: [walkEntry]
        )
        let entity = DayTimelineEntity(timeline: mockTimeline)
        let context = ModelContext(container)
        context.insert(entity)
        try? context.save()

        let messages = builder.buildThreadMessages(
            userInput: "我上周去哪了",
            personality: .gentle,
            sourceData: nil,
            sourceDescription: "",
            messageType: .freeChat
        )

        let systemMessage = messages.first { $0.role == .system }
        XCTAssertNotNil(systemMessage, "System message must be present")
        XCTAssertTrue(
            systemMessage?.content.contains("近期生活时间线") ?? false,
            "freeChat system prompt must contain 【近期生活时间线】 section"
        )
    }

    /// GREEN: non-freeChat threads must NOT include timeline context.
    ///
    /// Daily insight threads carry their own sourceData — no timeline injection needed.
    @MainActor
    func testBuildThreadMessagesForNonFreeChatExcludesTimeline() {
        let messages = builder.buildThreadMessages(
            userInput: "给我多说一点",
            personality: .gentle,
            sourceData: nil,
            sourceDescription: "今日洞察",
            messageType: .dailyInsight
        )

        let systemMessage = messages.first { $0.role == .system }
        XCTAssertNotNil(systemMessage, "System message must be present")
        XCTAssertFalse(
            systemMessage?.content.contains("近期生活时间线") ?? true,
            "Non-freeChat system prompt must NOT contain 【近期生活时间线】 section"
        )
    }
}
