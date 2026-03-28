import XCTest
@testable import ToDay

final class PhoneInferenceEngineTests: XCTestCase {
    private let engine = PhoneInferenceEngine()
    private let calendar = Calendar.current

    private func makeDate(hour: Int, minute: Int = 0) -> Date {
        let today = calendar.startOfDay(for: Date())
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today)!
    }

    func testSleepInference() {
        let readings: [SensorReading] = [
            SensorReading(sensorType: .deviceState, timestamp: makeDate(hour: 23, minute: 0),
                          payload: .deviceState(event: .screenLock)),
            SensorReading(sensorType: .deviceState, timestamp: makeDate(hour: 23, minute: 5),
                          payload: .deviceState(event: .chargingStart)),
            SensorReading(sensorType: .deviceState, timestamp: makeDate(hour: 7, minute: 0),
                          payload: .deviceState(event: .screenUnlock)),
        ]
        let events = engine.inferEvents(from: readings, on: Date(), places: [])
        let sleep = events.filter { $0.kind == .sleep }
        XCTAssertEqual(sleep.count, 1)
        XCTAssertGreaterThanOrEqual(sleep.first?.confidence ?? .low, .medium)
    }

    func testNapInference() {
        let readings: [SensorReading] = [
            SensorReading(sensorType: .deviceState, timestamp: makeDate(hour: 13, minute: 0),
                          payload: .deviceState(event: .screenLock)),
            SensorReading(sensorType: .deviceState, timestamp: makeDate(hour: 13, minute: 50),
                          payload: .deviceState(event: .screenUnlock)),
        ]
        let events = engine.inferEvents(from: readings, on: Date(), places: [])
        let sleep = events.filter { $0.kind == .sleep }
        XCTAssertEqual(sleep.count, 1)
        XCTAssertTrue(sleep.first?.displayName.contains("小睡") ?? false)
    }

    func testCommuteInference() {
        let readings: [SensorReading] = [
            SensorReading(sensorType: .motion, timestamp: makeDate(hour: 8, minute: 0),
                          endTimestamp: makeDate(hour: 8, minute: 25),
                          payload: .motion(activity: .automotive, confidence: .high)),
            SensorReading(sensorType: .location, timestamp: makeDate(hour: 8, minute: 0),
                          payload: .location(latitude: 31.2, longitude: 121.4, horizontalAccuracy: 10)),
            SensorReading(sensorType: .location, timestamp: makeDate(hour: 8, minute: 25),
                          payload: .location(latitude: 31.3, longitude: 121.5, horizontalAccuracy: 10)),
        ]
        let events = engine.inferEvents(from: readings, on: Date(), places: [])
        let commute = events.filter { $0.kind == .commute }
        XCTAssertEqual(commute.count, 1)
    }

    func testWalkingExerciseInference() {
        var readings: [SensorReading] = []
        for i in 0..<15 {
            readings.append(SensorReading(
                sensorType: .motion,
                timestamp: makeDate(hour: 18, minute: i),
                payload: .motion(activity: .walking, confidence: .high)
            ))
        }
        readings.append(SensorReading(
            sensorType: .pedometer,
            timestamp: makeDate(hour: 18, minute: 0),
            endTimestamp: makeDate(hour: 19, minute: 0),
            payload: .pedometer(steps: 2000, distance: 1500, floorsAscended: nil)
        ))
        let events = engine.inferEvents(from: readings, on: Date(), places: [])
        let walks = events.filter { $0.kind == .activeWalk }
        XCTAssertFalse(walks.isEmpty)
    }

    func testRunningInference() {
        let readings: [SensorReading] = [
            SensorReading(sensorType: .motion, timestamp: makeDate(hour: 7, minute: 0),
                          endTimestamp: makeDate(hour: 7, minute: 20),
                          payload: .motion(activity: .running, confidence: .high)),
        ]
        let events = engine.inferEvents(from: readings, on: Date(), places: [])
        let workouts = events.filter { $0.kind == .workout }
        XCTAssertEqual(workouts.count, 1)
        XCTAssertTrue(workouts.first?.displayName.contains("跑步") ?? false)
    }

    func testLocationStayInference() {
        let home = KnownPlace(
            id: UUID(), name: "Home", category: .home,
            latitude: 31.23, longitude: 121.47, radius: 100,
            visitCount: 10, totalDuration: 36000,
            lastVisitDate: Date(), isConfirmedByUser: true
        )
        let readings: [SensorReading] = [
            SensorReading(sensorType: .location, timestamp: makeDate(hour: 19, minute: 0),
                          endTimestamp: makeDate(hour: 22, minute: 0),
                          payload: .visit(latitude: 31.23, longitude: 121.47,
                                          arrivalDate: makeDate(hour: 19), departureDate: makeDate(hour: 22))),
        ]
        let events = engine.inferEvents(from: readings, on: Date(), places: [home])
        let stays = events.filter { $0.kind == .quietTime }
        XCTAssertFalse(stays.isEmpty)
        XCTAssertTrue(stays.first?.displayName.contains("Home") ?? false)
    }

    func testBlankPeriodDetection() {
        let readings: [SensorReading] = [
            SensorReading(sensorType: .deviceState, timestamp: makeDate(hour: 14, minute: 0),
                          payload: .deviceState(event: .screenLock)),
            SensorReading(sensorType: .motion, timestamp: makeDate(hour: 14, minute: 0),
                          endTimestamp: makeDate(hour: 14, minute: 30),
                          payload: .motion(activity: .stationary, confidence: .high)),
            SensorReading(sensorType: .deviceState, timestamp: makeDate(hour: 14, minute: 30),
                          payload: .deviceState(event: .screenUnlock)),
        ]
        let events = engine.inferEvents(from: readings, on: Date(), places: [])
        let lowConf = events.filter { $0.confidence == .low }
        XCTAssertFalse(lowConf.isEmpty, "Should detect blank period as low-confidence event")
    }
}
