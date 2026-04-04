import XCTest
@testable import ToDay

// MARK: - DayScrollViewTests

final class DayScrollViewTests: XCTestCase {

    // MARK: - eventRowHeightFor: min-clamp (1-minute event → 44pt)

    func testEventRowHeightMinClamp() {
        // 1 min * 0.5 = 0.5pt → clamped to 44
        let event = makeEvent(kind: .quietTime, durationMinutes: 1)
        let height = eventRowHeightFor(event: event)
        XCTAssertEqual(height, 44, "1-minute event should clamp to 44pt minimum")
    }

    // MARK: - eventRowHeightFor: proportional (240-minute event → 120pt)

    func testEventRowHeightProportional() {
        // 240 min * 0.5 = 120pt, within [44, 180]
        let event = makeEvent(kind: .quietTime, durationMinutes: 240)
        let height = eventRowHeightFor(event: event)
        XCTAssertEqual(height, 120, "240-minute event should return 120pt proportional height")
    }

    // MARK: - eventRowHeightFor: max-clamp (480-minute event → 180pt)

    func testEventRowHeightMaxClamp() {
        // 480 min * 0.5 = 240pt → clamped to 180
        let event = makeEvent(kind: .quietTime, durationMinutes: 480)
        let height = eventRowHeightFor(event: event)
        XCTAssertEqual(height, 180, "480-minute event should clamp to 180pt maximum")
    }

    // MARK: - eventRowHeightFor: sleep with stages → 92pt floor

    func testEventRowHeightSleepWithStagesFloor() {
        // 60 min * 0.5 = 30pt → base = max(44, 30) = 44, but sleep-with-stages floor = 92
        let stages = [
            SleepStageSegment(
                start: Date(),
                end: Date().addingTimeInterval(3600),
                stage: .light
            )
        ]
        let event = makeEvent(kind: .sleep, durationMinutes: 60, sleepStages: stages)
        let height = eventRowHeightFor(event: event)
        XCTAssertEqual(height, 92, "Sleep event with stages and 60min duration should return 92pt (sleep-with-stages floor)")
    }

    // MARK: - eventRowHeightFor: sleep WITHOUT stages → base proportional (no 92pt override)

    func testEventRowHeightSleepWithoutStagesNoFloor() {
        // 60 min * 0.5 = 30pt → base = max(44, 30) = 44. No stages → no 92pt override.
        let event = makeEvent(kind: .sleep, durationMinutes: 60, sleepStages: nil)
        let height = eventRowHeightFor(event: event)
        XCTAssertEqual(height, 44, "Sleep event WITHOUT stages should return base proportional height (44pt), not 92pt")
    }
}

// MARK: - Test Helpers

private func makeEvent(
    kind: EventKind = .quietTime,
    durationMinutes: Int,
    sleepStages: [SleepStageSegment]? = nil
) -> InferredEvent {
    let start = Date()
    let end = start.addingTimeInterval(TimeInterval(durationMinutes * 60))
    var metrics: EventMetrics? = nil
    if let stages = sleepStages {
        var m = EventMetrics()
        m.sleepStages = stages
        metrics = m
    }
    return InferredEvent(
        kind: kind,
        startDate: start,
        endDate: end,
        confidence: .medium,
        displayName: "Test Event",
        associatedMetrics: metrics
    )
}
