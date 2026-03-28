import XCTest
import SwiftData
@testable import ToDay

final class LocationCollectorTests: XCTestCase {
    private var container: ModelContainer!
    private var store: SensorDataStore!
    private var collector: LocationCollector!

    @MainActor override func setUp() {
        super.setUp()
        container = try! ModelContainer(
            for: SensorReadingEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        store = SensorDataStore(container: container)
        collector = LocationCollector(store: store)
    }

    func testSensorType() {
        XCTAssertEqual(collector.sensorType, .location)
    }

    @MainActor func testRecordVisit() throws {
        let arrival = Date().addingTimeInterval(-3600)
        let departure = Date()
        collector.recordVisit(
            latitude: 31.23, longitude: 121.47,
            arrivalDate: arrival, departureDate: departure
        )
        let readings = try store.readings(for: arrival, type: .location)
        XCTAssertEqual(readings.count, 1)
        if case .visit(let lat, let lon, _, let dep) = readings.first?.payload {
            XCTAssertEqual(lat, 31.23, accuracy: 0.01)
            XCTAssertEqual(lon, 121.47, accuracy: 0.01)
            XCTAssertNotNil(dep)
        } else {
            XCTFail("Expected visit payload")
        }
    }

    @MainActor func testRecordLocationUpdate() throws {
        collector.recordLocationUpdate(latitude: 31.23, longitude: 121.47, accuracy: 10)
        let readings = try store.readings(for: Date(), type: .location)
        XCTAssertEqual(readings.count, 1)
        if case .location(let lat, _, let acc) = readings.first?.payload {
            XCTAssertEqual(lat, 31.23, accuracy: 0.01)
            XCTAssertEqual(acc, 10)
        } else {
            XCTFail("Expected location payload")
        }
    }
}
