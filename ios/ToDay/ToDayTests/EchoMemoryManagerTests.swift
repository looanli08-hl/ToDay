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
