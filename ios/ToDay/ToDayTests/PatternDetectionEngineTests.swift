import XCTest
import SwiftData
@testable import ToDay

final class PatternDetectionEngineTests: XCTestCase {
    private var container: ModelContainer!

    @MainActor
    override func setUp() {
        super.setUp()
        let schema = Schema([
            DayTimelineEntity.self,
            DailySummaryEntity.self,
            UserProfileEntity.self,
            ConversationMemoryEntity.self,
            EchoChatSessionEntity.self,
            EchoChatMessageEntity.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
    }

    override func tearDown() {
        container = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// Creates and saves a DayTimelineEntity with the given dateKey and events.
    @MainActor
    private func makeDayTimeline(dateKey: String, events: [InferredEvent]) {
        let context = ModelContext(container)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let date = formatter.date(from: dateKey)!
        let timeline = DayTimeline(
            date: date,
            summary: "",
            source: .phone,
            stats: [],
            entries: events
        )
        let entity = DayTimelineEntity(timeline: timeline)
        context.insert(entity)
        try? context.save()
    }

    /// Creates and saves a DailySummaryEntity with the given dateKey.
    @MainActor
    private func makeDailySummary(dateKey: String) {
        let context = ModelContext(container)
        let entity = DailySummaryEntity(
            dateKey: dateKey,
            summaryText: "Summary for \(dateKey)"
        )
        context.insert(entity)
        try? context.save()
    }

    /// Creates an InferredEvent of kind .quietTime at a given hour on a specific day.
    private func makeQuietTimeEvent(
        dateKey: String,
        hour: Int,
        displayName: String
    ) -> InferredEvent {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let dayStart = formatter.date(from: dateKey)!
        var components = Calendar.current.dateComponents([.year, .month, .day], from: dayStart)
        components.hour = hour
        components.minute = 0
        let startDate = Calendar.current.date(from: components)!
        let endDate = startDate.addingTimeInterval(3600) // 1 hour
        return InferredEvent(
            kind: .quietTime,
            startDate: startDate,
            endDate: endDate,
            confidence: .high,
            displayName: displayName
        )
    }

    // MARK: - Test 1: detectBestPattern returns streak of 3 for same (displayName, timeOfDayBucket)

    @MainActor
    func testDetectBestPatternReturnsStreakOfThree() {
        let context = ModelContext(container)
        let engine = PatternDetectionEngine()

        // Insert 21+ daily summaries so hasSufficientData passes
        for i in 0..<21 {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            let date = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            makeDailySummary(dateKey: formatter.string(from: date))
        }

        // Insert 3 consecutive days with same quietTime event at the library in the afternoon
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for i in 0..<3 {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: today)!
            let dateKey = formatter.string(from: date)
            let event = makeQuietTimeEvent(dateKey: dateKey, hour: 14, displayName: "北大图书馆")
            makeDayTimeline(dateKey: dateKey, events: [event])
        }

        let pattern = engine.detectBestPattern(context: context)

        XCTAssertNotNil(pattern, "Expected a pattern to be detected for 3 consecutive days at the same place")
        XCTAssertEqual(pattern?.streakLength, 3)
        XCTAssertEqual(pattern?.placeName, "北大图书馆")
        XCTAssertEqual(pattern?.timeOfDay, .afternoon)
    }

    // MARK: - Test 2: detectBestPattern returns nil when no streak meets minimum

    @MainActor
    func testDetectBestPatternReturnsNilWhenNoStreakMeetsMinimum() {
        let context = ModelContext(container)
        let engine = PatternDetectionEngine()

        // Insert 21+ daily summaries
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for i in 0..<21 {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            makeDailySummary(dateKey: formatter.string(from: date))
        }

        // Insert only 2 consecutive days at library (below minimum of 3)
        let today = Date()
        for i in 0..<2 {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: today)!
            let dateKey = formatter.string(from: date)
            let event = makeQuietTimeEvent(dateKey: dateKey, hour: 14, displayName: "星巴克")
            makeDayTimeline(dateKey: dateKey, events: [event])
        }

        let pattern = engine.detectBestPattern(context: context)

        XCTAssertNil(pattern, "Expected nil when streak is below minimum threshold (only 2 days)")
    }

    // MARK: - Test 3: detectBestPattern filters out "未知地点"

    @MainActor
    func testDetectBestPatternFiltersOutUnknownPlace() {
        let context = ModelContext(container)
        let engine = PatternDetectionEngine()

        // Insert 21+ daily summaries
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for i in 0..<21 {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            makeDailySummary(dateKey: formatter.string(from: date))
        }

        // Insert 3 consecutive days at "未知地点" — should be filtered
        let today = Date()
        for i in 0..<3 {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: today)!
            let dateKey = formatter.string(from: date)
            let event = makeQuietTimeEvent(dateKey: dateKey, hour: 14, displayName: "未知地点")
            makeDayTimeline(dateKey: dateKey, events: [event])
        }

        let pattern = engine.detectBestPattern(context: context)

        XCTAssertNil(pattern, "Expected nil when all matching events have blocklisted displayName '未知地点'")
    }

