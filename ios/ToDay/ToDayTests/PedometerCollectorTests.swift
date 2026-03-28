import XCTest
@testable import ToDay

final class PedometerCollectorTests: XCTestCase {
    func testSensorType() {
        let collector = PedometerCollector()
        XCTAssertEqual(collector.sensorType, .pedometer)
    }

    func testSegmentHours() {
        let base = Calendar.current.startOfDay(for: Date())
        let segments = PedometerCollector.hourSegments(for: base)
        XCTAssertEqual(segments.count, 24)
        XCTAssertEqual(segments[0].start, base)
        XCTAssertEqual(segments[0].end, base.addingTimeInterval(3600))
        XCTAssertEqual(segments[23].end, base.addingTimeInterval(86400))
    }
}
