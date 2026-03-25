import XCTest
@testable import ToDay

final class NewEventKindTests: XCTestCase {

    // MARK: - Raw Value Tests

    func testShutterKindRawValue() {
        XCTAssertEqual(EventKind.shutter.rawValue, "shutter")
    }

    func testScreenTimeKindRawValue() {
        XCTAssertEqual(EventKind.screenTime.rawValue, "screenTime")
    }

    func testSpendingKindRawValue() {
        XCTAssertEqual(EventKind.spending.rawValue, "spending")
    }

    // MARK: - Codable Tests

    func testNewKindsAreCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for kind in [EventKind.shutter, .screenTime, .spending] {
            let data = try encoder.encode(kind)
            let decoded = try decoder.decode(EventKind.self, from: data)
            XCTAssertEqual(decoded, kind)
        }
    }

    // MARK: - InferredEvent Integration Tests

    func testInferredEventWithShutterKind() {
        let now = Date()
        let event = InferredEvent(
            kind: .shutter,
            startDate: now,
            endDate: now.addingTimeInterval(60),
            confidence: .medium,
            displayName: "Photo Taken"
        )
        XCTAssertEqual(event.kind, .shutter)
    }

    func testInferredEventWithSpendingKind() {
        let now = Date()
        let event = InferredEvent(
            kind: .spending,
            startDate: now,
            endDate: now.addingTimeInterval(300),
            confidence: .low,
            displayName: "Coffee Purchase"
        )
        XCTAssertEqual(event.kind, .spending)
    }

    func testInferredEventWithScreenTimeKind() {
        let now = Date()
        let duration: TimeInterval = 1800 // 30 minutes
        let event = InferredEvent(
            kind: .screenTime,
            startDate: now,
            endDate: now.addingTimeInterval(duration),
            confidence: .high,
            displayName: "Screen Time"
        )
        XCTAssertEqual(event.kind, .screenTime)
        XCTAssertEqual(event.endDate.timeIntervalSince(event.startDate), duration, accuracy: 0.001)
    }
}
