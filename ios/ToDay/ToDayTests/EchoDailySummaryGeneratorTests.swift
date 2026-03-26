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
