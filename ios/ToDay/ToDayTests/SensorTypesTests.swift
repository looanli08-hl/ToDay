import XCTest
@testable import ToDay

final class SensorTypesTests: XCTestCase {
    func testSensorReadingCodable() throws {
        let reading = SensorReading(
            id: UUID(),
            sensorType: .motion,
            timestamp: Date(),
            endTimestamp: Date().addingTimeInterval(300),
            payload: .motion(activity: .walking, confidence: .high)
        )
        let data = try JSONEncoder().encode(reading)
        let decoded = try JSONDecoder().decode(SensorReading.self, from: data)
        XCTAssertEqual(decoded.id, reading.id)
        XCTAssertEqual(decoded.sensorType, .motion)
        if case .motion(let activity, let confidence) = decoded.payload {
            XCTAssertEqual(activity, .walking)
            XCTAssertEqual(confidence, .high)
        } else {
            XCTFail("Expected motion payload")
        }
    }

    func testAllPayloadTypesCodable() throws {
        let payloads: [SensorPayload] = [
            .motion(activity: .running, confidence: .medium),
            .location(latitude: 31.23, longitude: 121.47, horizontalAccuracy: 10),
            .visit(latitude: 31.23, longitude: 121.47, arrivalDate: Date(), departureDate: Date()),
            .pedometer(steps: 1000, distance: 800, floorsAscended: 2),
            .deviceState(event: .screenUnlock),
            .healthKit(metric: "heartRate", value: 72),
        ]
        for payload in payloads {
            let reading = SensorReading(
                id: UUID(), sensorType: .motion, timestamp: Date(),
                endTimestamp: nil, payload: payload
            )
            let data = try JSONEncoder().encode(reading)
            let decoded = try JSONDecoder().decode(SensorReading.self, from: data)
            XCTAssertEqual(decoded.id, reading.id)
        }
    }

    func testMotionActivityAllCases() {
        let cases: [MotionActivity] = [.stationary, .walking, .running, .automotive, .cycling, .unknown]
        XCTAssertEqual(cases.count, 6)
    }

    func testDeviceEventAllCases() {
        let cases: [DeviceEvent] = [.screenUnlock, .screenLock, .chargingStart, .chargingStop]
        XCTAssertEqual(cases.count, 4)
    }
}
