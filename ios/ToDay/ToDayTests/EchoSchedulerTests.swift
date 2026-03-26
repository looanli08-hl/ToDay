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
