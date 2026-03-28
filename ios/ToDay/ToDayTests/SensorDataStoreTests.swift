import XCTest
import SwiftData
@testable import ToDay

final class SensorDataStoreTests: XCTestCase {
    private var container: ModelContainer!
    private var store: SensorDataStore!

    @MainActor override func setUp() {
        super.setUp()
        container = try! ModelContainer(
            for: SensorReadingEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        store = SensorDataStore(container: container)
    }

    @MainActor func testSaveAndFetchReadings() throws {
        let date = Calendar.current.startOfDay(for: Date())
        let reading = SensorReading(
            sensorType: .motion, timestamp: date.addingTimeInterval(3600),
            payload: .motion(activity: .walking, confidence: .high)
        )
        try store.save([reading])
        let fetched = try store.readings(for: date)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.sensorType, .motion)
    }

    @MainActor func testFetchByType() throws {
        let date = Calendar.current.startOfDay(for: Date())
        let motionReading = SensorReading(
            sensorType: .motion, timestamp: date.addingTimeInterval(3600),
            payload: .motion(activity: .walking, confidence: .high)
        )
        let pedometerReading = SensorReading(
            sensorType: .pedometer, timestamp: date.addingTimeInterval(3600),
            payload: .pedometer(steps: 500, distance: 400, floorsAscended: 1)
        )
        try store.save([motionReading, pedometerReading])
        let motionOnly = try store.readings(for: date, type: .motion)
        XCTAssertEqual(motionOnly.count, 1)
        let all = try store.readings(for: date)
        XCTAssertEqual(all.count, 2)
    }

    @MainActor func testDeduplication() throws {
        let date = Calendar.current.startOfDay(for: Date())
        let reading = SensorReading(
            sensorType: .motion, timestamp: date.addingTimeInterval(3600),
            payload: .motion(activity: .walking, confidence: .high)
        )
        try store.save([reading])
        try store.save([reading]) // same ID
        let fetched = try store.readings(for: date)
        XCTAssertEqual(fetched.count, 1)
    }

    @MainActor func testPurgeOldReadings() throws {
        let oldDate = Calendar.current.date(byAdding: .day, value: -31, to: Date())!
        let reading = SensorReading(
            sensorType: .motion, timestamp: oldDate,
            payload: .motion(activity: .stationary, confidence: .low)
        )
        try store.save([reading])
        try store.purge(olderThan: 30)
        let fetched = try store.readings(for: Calendar.current.startOfDay(for: oldDate))
        XCTAssertEqual(fetched.count, 0)
    }
}
