import XCTest
import SwiftData
@testable import ToDay

final class PhoneTimelineDataProviderTests: XCTestCase {
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

    override func tearDown() {
        store = nil
        container = nil
        super.tearDown()
    }

    func testEmptyReadingsProducesEmptyTimeline() async throws {
        let placeManager = PlaceManager(defaults: UserDefaults(suiteName: "test.\(UUID())")!)
        let provider = PhoneTimelineDataProvider(
            collectors: [], store: store,
            inferenceEngine: PhoneInferenceEngine(), placeManager: placeManager
        )
        let timeline = try await provider.loadTimeline(for: Date())
        XCTAssertTrue(timeline.entries.isEmpty)
        XCTAssertEqual(timeline.source, .phone)
    }

    func testSourceIsAlwaysPhone() async throws {
        let placeManager = PlaceManager(defaults: UserDefaults(suiteName: "test.\(UUID())")!)
        let provider = PhoneTimelineDataProvider(
            collectors: [], store: store,
            inferenceEngine: PhoneInferenceEngine(), placeManager: placeManager
        )
        let timeline = try await provider.loadTimeline(for: Date())
        XCTAssertEqual(timeline.source, .phone)
    }

    @MainActor func testPreExistingReadingsAreInferred() async throws {
        let today = Calendar.current.startOfDay(for: Date())
        let readings = [
            SensorReading(sensorType: .motion, timestamp: today.addingTimeInterval(8 * 3600),
                          endTimestamp: today.addingTimeInterval(8.5 * 3600),
                          payload: .motion(activity: .automotive, confidence: .high)),
            SensorReading(sensorType: .location, timestamp: today.addingTimeInterval(8 * 3600),
                          payload: .location(latitude: 31.2, longitude: 121.4, horizontalAccuracy: 10)),
            SensorReading(sensorType: .location, timestamp: today.addingTimeInterval(8.5 * 3600),
                          payload: .location(latitude: 31.3, longitude: 121.5, horizontalAccuracy: 10)),
        ]
        try store.save(readings)
        let placeManager = PlaceManager(defaults: UserDefaults(suiteName: "test.\(UUID())")!)
        let provider = PhoneTimelineDataProvider(
            collectors: [], store: store,
            inferenceEngine: PhoneInferenceEngine(), placeManager: placeManager
        )
        let timeline = try await provider.loadTimeline(for: today)
        XCTAssertFalse(timeline.entries.isEmpty)
    }

    @MainActor func testPedometerReadingsPopulateSteps() async throws {
        let today = Calendar.current.startOfDay(for: Date())
        let readings = [
            SensorReading(sensorType: .pedometer, timestamp: today.addingTimeInterval(9 * 3600),
                          payload: .pedometer(steps: 3500, distance: 2800, floorsAscended: 5)),
        ]
        try store.save(readings)
        let placeManager = PlaceManager(defaults: UserDefaults(suiteName: "test.\(UUID())")!)
        let provider = PhoneTimelineDataProvider(
            collectors: [], store: store,
            inferenceEngine: PhoneInferenceEngine(), placeManager: placeManager
        )
        let timeline = try await provider.loadTimeline(for: today)
        let stepsStat = timeline.stats.first { $0.id == "steps" }
        XCTAssertNotNil(stepsStat)
        XCTAssertEqual(stepsStat?.value, "3500")
    }

    @MainActor func testVisitReadingsUpdatePlaceManager() async throws {
        let today = Calendar.current.startOfDay(for: Date())
        let arrival = today.addingTimeInterval(8 * 3600)
        let departure = today.addingTimeInterval(9 * 3600)
        let readings = [
            SensorReading(sensorType: .location, timestamp: arrival,
                          endTimestamp: departure,
                          payload: .visit(latitude: 31.2, longitude: 121.4,
                                          arrivalDate: arrival, departureDate: departure)),
        ]
        try store.save(readings)
        let suiteName = "test.\(UUID())"
        let placeManager = PlaceManager(defaults: UserDefaults(suiteName: suiteName)!)
        let provider = PhoneTimelineDataProvider(
            collectors: [], store: store,
            inferenceEngine: PhoneInferenceEngine(), placeManager: placeManager
        )
        _ = try await provider.loadTimeline(for: today)
        XCTAssertFalse(placeManager.allPlaces.isEmpty)
    }

    @MainActor func testSummaryNonEmptyForEvents() async throws {
        let today = Calendar.current.startOfDay(for: Date())
        let readings = [
            SensorReading(sensorType: .motion, timestamp: today.addingTimeInterval(8 * 3600),
                          endTimestamp: today.addingTimeInterval(8.5 * 3600),
                          payload: .motion(activity: .automotive, confidence: .high)),
            SensorReading(sensorType: .location, timestamp: today.addingTimeInterval(8 * 3600),
                          payload: .location(latitude: 31.2, longitude: 121.4, horizontalAccuracy: 10)),
            SensorReading(sensorType: .location, timestamp: today.addingTimeInterval(8.5 * 3600),
                          payload: .location(latitude: 31.3, longitude: 121.5, horizontalAccuracy: 10)),
        ]
        try store.save(readings)
        let placeManager = PlaceManager(defaults: UserDefaults(suiteName: "test.\(UUID())")!)
        let provider = PhoneTimelineDataProvider(
            collectors: [], store: store,
            inferenceEngine: PhoneInferenceEngine(), placeManager: placeManager
        )
        let timeline = try await provider.loadTimeline(for: today)
        XCTAssertFalse(timeline.summary.isEmpty)
    }
}
