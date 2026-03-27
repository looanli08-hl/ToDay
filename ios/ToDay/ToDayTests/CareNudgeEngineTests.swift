import XCTest
@testable import ToDay

final class CareNudgeEngineTests: XCTestCase {
    func testConsecutiveWorkoutDaysReturnsEncouragement() {
        let engine = CareNudgeEngine()
        // 3 consecutive days with workouts
        let timelines = (0..<3).map { dayOffset -> DayTimeline in
            let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date())!
            let workout = InferredEvent(
                kind: .workout,
                startDate: date,
                endDate: date.addingTimeInterval(1800),
                confidence: .high,
                displayName: "跑步"
            )
            return DayTimeline(
                date: date,
                summary: "",
                source: .mock,
                stats: [],
                entries: [workout]
            )
        }

        let nudges = engine.evaluate(recentTimelines: timelines, shutterRecords: [])

        XCTAssertTrue(nudges.contains(where: { $0.kind == .exerciseStreak }))
    }

    func testHighScreenTimeReturnsReminder() {
        let engine = CareNudgeEngine()
        let today = Date()
        let screenTimeEvent = InferredEvent(
            kind: .screenTime,
            startDate: today,
            endDate: today,
            confidence: .high,
            displayName: "屏幕时间 8h"
        )
        let timeline = DayTimeline(
            date: today,
            summary: "",
            source: .mock,
            stats: [TimelineStat(title: "屏幕时间", value: "8h 0m")],
            entries: [screenTimeEvent]
        )

        let nudges = engine.evaluate(
            recentTimelines: [timeline],
            shutterRecords: [],
            screenTimeHours: 8.0
        )

        XCTAssertTrue(nudges.contains(where: { $0.kind == .highScreenTime }))
    }

    func testNoShutterRecordsForDaysReturnsCheckIn() {
        let engine = CareNudgeEngine()
        // No shutter records, 5 days of timelines
        let timelines = (0..<5).map { dayOffset -> DayTimeline in
            let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date())!
            return DayTimeline(date: date, summary: "", source: .mock, stats: [], entries: [])
        }

        let nudges = engine.evaluate(recentTimelines: timelines, shutterRecords: [])

        XCTAssertTrue(nudges.contains(where: { $0.kind == .noShutterCheckIn }))
    }

    func testNoNudgesWhenDataNormal() {
        let engine = CareNudgeEngine()
        let today = Date()
        let record = ShutterRecord(
            createdAt: today,
            type: .text,
            textContent: "Normal day"
        )
        let timeline = DayTimeline(date: today, summary: "", source: .mock, stats: [], entries: [])

        let nudges = engine.evaluate(
            recentTimelines: [timeline],
            shutterRecords: [record],
            screenTimeHours: 2.0
        )

        // Should have no nudges: only 1 day (no exercise streak), screen time normal, has shutter records
        XCTAssertFalse(nudges.contains(where: { $0.kind == .exerciseStreak }))
        XCTAssertFalse(nudges.contains(where: { $0.kind == .highScreenTime }))
        XCTAssertFalse(nudges.contains(where: { $0.kind == .noShutterCheckIn }))
    }
}
