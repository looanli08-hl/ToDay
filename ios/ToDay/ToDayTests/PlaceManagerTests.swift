import XCTest
@testable import ToDay

final class PlaceManagerTests: XCTestCase {
    private var manager: PlaceManager!

    override func setUp() {
        super.setUp()
        manager = PlaceManager(defaults: .init(suiteName: "test.\(UUID().uuidString)")!)
    }

    func testRecordVisitCreatesNewPlace() {
        manager.recordVisit(latitude: 31.23, longitude: 121.47, duration: 3600, date: Date())
        XCTAssertEqual(manager.allPlaces.count, 1)
        XCTAssertEqual(manager.allPlaces.first?.category, .visited)
        XCTAssertEqual(manager.allPlaces.first?.visitCount, 1)
    }

    func testRepeatedVisitIncrementsCount() {
        let coord = (lat: 31.23, lon: 121.47)
        manager.recordVisit(latitude: coord.lat, longitude: coord.lon, duration: 3600, date: Date())
        manager.recordVisit(latitude: coord.lat + 0.0001, longitude: coord.lon, duration: 3600, date: Date())
        XCTAssertEqual(manager.allPlaces.count, 1)
        XCTAssertEqual(manager.allPlaces.first?.visitCount, 2)
    }

    func testAutoDetectHome() {
        for _ in 0..<4 {
            manager.recordVisit(latitude: 31.23, longitude: 121.47, duration: 28800, date: Date())
        }
        manager.reclassifyPlaces()
        XCTAssertEqual(manager.allPlaces.first?.category, .home)
    }

    func testFindPlace() {
        manager.recordVisit(latitude: 31.23, longitude: 121.47, duration: 3600, date: Date())
        let found = manager.findPlace(latitude: 31.2301, longitude: 121.4701)
        XCTAssertNotNil(found)
        let far = manager.findPlace(latitude: 32.0, longitude: 122.0)
        XCTAssertNil(far)
    }

    func testNamePlace() {
        manager.recordVisit(latitude: 31.23, longitude: 121.47, duration: 3600, date: Date())
        let place = manager.allPlaces.first!
        manager.namePlace(id: place.id, name: "Home")
        XCTAssertEqual(manager.allPlaces.first?.name, "Home")
        XCTAssertTrue(manager.allPlaces.first?.isConfirmedByUser ?? false)
    }
}
