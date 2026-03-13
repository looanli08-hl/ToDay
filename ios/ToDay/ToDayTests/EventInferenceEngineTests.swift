import XCTest
@testable import ToDay

final class EventInferenceEngineTests: XCTestCase {
    private var calendar: Calendar!
    private var engine: HealthKitEventInferenceEngine!
    private var targetDate: Date!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60) ?? .current
        engine = HealthKitEventInferenceEngine(calendar: calendar)
        targetDate = makeDate(year: 2026, month: 3, day: 12, hour: 12, minute: 0)
    }

    func testEmptyDataReturnsAllDayQuietTime() async throws {
        let events = try await infer(DayRawData(date: targetDate))

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.kind, .quietTime)
        XCTAssertEqual(events.first?.startDate, startOfDay)
        XCTAssertEqual(events.first?.endDate, endOfDay)
    }

    func testOnlySleepCreatesSleepAndQuietTime() async throws {
        let rawData = DayRawData(
            date: targetDate,
            sleepSamples: [
                SleepSample(startDate: makeDate(year: 2026, month: 3, day: 11, hour: 23, minute: 0),
                            endDate: makeDate(year: 2026, month: 3, day: 12, hour: 7, minute: 30),
                            stage: .deep)
            ]
        )

        let events = try await infer(rawData)
        let sleepEvent = try XCTUnwrap(events.first(where: { $0.kind == .sleep }))

        XCTAssertEqual(sleepEvent.startDate, startOfDay)
        XCTAssertEqual(sleepEvent.endDate, makeDate(year: 2026, month: 3, day: 12, hour: 7, minute: 30))
        XCTAssertTrue(events.contains(where: { $0.kind == .quietTime && $0.startDate >= sleepEvent.endDate }))
    }

    func testSleepStagesArePreservedInAssociatedMetrics() async throws {
        let rawData = DayRawData(
            date: targetDate,
            sleepSamples: [
                SleepSample(
                    startDate: makeDate(year: 2026, month: 3, day: 11, hour: 23, minute: 30),
                    endDate: makeDate(year: 2026, month: 3, day: 12, hour: 1, minute: 0),
                    stage: .light
                ),
                SleepSample(
                    startDate: makeDate(year: 2026, month: 3, day: 12, hour: 1, minute: 0),
                    endDate: makeDate(year: 2026, month: 3, day: 12, hour: 2, minute: 15),
                    stage: .deep
                ),
                SleepSample(
                    startDate: makeDate(year: 2026, month: 3, day: 12, hour: 2, minute: 15),
                    endDate: makeDate(year: 2026, month: 3, day: 12, hour: 3, minute: 0),
                    stage: .rem
                )
            ]
        )

        let events = try await infer(rawData)
        let sleepEvent = try XCTUnwrap(events.first(where: { $0.kind == .sleep }))
        let stages = try XCTUnwrap(sleepEvent.associatedMetrics?.sleepStages)

        XCTAssertEqual(stages.count, 3)
        XCTAssertEqual(stages[0].start, startOfDay)
        XCTAssertEqual(stages[0].end, makeDate(year: 2026, month: 3, day: 12, hour: 1, minute: 0))
        XCTAssertEqual(stages[0].stage, .light)
        XCTAssertEqual(stages[1].stage, .deep)
        XCTAssertEqual(stages[2].stage, .rem)
    }

    func testSleepAndWorkoutStayOrderedWithQuietGaps() async throws {
        let rawData = DayRawData(
            date: targetDate,
            sleepSamples: [
                SleepSample(startDate: makeDate(year: 2026, month: 3, day: 11, hour: 23, minute: 30),
                            endDate: makeDate(year: 2026, month: 3, day: 12, hour: 6, minute: 45),
                            stage: .light)
            ],
            workouts: [
                WorkoutSample(
                    startDate: makeDate(year: 2026, month: 3, day: 12, hour: 14, minute: 0),
                    endDate: makeDate(year: 2026, month: 3, day: 12, hour: 15, minute: 0),
                    activityType: "跑步",
                    activeEnergy: 420,
                    distance: 5000
                )
            ]
        )

        let events = try await infer(rawData)
        let kinds = events.map(\.kind)

        XCTAssertTrue(kinds.starts(with: [.sleep]))
        XCTAssertTrue(kinds.contains(.workout))
        let workoutIndex = try XCTUnwrap(kinds.firstIndex(of: .workout))
        XCTAssertTrue(events[..<workoutIndex].contains(where: { $0.kind == .quietTime }))
    }

    func testDenseWalkingBecomesActiveWalk() async throws {
        let rawData = DayRawData(
            date: targetDate,
            stepSamples: [
                stepSample(hour: 10, minute: 0, durationMinutes: 15, steps: 1200),
                stepSample(hour: 10, minute: 15, durationMinutes: 15, steps: 1150)
            ]
        )

        let events = try await infer(rawData)
        let walkEvent = try XCTUnwrap(events.first(where: { $0.kind == .activeWalk }))

        XCTAssertEqual(walkEvent.displayName, "活跃步行")
        XCTAssertEqual(walkEvent.confidence, .medium)
    }

    func testCommuteWindowBecomesCommute() async throws {
        let rawData = DayRawData(
            date: targetDate,
            stepSamples: [
                stepSample(hour: 7, minute: 30, durationMinutes: 15, steps: 1100),
                stepSample(hour: 7, minute: 45, durationMinutes: 15, steps: 1150)
            ]
        )

        let events = try await infer(rawData)
        let commuteEvent = try XCTUnwrap(events.first(where: { $0.kind == .commute }))

        XCTAssertEqual(commuteEvent.displayName, "步行通勤")
    }

    func testHighHeartRateWithLowCadenceBecomesQuietTime() async throws {
        let rawData = DayRawData(
            date: targetDate,
            heartRateSamples: [
                heartRateSample(hour: 6, minute: 0, durationMinutes: 10, bpm: 52),
                heartRateSample(hour: 6, minute: 30, durationMinutes: 10, bpm: 54),
                heartRateSample(hour: 11, minute: 0, durationMinutes: 15, bpm: 98),
                heartRateSample(hour: 11, minute: 15, durationMinutes: 15, bpm: 104)
            ],
            stepSamples: [
                stepSample(hour: 11, minute: 0, durationMinutes: 15, steps: 220),
                stepSample(hour: 11, minute: 15, durationMinutes: 15, steps: 260)
            ]
        )

        let events = try await infer(rawData)
        let quietEvent = try XCTUnwrap(events.first(where: {
            $0.kind == .quietTime &&
            $0.startDate == makeDate(year: 2026, month: 3, day: 12, hour: 11, minute: 0)
        }))

        XCTAssertEqual(quietEvent.confidence, .medium)
        XCTAssertTrue(quietEvent.subtitle?.contains("平均 101 bpm") == true)
    }

    func testLowHeartRateWithHighCadenceBecomesActiveWalk() async throws {
        let rawData = DayRawData(
            date: targetDate,
            heartRateSamples: [
                heartRateSample(hour: 6, minute: 0, durationMinutes: 10, bpm: 54),
                heartRateSample(hour: 6, minute: 30, durationMinutes: 10, bpm: 56),
                heartRateSample(hour: 10, minute: 0, durationMinutes: 15, bpm: 72),
                heartRateSample(hour: 10, minute: 15, durationMinutes: 15, bpm: 76)
            ],
            stepSamples: [
                stepSample(hour: 10, minute: 0, durationMinutes: 15, steps: 1180),
                stepSample(hour: 10, minute: 15, durationMinutes: 15, steps: 1140)
            ]
        )

        let events = try await infer(rawData)
        let walkEvent = try XCTUnwrap(events.first(where: {
            $0.kind == .activeWalk &&
            $0.startDate == makeDate(year: 2026, month: 3, day: 12, hour: 10, minute: 0)
        }))

        XCTAssertEqual(walkEvent.confidence, .medium)
        XCTAssertEqual(walkEvent.displayName, "活跃步行")
    }

    func testMoodRecordsAreEmbeddedAsMoodEvents() async throws {
        let mood = MoodRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000111")!,
            mood: .focused,
            note: "准备开会",
            createdAt: makeDate(year: 2026, month: 3, day: 12, hour: 9, minute: 30)
        )

        let rawData = DayRawData(date: targetDate, moodRecords: [mood])
        let events = try await infer(rawData)
        let moodEvent = try XCTUnwrap(events.first(where: { $0.kind == .mood }))

        XCTAssertEqual(moodEvent.id, mood.id)
        XCTAssertEqual(moodEvent.startDate, mood.createdAt)
        XCTAssertEqual(moodEvent.endDate, mood.createdAt)
        XCTAssertEqual(moodEvent.resolvedName, "心情：专注")
        XCTAssertEqual(moodEvent.subtitle, "准备开会")
    }

    func testIntervalEventsDoNotOverlap() async throws {
        let rawData = DayRawData(
            date: targetDate,
            stepSamples: [
                stepSample(hour: 17, minute: 30, durationMinutes: 15, steps: 1200),
                stepSample(hour: 17, minute: 45, durationMinutes: 15, steps: 1200)
            ],
            sleepSamples: [
                SleepSample(startDate: makeDate(year: 2026, month: 3, day: 11, hour: 22, minute: 30),
                            endDate: makeDate(year: 2026, month: 3, day: 12, hour: 6, minute: 30),
                            stage: .rem)
            ],
            workouts: [
                WorkoutSample(startDate: makeDate(year: 2026, month: 3, day: 12, hour: 14, minute: 0),
                              endDate: makeDate(year: 2026, month: 3, day: 12, hour: 15, minute: 0),
                              activityType: "跑步")
            ],
            moodRecords: [
                MoodRecord(mood: .happy, createdAt: makeDate(year: 2026, month: 3, day: 12, hour: 20, minute: 0))
            ]
        )

        let intervalEvents = try await infer(rawData)
            .filter { $0.kind != .mood && $0.duration > 0 }

        for pair in zip(intervalEvents, intervalEvents.dropFirst()) {
            XCTAssertLessThanOrEqual(pair.0.endDate, pair.1.startDate)
        }
    }

    func testShortQuietFragmentsAreFilteredOut() async throws {
        let rawData = DayRawData(
            date: targetDate,
            workouts: [
                WorkoutSample(startDate: makeDate(year: 2026, month: 3, day: 12, hour: 11, minute: 0),
                              endDate: makeDate(year: 2026, month: 3, day: 12, hour: 11, minute: 58),
                              activityType: "力量训练"),
                WorkoutSample(startDate: makeDate(year: 2026, month: 3, day: 12, hour: 12, minute: 2),
                              endDate: makeDate(year: 2026, month: 3, day: 12, hour: 13, minute: 0),
                              activityType: "走路")
            ]
        )

        let events = try await infer(rawData)
        let shortQuiet = events.first {
            $0.kind == .quietTime && $0.duration > 0 && $0.duration < 5 * 60
        }

        XCTAssertNil(shortQuiet)
    }

    func testAdjacentQuietTimesMergeWhenShortEnough() async throws {
        let rawData = DayRawData(
            date: targetDate,
            workouts: [
                WorkoutSample(startDate: makeDate(year: 2026, month: 3, day: 12, hour: 10, minute: 0),
                              endDate: makeDate(year: 2026, month: 3, day: 12, hour: 11, minute: 0),
                              activityType: "快走"),
                WorkoutSample(startDate: makeDate(year: 2026, month: 3, day: 12, hour: 12, minute: 30),
                              endDate: makeDate(year: 2026, month: 3, day: 12, hour: 13, minute: 0),
                              activityType: "快走")
            ]
        )

        let events = try await infer(rawData)
        let mergedQuiet = try XCTUnwrap(
            events.first(where: {
                $0.kind == .quietTime &&
                $0.startDate == makeDate(year: 2026, month: 3, day: 12, hour: 11, minute: 0)
            })
        )

        XCTAssertEqual(mergedQuiet.endDate, makeDate(year: 2026, month: 3, day: 12, hour: 12, minute: 30))
    }

    func testCrossMidnightSleepIsClippedToCurrentDay() async throws {
        let rawData = DayRawData(
            date: targetDate,
            sleepSamples: [
                SleepSample(startDate: makeDate(year: 2026, month: 3, day: 11, hour: 22, minute: 0),
                            endDate: makeDate(year: 2026, month: 3, day: 12, hour: 7, minute: 15),
                            stage: .deep)
            ]
        )

        let events = try await infer(rawData)
        let sleepEvent = try XCTUnwrap(events.first(where: { $0.kind == .sleep }))

        XCTAssertEqual(sleepEvent.startDate, startOfDay)
        XCTAssertEqual(sleepEvent.endDate, makeDate(year: 2026, month: 3, day: 12, hour: 7, minute: 15))
    }

    private var startOfDay: Date {
        calendar.startOfDay(for: targetDate)
    }

    private var endOfDay: Date {
        calendar.date(byAdding: .day, value: 1, to: startOfDay)!
    }

    private func infer(_ rawData: DayRawData) async throws -> [InferredEvent] {
        try await engine.inferEvents(from: rawData, on: targetDate)
    }

    private func stepSample(hour: Int, minute: Int, durationMinutes: Int, steps: Double) -> DateValueSample {
        let start = makeDate(year: 2026, month: 3, day: 12, hour: hour, minute: minute)
        let end = calendar.date(byAdding: .minute, value: durationMinutes, to: start)!
        return DateValueSample(startDate: start, endDate: end, value: steps)
    }

    private func heartRateSample(hour: Int, minute: Int, durationMinutes: Int, bpm: Double) -> DateValueSample {
        let start = makeDate(year: 2026, month: 3, day: 12, hour: hour, minute: minute)
        let end = calendar.date(byAdding: .minute, value: durationMinutes, to: start)!
        return DateValueSample(startDate: start, endDate: end, value: bpm)
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }
}
