import XCTest
@testable import ToDay

final class MotionCollectorTests: XCTestCase {
    func testSensorType() {
        let collector = MotionCollector()
        XCTAssertEqual(collector.sensorType, .motion)
    }

    func testMapCMMotionActivity() {
        XCTAssertEqual(MotionCollector.mapActivity(stationary: true, walking: false, running: false, automotive: false, cycling: false), .stationary)
        XCTAssertEqual(MotionCollector.mapActivity(stationary: false, walking: true, running: false, automotive: false, cycling: false), .walking)
        XCTAssertEqual(MotionCollector.mapActivity(stationary: false, walking: false, running: true, automotive: false, cycling: false), .running)
        XCTAssertEqual(MotionCollector.mapActivity(stationary: false, walking: false, running: false, automotive: true, cycling: false), .automotive)
        XCTAssertEqual(MotionCollector.mapActivity(stationary: false, walking: false, running: false, automotive: false, cycling: true), .cycling)
        XCTAssertEqual(MotionCollector.mapActivity(stationary: false, walking: false, running: false, automotive: false, cycling: false), .unknown)
    }

    func testMapCMMotionConfidence() {
        XCTAssertEqual(MotionCollector.mapConfidence(0), .low)
        XCTAssertEqual(MotionCollector.mapConfidence(1), .medium)
        XCTAssertEqual(MotionCollector.mapConfidence(2), .high)
    }
}
