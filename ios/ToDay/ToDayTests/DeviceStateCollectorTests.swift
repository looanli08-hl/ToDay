import XCTest
import SwiftData
@testable import ToDay

final class DeviceStateCollectorTests: XCTestCase {
    private var container: ModelContainer!
    private var store: SensorDataStore!
    private var collector: DeviceStateCollector!

    @MainActor override func setUp() {
        super.setUp()
        container = try! ModelContainer(
            for: SensorReadingEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        store = SensorDataStore(container: container)
        collector = DeviceStateCollector(store: store)
    }

    func testSensorType() {
        XCTAssertEqual(collector.sensorType, .deviceState)
    }

    @MainActor func testRecordEvent() throws {
        collector.recordEvent(.screenUnlock)
        let readings = try store.readings(for: Date(), type: .deviceState)
        XCTAssertEqual(readings.count, 1)
        if case .deviceState(let event) = readings.first?.payload {
            XCTAssertEqual(event, .screenUnlock)
        } else {
            XCTFail("Expected deviceState payload")
        }
    }

    @MainActor func testCollectDataReturnsStoredEvents() async throws {
        collector.recordEvent(.chargingStart)
        collector.recordEvent(.screenLock)
        let readings = try await collector.collectData(for: Date())
        XCTAssertEqual(readings.count, 2)
    }
}