    // MARK: - Test 4: hasSufficientData returns false for 20 summaries

    @MainActor
    func testHasSufficientDataReturnsFalseFor20() {
        let context = ModelContext(container)
        let engine = PatternDetectionEngine()

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for i in 0..<20 {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            makeDailySummary(dateKey: formatter.string(from: date))
        }

        XCTAssertFalse(engine.hasSufficientData(context: context), "Expected false for 20 summaries (below threshold of 21)")
    }

    // MARK: - Test 5: hasSufficientData returns true for 21 summaries

    @MainActor
    func testHasSufficientDataReturnsTrueFor21() {
        let context = ModelContext(container)
        let engine = PatternDetectionEngine()

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for i in 0..<21 {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            makeDailySummary(dateKey: formatter.string(from: date))
        }

        XCTAssertTrue(engine.hasSufficientData(context: context), "Expected true for 21 summaries (meets threshold)")
    }

    // MARK: - Test 6: detectBestPattern returns nil when data is insufficient

    @MainActor
    func testDetectBestPatternReturnsNilWhenDataInsufficient() {
        let context = ModelContext(container)
        let engine = PatternDetectionEngine()

        // Only 5 daily summaries — insufficient
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for i in 0..<5 {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            makeDailySummary(dateKey: formatter.string(from: date))
        }

        // Insert 3 consecutive days with valid events (would match if data were sufficient)
        let today = Date()
        for i in 0..<3 {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: today)!
            let dateKey = formatter.string(from: date)
            let event = makeQuietTimeEvent(dateKey: dateKey, hour: 9, displayName: "咖啡馆")
            makeDayTimeline(dateKey: dateKey, events: [event])
        }

        let pattern = engine.detectBestPattern(context: context)

        XCTAssertNil(pattern, "Expected nil when hasSufficientData is false (only 5 summaries)")
    }

    // MARK: - Test 7: TimeOfDayBucket.from(hour:) returns correct buckets

    func testTimeOfDayBucketFromHour() {
        XCTAssertEqual(TimeOfDayBucket.from(hour: 9), .morning, "Hour 9 should be .morning")
        XCTAssertEqual(TimeOfDayBucket.from(hour: 14), .afternoon, "Hour 14 should be .afternoon")
        XCTAssertEqual(TimeOfDayBucket.from(hour: 20), .evening, "Hour 20 should be .evening")
        // Boundary checks
        XCTAssertEqual(TimeOfDayBucket.from(hour: 6), .morning, "Hour 6 should be .morning")
        XCTAssertEqual(TimeOfDayBucket.from(hour: 11), .morning, "Hour 11 should be .morning")
        XCTAssertEqual(TimeOfDayBucket.from(hour: 12), .afternoon, "Hour 12 should be .afternoon")
        XCTAssertEqual(TimeOfDayBucket.from(hour: 17), .afternoon, "Hour 17 should be .afternoon")
        XCTAssertEqual(TimeOfDayBucket.from(hour: 18), .evening, "Hour 18 should be .evening")
        XCTAssertEqual(TimeOfDayBucket.from(hour: 0), .evening, "Hour 0 should be .evening")
        XCTAssertEqual(TimeOfDayBucket.from(hour: 5), .evening, "Hour 5 should be .evening")
    }
}
