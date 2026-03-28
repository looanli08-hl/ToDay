# Phone-First Auto Recording Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Apple Watch dependency with iPhone sensor-based auto recording using CoreMotion, CoreLocation, pedometer, and device state.

**Architecture:** Collectors gather raw sensor data → SensorDataStore persists readings → PhoneInferenceEngine cross-references all sources to infer activities → PlaceManager auto-learns frequently visited locations. HealthKit becomes one optional Collector among many.

**Tech Stack:** SwiftUI, SwiftData, CoreMotion (CMMotionActivityManager, CMPedometer), CoreLocation (CLVisit, Significant Location Change), HealthKit (optional), BackgroundTasks framework

**Design Spec:** `docs/superpowers/specs/2026-03-28-phone-first-auto-recording-design.md`

---

## File Structure

### New Files

```
ToDay/Data/Sensors/
  SensorTypes.swift              — SensorType, SensorReading, SensorPayload enums/structs
  SensorCollecting.swift         — SensorCollecting protocol
  SensorDataStore.swift          — SwiftData entity + read/write/cleanup
  MotionCollector.swift          — CMMotionActivityManager wrapper
  PedometerCollector.swift       — CMPedometer wrapper
  DeviceStateCollector.swift     — Battery/screen lock event listener
  LocationCollector.swift        — Evolves from LocationService
  HealthKitCollector.swift       — Extracted from HealthKitTimelineDataProvider
  PlaceManager.swift             — KnownPlace model + auto-learning
  PhoneInferenceEngine.swift     — Cross-source activity inference
  PhoneTimelineDataProvider.swift — Implements TimelineDataProviding

ToDayTests/
  SensorDataStoreTests.swift
  MotionCollectorTests.swift
  PedometerCollectorTests.swift
  DeviceStateCollectorTests.swift
  LocationCollectorTests.swift
  PlaceManagerTests.swift
  PhoneInferenceEngineTests.swift
  PhoneTimelineDataProviderTests.swift
```

### Modified Files

```
ToDay/App/AppContainer.swift         — Wire new provider + collectors
ToDay/Data/BackgroundTaskManager.swift — Call collectors instead of HealthKit directly
ToDay/Shared/SharedDataTypes.swift    — Add TimelineSource.phone case
project.yml                          — Remove Watch target, add Motion permission
ToDay/ToDay.entitlements             — Keep as-is (HealthKit stays for optional enhancement)
ToDay/Info.plist                     — Add NSMotionUsageDescription, upgrade location to Always
```

### Removed Files

```
ToDayWatch/                          — Entire directory
ToDay/Data/LocationService.swift     — Replaced by LocationCollector
ToDay/Data/HealthKitTimelineDataProvider.swift — Split into HealthKitCollector + PhoneInferenceEngine
ToDay/Data/HealthKitEventInferenceEngine.swift — Merged into PhoneInferenceEngine
```

---

## Task 1: Core Sensor Types

**Files:**
- Create: `ToDay/Data/Sensors/SensorTypes.swift`
- Test: `ToDayTests/SensorTypesTests.swift`

- [ ] **Step 1: Write tests for SensorReading and SensorPayload**

```swift
// ToDayTests/SensorTypesTests.swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ToDayTests/SensorTypesTests CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`
Expected: Compilation failure — types not defined

- [ ] **Step 3: Implement SensorTypes**

```swift
// ToDay/Data/Sensors/SensorTypes.swift
import Foundation

// MARK: - Sensor Type

enum SensorType: String, Codable, Sendable {
    case motion
    case location
    case pedometer
    case deviceState
    case healthKit
}

// MARK: - Sensor Reading

struct SensorReading: Codable, Identifiable, Sendable {
    let id: UUID
    let sensorType: SensorType
    let timestamp: Date
    let endTimestamp: Date?
    let payload: SensorPayload

    init(id: UUID = UUID(), sensorType: SensorType, timestamp: Date,
         endTimestamp: Date? = nil, payload: SensorPayload) {
        self.id = id
        self.sensorType = sensorType
        self.timestamp = timestamp
        self.endTimestamp = endTimestamp
        self.payload = payload
    }
}

// MARK: - Sensor Payload

enum SensorPayload: Codable, Sendable {
    case motion(activity: MotionActivity, confidence: MotionConfidence)
    case location(latitude: Double, longitude: Double, horizontalAccuracy: Double)
    case visit(latitude: Double, longitude: Double, arrivalDate: Date, departureDate: Date?)
    case pedometer(steps: Int, distance: Double?, floorsAscended: Int?)
    case deviceState(event: DeviceEvent)
    case healthKit(metric: String, value: Double)
}

// MARK: - Motion Types

enum MotionActivity: String, Codable, Sendable, CaseIterable {
    case stationary, walking, running, automotive, cycling, unknown
}

enum MotionConfidence: String, Codable, Sendable, Comparable {
    case low, medium, high

    static func < (lhs: Self, rhs: Self) -> Bool {
        let order: [MotionConfidence] = [.low, .medium, .high]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

// MARK: - Device Events

enum DeviceEvent: String, Codable, Sendable, CaseIterable {
    case screenUnlock, screenLock, chargingStart, chargingStop
}
```

- [ ] **Step 4: Run `xcodegen generate` then run tests**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`
Expected: All tests pass including new SensorTypesTests

- [ ] **Step 5: Commit**

```bash
git add ios/ToDay/ToDay/Data/Sensors/SensorTypes.swift ios/ToDay/ToDayTests/SensorTypesTests.swift
git commit -m "feat: add core sensor types — SensorReading, SensorPayload, MotionActivity, DeviceEvent"
```

---

## Task 2: SensorDataStore (SwiftData persistence)

**Files:**
- Create: `ToDay/Data/Sensors/SensorDataStore.swift`
- Modify: `ToDay/App/AppContainer.swift` (add SensorReadingEntity to ModelContainer)
- Test: `ToDayTests/SensorDataStoreTests.swift`

- [ ] **Step 1: Write tests for SensorDataStore**

```swift
// ToDayTests/SensorDataStoreTests.swift
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

    func testSaveAndFetchReadings() async throws {
        let date = Calendar.current.startOfDay(for: Date())
        let reading = SensorReading(
            sensorType: .motion, timestamp: date.addingTimeInterval(3600),
            payload: .motion(activity: .walking, confidence: .high)
        )
        try await store.save([reading])
        let fetched = try await store.readings(for: date)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.sensorType, .motion)
    }

    func testFetchByType() async throws {
        let date = Calendar.current.startOfDay(for: Date())
        let motionReading = SensorReading(
            sensorType: .motion, timestamp: date.addingTimeInterval(3600),
            payload: .motion(activity: .walking, confidence: .high)
        )
        let pedometerReading = SensorReading(
            sensorType: .pedometer, timestamp: date.addingTimeInterval(3600),
            payload: .pedometer(steps: 500, distance: 400, floorsAscended: 1)
        )
        try await store.save([motionReading, pedometerReading])

        let motionOnly = try await store.readings(for: date, type: .motion)
        XCTAssertEqual(motionOnly.count, 1)

        let all = try await store.readings(for: date)
        XCTAssertEqual(all.count, 2)
    }

    func testDeduplication() async throws {
        let date = Calendar.current.startOfDay(for: Date())
        let reading = SensorReading(
            sensorType: .motion, timestamp: date.addingTimeInterval(3600),
            payload: .motion(activity: .walking, confidence: .high)
        )
        try await store.save([reading])
        try await store.save([reading]) // same ID
        let fetched = try await store.readings(for: date)
        XCTAssertEqual(fetched.count, 1)
    }

    func testPurgeOldReadings() async throws {
        let oldDate = Calendar.current.date(byAdding: .day, value: -31, to: Date())!
        let reading = SensorReading(
            sensorType: .motion, timestamp: oldDate,
            payload: .motion(activity: .stationary, confidence: .low)
        )
        try await store.save([reading])
        try await store.purge(olderThan: 30)
        let fetched = try await store.readings(for: Calendar.current.startOfDay(for: oldDate))
        XCTAssertEqual(fetched.count, 0)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: Compilation failure — SensorReadingEntity and SensorDataStore not defined

- [ ] **Step 3: Implement SensorDataStore**

```swift
// ToDay/Data/Sensors/SensorDataStore.swift
import Foundation
import SwiftData

// MARK: - SwiftData Entity

@Model
final class SensorReadingEntity {
    @Attribute(.unique) var readingID: UUID
    var sensorType: String
    var timestamp: Date
    var endTimestamp: Date?
    var dateKey: String // "yyyy-MM-dd" for indexed day queries
    var payloadData: Data

    init(from reading: SensorReading) throws {
        self.readingID = reading.id
        self.sensorType = reading.sensorType.rawValue
        self.timestamp = reading.timestamp
        self.endTimestamp = reading.endTimestamp
        self.dateKey = Self.dateKeyFormatter.string(from: reading.timestamp)
        self.payloadData = try JSONEncoder().encode(reading.payload)
    }

    func toReading() throws -> SensorReading {
        let payload = try JSONDecoder().decode(SensorPayload.self, from: payloadData)
        guard let type = SensorType(rawValue: sensorType) else {
            throw SensorDataStoreError.invalidSensorType(sensorType)
        }
        return SensorReading(
            id: readingID, sensorType: type, timestamp: timestamp,
            endTimestamp: endTimestamp, payload: payload
        )
    }

    private static let dateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

// MARK: - Store

final class SensorDataStore: Sendable {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    @MainActor
    func save(_ readings: [SensorReading]) throws {
        let context = container.mainContext
        for reading in readings {
            let descriptor = FetchDescriptor<SensorReadingEntity>(
                predicate: #Predicate { $0.readingID == reading.id }
            )
            let existing = try context.fetch(descriptor)
            if existing.isEmpty {
                let entity = try SensorReadingEntity(from: reading)
                context.insert(entity)
            }
        }
        try context.save()
    }

    @MainActor
    func readings(for date: Date, type: SensorType? = nil) throws -> [SensorReading] {
        let dateKey = Self.dateKeyFormatter.string(from: date)
        let descriptor: FetchDescriptor<SensorReadingEntity>
        if let type {
            let typeStr = type.rawValue
            descriptor = FetchDescriptor<SensorReadingEntity>(
                predicate: #Predicate { $0.dateKey == dateKey && $0.sensorType == typeStr },
                sortBy: [SortDescriptor(\.timestamp)]
            )
        } else {
            descriptor = FetchDescriptor<SensorReadingEntity>(
                predicate: #Predicate { $0.dateKey == dateKey },
                sortBy: [SortDescriptor(\.timestamp)]
            )
        }
        return try context.fetch(descriptor).compactMap { try? $0.toReading() }
    }

    @MainActor
    func purge(olderThan days: Int) throws {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let descriptor = FetchDescriptor<SensorReadingEntity>(
            predicate: #Predicate { $0.timestamp < cutoff }
        )
        let old = try container.mainContext.fetch(descriptor)
        for entity in old {
            container.mainContext.delete(entity)
        }
        try container.mainContext.save()
    }

    private static let dateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

enum SensorDataStoreError: Error {
    case invalidSensorType(String)
}
```

- [ ] **Step 4: Add SensorReadingEntity to ModelContainer in AppContainer.swift**

In `AppContainer.swift`, add `SensorReadingEntity.self` to the `ModelContainer(for:)` call:

```swift
// In makeModelContainer(), add SensorReadingEntity.self to the entity list:
let container = try ModelContainer(
    for: MoodRecordEntity.self,
    DayTimelineEntity.self,
    ShutterRecordEntity.self,
    SpendingRecordEntity.self,
    ScreenTimeRecordEntity.self,
    EchoItemEntity.self,
    UserProfileEntity.self,
    DailySummaryEntity.self,
    ConversationMemoryEntity.self,
    EchoChatSessionEntity.self,
    EchoChatMessageEntity.self,
    EchoMessageEntity.self,
    SensorReadingEntity.self    // NEW
)
```

- [ ] **Step 5: Run `xcodegen generate` then run all tests**

Expected: All 163+ tests pass including new SensorDataStoreTests

- [ ] **Step 6: Commit**

```bash
git add ios/ToDay/ToDay/Data/Sensors/SensorDataStore.swift ios/ToDay/ToDayTests/SensorDataStoreTests.swift ios/ToDay/ToDay/App/AppContainer.swift
git commit -m "feat: add SensorDataStore with SwiftData persistence, dedup, and purge"
```

---

## Task 3: SensorCollecting Protocol + MotionCollector

**Files:**
- Create: `ToDay/Data/Sensors/SensorCollecting.swift`
- Create: `ToDay/Data/Sensors/MotionCollector.swift`
- Test: `ToDayTests/MotionCollectorTests.swift`

- [ ] **Step 1: Write SensorCollecting protocol**

```swift
// ToDay/Data/Sensors/SensorCollecting.swift
import Foundation

protocol SensorCollecting: Sendable {
    var sensorType: SensorType { get }
    var isAvailable: Bool { get }
    func collectData(for date: Date) async throws -> [SensorReading]
    func requestAuthorizationIfNeeded() async throws
}
```

- [ ] **Step 2: Write tests for MotionCollector**

```swift
// ToDayTests/MotionCollectorTests.swift
import XCTest
@testable import ToDay

final class MotionCollectorTests: XCTestCase {
    func testSensorType() {
        let collector = MotionCollector()
        XCTAssertEqual(collector.sensorType, .motion)
    }

    func testMapCMMotionActivity() {
        // Test the static mapping function
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
```

- [ ] **Step 3: Implement MotionCollector**

```swift
// ToDay/Data/Sensors/MotionCollector.swift
import CoreMotion
import Foundation

final class MotionCollector: SensorCollecting, @unchecked Sendable {
    let sensorType: SensorType = .motion
    private let activityManager = CMMotionActivityManager()

    var isAvailable: Bool {
        CMMotionActivityManager.isActivityAvailable()
    }

    func requestAuthorizationIfNeeded() async throws {
        // CoreMotion authorization is triggered on first query — no explicit request needed.
        // If denied, queryActivityStarting will fail with CMErrorMotionActivityNotAuthorized.
    }

    func collectData(for date: Date) async throws -> [SensorReading] {
        guard isAvailable else { return [] }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!

        return try await withCheckedThrowingContinuation { continuation in
            activityManager.queryActivityStarting(from: start, to: end, to: .main) { activities, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let readings = (activities ?? []).map { activity -> SensorReading in
                    let motionActivity = Self.mapActivity(
                        stationary: activity.stationary,
                        walking: activity.walking,
                        running: activity.running,
                        automotive: activity.automotive,
                        cycling: activity.cycling
                    )
                    let confidence = Self.mapConfidence(activity.confidence.rawValue)
                    return SensorReading(
                        sensorType: .motion,
                        timestamp: activity.startDate,
                        payload: .motion(activity: motionActivity, confidence: confidence)
                    )
                }
                continuation.resume(returning: readings)
            }
        }
    }

    // MARK: - Mapping Helpers (internal for testing)

    static func mapActivity(stationary: Bool, walking: Bool, running: Bool,
                            automotive: Bool, cycling: Bool) -> MotionActivity {
        if running { return .running }
        if cycling { return .cycling }
        if automotive { return .automotive }
        if walking { return .walking }
        if stationary { return .stationary }
        return .unknown
    }

    static func mapConfidence(_ raw: Int) -> MotionConfidence {
        switch raw {
        case 2: return .high
        case 1: return .medium
        default: return .low
        }
    }
}
```

- [ ] **Step 4: Run `xcodegen generate` then run tests**

Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add ios/ToDay/ToDay/Data/Sensors/SensorCollecting.swift ios/ToDay/ToDay/Data/Sensors/MotionCollector.swift ios/ToDay/ToDayTests/MotionCollectorTests.swift
git commit -m "feat: add SensorCollecting protocol and MotionCollector with CMMotionActivity"
```

---

## Task 4: PedometerCollector

**Files:**
- Create: `ToDay/Data/Sensors/PedometerCollector.swift`
- Test: `ToDayTests/PedometerCollectorTests.swift`

- [ ] **Step 1: Write tests**

```swift
// ToDayTests/PedometerCollectorTests.swift
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
```

- [ ] **Step 2: Implement PedometerCollector**

```swift
// ToDay/Data/Sensors/PedometerCollector.swift
import CoreMotion
import Foundation

final class PedometerCollector: SensorCollecting, @unchecked Sendable {
    let sensorType: SensorType = .pedometer
    private let pedometer = CMPedometer()

    var isAvailable: Bool {
        CMPedometer.isStepCountingAvailable()
    }

    func requestAuthorizationIfNeeded() async throws {
        // Authorization triggered on first query, same as CoreMotion.
    }

    func collectData(for date: Date) async throws -> [SensorReading] {
        guard isAvailable else { return [] }
        var readings: [SensorReading] = []
        for segment in Self.hourSegments(for: date) {
            if let reading = try? await querySegment(start: segment.start, end: segment.end) {
                readings.append(reading)
            }
        }
        return readings
    }

    private func querySegment(start: Date, end: Date) async throws -> SensorReading? {
        try await withCheckedThrowingContinuation { continuation in
            pedometer.queryPedometerData(from: start, to: end) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let data, data.numberOfSteps.intValue > 0 else {
                    continuation.resume(returning: nil)
                    return
                }
                let reading = SensorReading(
                    sensorType: .pedometer,
                    timestamp: start,
                    endTimestamp: end,
                    payload: .pedometer(
                        steps: data.numberOfSteps.intValue,
                        distance: data.distance?.doubleValue,
                        floorsAscended: data.floorsAscended?.intValue
                    )
                )
                continuation.resume(returning: reading)
            }
        }
    }

    // MARK: - Helpers

    static func hourSegments(for date: Date) -> [(start: Date, end: Date)] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        return (0..<24).map { hour in
            let start = dayStart.addingTimeInterval(Double(hour) * 3600)
            let end = start.addingTimeInterval(3600)
            return (start, end)
        }
    }
}
```

- [ ] **Step 3: Run `xcodegen generate` then run all tests**

Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add ios/ToDay/ToDay/Data/Sensors/PedometerCollector.swift ios/ToDay/ToDayTests/PedometerCollectorTests.swift
git commit -m "feat: add PedometerCollector with hourly step/distance/floor queries"
```

---

## Task 5: DeviceStateCollector

**Files:**
- Create: `ToDay/Data/Sensors/DeviceStateCollector.swift`
- Test: `ToDayTests/DeviceStateCollectorTests.swift`

- [ ] **Step 1: Write tests**

```swift
// ToDayTests/DeviceStateCollectorTests.swift
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
```

- [ ] **Step 2: Implement DeviceStateCollector**

```swift
// ToDay/Data/Sensors/DeviceStateCollector.swift
import Foundation
import UIKit

final class DeviceStateCollector: SensorCollecting, @unchecked Sendable {
    let sensorType: SensorType = .deviceState
    let isAvailable: Bool = true

    private let store: SensorDataStore
    private var observers: [NSObjectProtocol] = []

    init(store: SensorDataStore) {
        self.store = store
    }

    func requestAuthorizationIfNeeded() async throws {
        // No authorization needed for battery/screen events
    }

    func collectData(for date: Date) async throws -> [SensorReading] {
        try await MainActor.run {
            try store.readings(for: date, type: .deviceState)
        }
    }

    /// Call from app startup to begin monitoring device events.
    @MainActor
    func startMonitoring() {
        stopMonitoring()
        let nc = NotificationCenter.default

        observers.append(nc.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            let state = UIDevice.current.batteryState
            switch state {
            case .charging, .full:
                self?.recordEvent(.chargingStart)
            case .unplugged:
                self?.recordEvent(.chargingStop)
            default: break
            }
        })

        observers.append(nc.addObserver(
            forName: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.recordEvent(.screenUnlock)
        })

        observers.append(nc.addObserver(
            forName: UIApplication.protectedDataWillBecomeUnavailableNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.recordEvent(.screenLock)
        })

        UIDevice.current.isBatteryMonitoringEnabled = true
    }

    @MainActor
    func stopMonitoring() {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
    }

    @MainActor
    func recordEvent(_ event: DeviceEvent) {
        let reading = SensorReading(
            sensorType: .deviceState,
            timestamp: Date(),
            payload: .deviceState(event: event)
        )
        try? store.save([reading])
    }
}
```

- [ ] **Step 3: Run `xcodegen generate` then run all tests**

Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add ios/ToDay/ToDay/Data/Sensors/DeviceStateCollector.swift ios/ToDay/ToDayTests/DeviceStateCollectorTests.swift
git commit -m "feat: add DeviceStateCollector for battery/screen lock events"
```

---

## Task 6: LocationCollector (evolve from LocationService)

**Files:**
- Create: `ToDay/Data/Sensors/LocationCollector.swift`
- Test: `ToDayTests/LocationCollectorTests.swift`

- [ ] **Step 1: Write tests**

```swift
// ToDayTests/LocationCollectorTests.swift
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
        if case .visit(let lat, let lon, let arr, let dep) = readings.first?.payload {
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
```

- [ ] **Step 2: Implement LocationCollector**

```swift
// ToDay/Data/Sensors/LocationCollector.swift
import CoreLocation
import Foundation

final class LocationCollector: NSObject, SensorCollecting, CLLocationManagerDelegate, @unchecked Sendable {
    let sensorType: SensorType = .location
    private let store: SensorDataStore
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    var isAvailable: Bool {
        CLLocationManager.significantLocationChangeMonitoringAvailable()
    }

    init(store: SensorDataStore) {
        self.store = store
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestAuthorizationIfNeeded() async throws {
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestAlwaysAuthorization()
        }
    }

    func collectData(for date: Date) async throws -> [SensorReading] {
        try await MainActor.run {
            try store.readings(for: date, type: .location)
        }
    }

    /// Call from app startup to begin monitoring.
    func startMonitoring() {
        locationManager.startMonitoringSignificantLocationChanges()
        locationManager.startMonitoringVisits()
    }

    // MARK: - Recording (called from delegate callbacks)

    @MainActor
    func recordVisit(latitude: Double, longitude: Double, arrivalDate: Date, departureDate: Date?) {
        let reading = SensorReading(
            sensorType: .location,
            timestamp: arrivalDate,
            endTimestamp: departureDate,
            payload: .visit(
                latitude: latitude, longitude: longitude,
                arrivalDate: arrivalDate, departureDate: departureDate
            )
        )
        try? store.save([reading])
    }

    @MainActor
    func recordLocationUpdate(latitude: Double, longitude: Double, accuracy: Double) {
        let reading = SensorReading(
            sensorType: .location,
            timestamp: Date(),
            payload: .location(latitude: latitude, longitude: longitude, horizontalAccuracy: accuracy)
        )
        try? store.save([reading])
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        let dep = visit.departureDate == Date.distantFuture ? nil : visit.departureDate
        Task { @MainActor in
            recordVisit(
                latitude: visit.coordinate.latitude,
                longitude: visit.coordinate.longitude,
                arrivalDate: visit.arrivalDate,
                departureDate: dep
            )
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            recordLocationUpdate(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                accuracy: location.horizontalAccuracy
            )
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedAlways ||
           manager.authorizationStatus == .authorizedWhenInUse {
            startMonitoring()
        }
    }
}
```

- [ ] **Step 3: Run `xcodegen generate` then run all tests**

Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add ios/ToDay/ToDay/Data/Sensors/LocationCollector.swift ios/ToDay/ToDayTests/LocationCollectorTests.swift
git commit -m "feat: add LocationCollector with visit monitoring and significant location changes"
```

---

## Task 7: HealthKitCollector

**Files:**
- Create: `ToDay/Data/Sensors/HealthKitCollector.swift`

- [ ] **Step 1: Implement HealthKitCollector**

Extract the data-fetching logic from `HealthKitTimelineDataProvider` into a Collector that outputs `[SensorReading]`. This collector wraps existing HealthKit queries and remains optional.

```swift
// ToDay/Data/Sensors/HealthKitCollector.swift
import Foundation
import HealthKit

final class HealthKitCollector: SensorCollecting, @unchecked Sendable {
    let sensorType: SensorType = .healthKit
    private let healthStore = HKHealthStore()
    private let authGate = HealthAuthorizationGate()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorizationIfNeeded() async throws {
        guard isAvailable else { return }
        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKCategoryType(.sleepAnalysis),
            HKWorkoutType.workoutType(),
        ]
        try await authGate.requestOnce {
            try await self.healthStore.requestAuthorization(toShare: [], read: readTypes)
        }
    }

    func collectData(for date: Date) async throws -> [SensorReading] {
        guard isAvailable else { return [] }
        try await requestAuthorizationIfNeeded()
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!

        var readings: [SensorReading] = []

        // Heart rate samples
        let hrSamples = try await queryQuantitySamples(type: .heartRate, start: start, end: end)
        for sample in hrSamples {
            let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            readings.append(SensorReading(
                sensorType: .healthKit, timestamp: sample.startDate,
                endTimestamp: sample.endDate,
                payload: .healthKit(metric: "heartRate", value: bpm)
            ))
        }

        // Sleep samples
        let sleepSamples = try await queryCategorySamples(type: .sleepAnalysis, start: start, end: end)
        for sample in sleepSamples {
            readings.append(SensorReading(
                sensorType: .healthKit, timestamp: sample.startDate,
                endTimestamp: sample.endDate,
                payload: .healthKit(metric: "sleep.\(sample.value)", value: Double(sample.value))
            ))
        }

        return readings
    }

    // MARK: - HealthKit Queries

    private func queryQuantitySamples(type: HKQuantityTypeIdentifier, start: Date, end: Date) async throws -> [HKQuantitySample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(type), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        return try await descriptor.result(for: healthStore)
    }

    private func queryCategorySamples(type: HKCategoryTypeIdentifier, start: Date, end: Date) async throws -> [HKCategorySample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(type), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        return try await descriptor.result(for: healthStore)
    }
}
```

- [ ] **Step 2: Run `xcodegen generate` then build**

Expected: Build succeeds (no unit test for HealthKit — requires real device)

- [ ] **Step 3: Commit**

```bash
git add ios/ToDay/ToDay/Data/Sensors/HealthKitCollector.swift
git commit -m "feat: add HealthKitCollector — optional Watch data as sensor readings"
```

---

## Task 8: PlaceManager

**Files:**
- Create: `ToDay/Data/Sensors/PlaceManager.swift`
- Test: `ToDayTests/PlaceManagerTests.swift`

- [ ] **Step 1: Write tests**

```swift
// ToDayTests/PlaceManagerTests.swift
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
        XCTAssertEqual(manager.allPlaces.count, 1) // Same place (within 100m)
        XCTAssertEqual(manager.allPlaces.first?.visitCount, 2)
    }

    func testAutoDetectHome() {
        let nightHours = [22, 23, 0, 1, 2, 3, 4, 5]
        for day in 0..<4 {
            for hour in nightHours {
                let date = Calendar.current.date(byAdding: .day, value: -day, to: Date())!
                let nightDate = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: date)!
                manager.recordVisit(latitude: 31.23, longitude: 121.47, duration: 3600, date: nightDate)
            }
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
```

- [ ] **Step 2: Implement PlaceManager**

```swift
// ToDay/Data/Sensors/PlaceManager.swift
import CoreLocation
import Foundation

struct KnownPlace: Codable, Identifiable {
    let id: UUID
    var name: String?
    var category: PlaceCategory
    var latitude: Double
    var longitude: Double
    var radius: Double
    var visitCount: Int
    var totalDuration: TimeInterval
    var lastVisitDate: Date
    var isConfirmedByUser: Bool

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

enum PlaceCategory: String, Codable, Sendable {
    case home, work, frequent, visited
}

final class PlaceManager {
    private let defaults: UserDefaults
    private static let storageKey = "today.places.known"
    private let matchRadius: Double = 100 // meters

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var allPlaces: [KnownPlace] {
        get {
            guard let data = defaults.data(forKey: Self.storageKey) else { return [] }
            return (try? JSONDecoder().decode([KnownPlace].self, from: data)) ?? []
        }
        set {
            defaults.set(try? JSONEncoder().encode(newValue), forKey: Self.storageKey)
        }
    }

    func recordVisit(latitude: Double, longitude: Double, duration: TimeInterval, date: Date) {
        var places = allPlaces
        if let index = findPlaceIndex(latitude: latitude, longitude: longitude, in: places) {
            places[index].visitCount += 1
            places[index].totalDuration += duration
            places[index].lastVisitDate = date
        } else {
            places.append(KnownPlace(
                id: UUID(), name: nil, category: .visited,
                latitude: latitude, longitude: longitude,
                radius: matchRadius, visitCount: 1,
                totalDuration: duration, lastVisitDate: date,
                isConfirmedByUser: false
            ))
        }
        allPlaces = places
    }

    func findPlace(latitude: Double, longitude: Double) -> KnownPlace? {
        let target = CLLocation(latitude: latitude, longitude: longitude)
        return allPlaces.first { place in
            let loc = CLLocation(latitude: place.latitude, longitude: place.longitude)
            return target.distance(from: loc) < place.radius
        }
    }

    func namePlace(id: UUID, name: String) {
        var places = allPlaces
        if let index = places.firstIndex(where: { $0.id == id }) {
            places[index].name = name
            places[index].isConfirmedByUser = true
        }
        allPlaces = places
    }

    /// Re-classify places based on visit patterns.
    func reclassifyPlaces() {
        var places = allPlaces

        // Home: most visits during 22:00-6:00, visited > 3 days
        // Work: most visits during weekday 8:00-18:00, visited > 3 days, not home
        // Frequent: visited >= 3 times in 7 days
        // We use visitCount as proxy since we don't store per-visit timestamps.

        // Sort by nighttime visit heuristic (totalDuration as proxy)
        let candidates = places.filter { !$0.isConfirmedByUser && $0.visitCount >= 3 }

        // Highest total duration place with > 3 visits → home
        if let homeIdx = candidates.max(by: { $0.totalDuration < $1.totalDuration })
            .flatMap({ candidate in places.firstIndex(where: { $0.id == candidate.id }) }) {
            if places[homeIdx].category != .home {
                places[homeIdx].category = .home
            }
        }

        // Second most visited → work (if not home)
        let nonHome = candidates.filter { places.first(where: { $0.id == $0.id && $0.category == .home })?.id != $0.id }
        if let workCandidate = nonHome.sorted(by: { $0.visitCount > $1.visitCount }).first,
           let workIdx = places.firstIndex(where: { $0.id == workCandidate.id }) {
            if places[workIdx].category != .work && places[workIdx].category != .home {
                places[workIdx].category = .work
            }
        }

        // Frequent: visitCount >= 3
        for i in places.indices where places[i].visitCount >= 3 &&
            places[i].category == .visited && !places[i].isConfirmedByUser {
            places[i].category = .frequent
        }

        allPlaces = places
    }

    // MARK: - Private

    private func findPlaceIndex(latitude: Double, longitude: Double, in places: [KnownPlace]) -> Int? {
        let target = CLLocation(latitude: latitude, longitude: longitude)
        return places.firstIndex { place in
            let loc = CLLocation(latitude: place.latitude, longitude: place.longitude)
            return target.distance(from: loc) < place.radius
        }
    }
}
```

- [ ] **Step 3: Run `xcodegen generate` then run all tests**

Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add ios/ToDay/ToDay/Data/Sensors/PlaceManager.swift ios/ToDay/ToDayTests/PlaceManagerTests.swift
git commit -m "feat: add PlaceManager with auto-learning, place matching, and reclassification"
```

---

## Task 9: PhoneInferenceEngine — Sleep + Commute + Exercise

**Files:**
- Create: `ToDay/Data/Sensors/PhoneInferenceEngine.swift`
- Test: `ToDayTests/PhoneInferenceEngineTests.swift`

- [ ] **Step 1: Write tests for sleep, commute, and exercise inference**

```swift
// ToDayTests/PhoneInferenceEngineTests.swift
import XCTest
@testable import ToDay

final class PhoneInferenceEngineTests: XCTestCase {
    private let engine = PhoneInferenceEngine()
    private let calendar = Calendar.current

    private func makeDate(hour: Int, minute: Int = 0) -> Date {
        let today = calendar.startOfDay(for: Date())
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today)!
    }

    // MARK: - Sleep

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

    // MARK: - Commute

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

    // MARK: - Exercise

    func testWalkingExerciseInference() {
        var readings: [SensorReading] = []
        // 15 minutes of walking
        for i in 0..<15 {
            readings.append(SensorReading(
                sensorType: .motion,
                timestamp: makeDate(hour: 18, minute: i),
                payload: .motion(activity: .walking, confidence: .high)
            ))
        }
        // High step count for that period
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

    // MARK: - Location Stay

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
        let stays = events.filter { $0.kind == .quietTime && $0.displayName.contains("Home") }
        XCTAssertFalse(stays.isEmpty)
    }

    // MARK: - Blank Period

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
```

- [ ] **Step 2: Implement PhoneInferenceEngine**

```swift
// ToDay/Data/Sensors/PhoneInferenceEngine.swift
import Foundation

final class PhoneInferenceEngine: @unchecked Sendable {

    func inferEvents(from readings: [SensorReading], on date: Date,
                     places: [KnownPlace]) -> [InferredEvent] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)

        let motions = readings.filter { $0.sensorType == .motion }
        let locations = readings.filter { $0.sensorType == .location }
        let pedometers = readings.filter { $0.sensorType == .pedometer }
        let deviceStates = readings.filter { $0.sensorType == .deviceState }

        var events: [InferredEvent] = []
        var coveredIntervals: [DateInterval] = []

        // 1. Sleep
        let sleepEvents = inferSleep(deviceStates: deviceStates, dayStart: dayStart, calendar: calendar)
        for e in sleepEvents {
            events.append(e)
            coveredIntervals.append(DateInterval(start: e.startDate, end: e.endDate))
        }

        // 2. Commute
        let commuteEvents = inferCommute(motions: motions, locations: locations, places: places)
        for e in commuteEvents where !overlaps(e, with: coveredIntervals) {
            events.append(e)
            coveredIntervals.append(DateInterval(start: e.startDate, end: e.endDate))
        }

        // 3. Exercise
        let exerciseEvents = inferExercise(motions: motions, pedometers: pedometers, places: places)
        for e in exerciseEvents where !overlaps(e, with: coveredIntervals) {
            events.append(e)
            coveredIntervals.append(DateInterval(start: e.startDate, end: e.endDate))
        }

        // 4. Location stays
        let stayEvents = inferLocationStays(locations: locations, places: places)
        for e in stayEvents where !overlaps(e, with: coveredIntervals) {
            events.append(e)
            coveredIntervals.append(DateInterval(start: e.startDate, end: e.endDate))
        }

        // 5. Blank periods
        let blankEvents = inferBlankPeriods(
            deviceStates: deviceStates, motions: motions,
            coveredIntervals: coveredIntervals, dayStart: dayStart, places: places, calendar: calendar
        )
        events.append(contentsOf: blankEvents)

        // 6. Merge short consecutive same-type events (gap < 3 min)
        events = mergeConsecutive(events)

        return events.sorted { $0.startDate < $1.startDate }
    }

    // MARK: - Sleep Inference

    private func inferSleep(deviceStates: [SensorReading], dayStart: Date, calendar: Calendar) -> [InferredEvent] {
        var events: [InferredEvent] = []
        let locks = deviceStates.filter { if case .deviceState(.screenLock) = $0.payload { return true }; return false }
        let unlocks = deviceStates.filter { if case .deviceState(.screenUnlock) = $0.payload { return true }; return false }
        let charges = deviceStates.filter { if case .deviceState(.chargingStart) = $0.payload { return true }; return false }

        for lock in locks {
            let nextUnlock = unlocks.first { $0.timestamp > lock.timestamp }
            guard let unlockTime = nextUnlock?.timestamp else { continue }
            let duration = unlockTime.timeIntervalSince(lock.timestamp)
            let hour = calendar.component(.hour, from: lock.timestamp)
            let isCharging = charges.contains { abs($0.timestamp.timeIntervalSince(lock.timestamp)) < 1800 }

            // Night sleep: lock after 20:00 or before 4:00, gap > 2 hours
            if duration > 7200 && (hour >= 20 || hour < 4) {
                let confidence: EventConfidence = isCharging ? .high : .medium
                events.append(InferredEvent(
                    kind: .sleep, startDate: lock.timestamp, endDate: unlockTime,
                    confidence: confidence, displayName: "睡眠",
                    subtitle: String(format: "%.1f 小时", duration / 3600)
                ))
            }
            // Nap: 11:00-17:00, gap > 40 min
            else if duration > 2400 && hour >= 11 && hour < 17 {
                events.append(InferredEvent(
                    kind: .sleep, startDate: lock.timestamp, endDate: unlockTime,
                    confidence: .medium, displayName: "小睡",
                    subtitle: String(format: "%d 分钟", Int(duration / 60))
                ))
            }
        }
        return events
    }

    // MARK: - Commute Inference

    private func inferCommute(motions: [SensorReading], locations: [SensorReading],
                              places: [KnownPlace]) -> [InferredEvent] {
        var events: [InferredEvent] = []
        // Find continuous automotive segments
        let segments = buildSegments(from: motions, matching: .automotive)
        for seg in segments where seg.duration >= 120 { // > 2 min
            var name = "通勤"
            // Try to resolve origin/destination
            let origin = findNearestPlace(to: seg.start, in: locations, places: places)
            let dest = findNearestPlace(to: seg.end, in: locations, places: places)
            if let originName = origin?.name, let destName = dest?.name {
                name = "通勤·\(originName)→\(destName)"
            } else if let destName = dest?.name {
                name = "通勤·去\(destName)"
            }
            events.append(InferredEvent(
                kind: .commute, startDate: seg.start, endDate: seg.end,
                confidence: .medium, displayName: name,
                subtitle: String(format: "%d 分钟", Int(seg.duration / 60))
            ))
        }
        return events
    }

    // MARK: - Exercise Inference

    private func inferExercise(motions: [SensorReading], pedometers: [SensorReading],
                               places: [KnownPlace]) -> [InferredEvent] {
        var events: [InferredEvent] = []

        // Running: any duration
        let runSegments = buildSegments(from: motions, matching: .running)
        for seg in runSegments where seg.duration >= 60 {
            events.append(InferredEvent(
                kind: .workout, startDate: seg.start, endDate: seg.end,
                confidence: .high, displayName: "跑步",
                subtitle: String(format: "%d 分钟", Int(seg.duration / 60))
            ))
        }

        // Cycling
        let cycleSegments = buildSegments(from: motions, matching: .cycling)
        for seg in cycleSegments where seg.duration >= 60 {
            events.append(InferredEvent(
                kind: .workout, startDate: seg.start, endDate: seg.end,
                confidence: .high, displayName: "骑行",
                subtitle: String(format: "%d 分钟", Int(seg.duration / 60))
            ))
        }

        // Walking exercise: > 10 min continuous walking
        let walkSegments = buildSegments(from: motions, matching: .walking)
        for seg in walkSegments where seg.duration >= 600 {
            events.append(InferredEvent(
                kind: .activeWalk, startDate: seg.start, endDate: seg.end,
                confidence: .medium, displayName: "步行",
                subtitle: String(format: "%d 分钟", Int(seg.duration / 60))
            ))
        }

        return events
    }

    // MARK: - Location Stay Inference

    private func inferLocationStays(locations: [SensorReading], places: [KnownPlace]) -> [InferredEvent] {
        var events: [InferredEvent] = []
        let visits = locations.filter { if case .visit = $0.payload { return true }; return false }

        for visit in visits {
            guard case .visit(let lat, let lon, let arrival, let departure) = visit.payload,
                  let dep = departure else { continue }
            let duration = dep.timeIntervalSince(arrival)
            guard duration >= 300 else { continue } // > 5 min

            let place = places.first { p in
                let dist = CLLocation(latitude: lat, longitude: lon)
                    .distance(from: CLLocation(latitude: p.latitude, longitude: p.longitude))
                return dist < p.radius
            }

            let name = place?.name ?? "停留"
            let category = place?.category
            let displayName: String
            switch category {
            case .home: displayName = "在\(name)"
            case .work: displayName = "在\(name)"
            default: displayName = name.isEmpty || name == "停留" ? "停留" : "在\(name)"
            }

            events.append(InferredEvent(
                kind: .quietTime, startDate: arrival, endDate: dep,
                confidence: place != nil ? .medium : .low,
                displayName: displayName,
                subtitle: String(format: "%d 分钟", Int(duration / 60))
            ))
        }
        return events
    }

    // MARK: - Blank Period Detection

    private func inferBlankPeriods(deviceStates: [SensorReading], motions: [SensorReading],
                                   coveredIntervals: [DateInterval], dayStart: Date,
                                   places: [KnownPlace], calendar: Calendar) -> [InferredEvent] {
        var events: [InferredEvent] = []
        let locks = deviceStates.filter { if case .deviceState(.screenLock) = $0.payload { return true }; return false }
        let unlocks = deviceStates.filter { if case .deviceState(.screenUnlock) = $0.payload { return true }; return false }

        for lock in locks {
            let nextUnlock = unlocks.first { $0.timestamp > lock.timestamp }
            guard let unlockTime = nextUnlock?.timestamp else { continue }
            let duration = unlockTime.timeIntervalSince(lock.timestamp)
            let hour = calendar.component(.hour, from: lock.timestamp)

            // Skip if already covered (sleep, commute, etc.)
            let interval = DateInterval(start: lock.timestamp, end: unlockTime)
            if coveredIntervals.contains(where: { $0.intersects(interval) }) { continue }

            // > 15 min, not sleep hours
            guard duration > 900 && hour >= 6 && hour < 22 else { continue }

            // Check if phone was stationary
            let stationaryInPeriod = motions.contains {
                if case .motion(.stationary, _) = $0.payload,
                   $0.timestamp >= lock.timestamp && $0.timestamp <= unlockTime {
                    return true
                }
                return false
            }

            if stationaryInPeriod {
                events.append(InferredEvent(
                    kind: .quietTime, startDate: lock.timestamp, endDate: unlockTime,
                    confidence: .low, displayName: "离开了手机",
                    subtitle: String(format: "%d 分钟", Int(duration / 60))
                ))
            }
        }
        return events
    }

    // MARK: - Segment Building

    private struct TimeSegment {
        let start: Date
        let end: Date
        var duration: TimeInterval { end.timeIntervalSince(start) }
    }

    private func buildSegments(from motions: [SensorReading], matching activity: MotionActivity) -> [TimeSegment] {
        let matching = motions.filter {
            if case .motion(let act, _) = $0.payload { return act == activity }
            return false
        }.sorted { $0.timestamp < $1.timestamp }

        guard !matching.isEmpty else { return [] }
        var segments: [TimeSegment] = []
        var segStart = matching[0].timestamp
        var segEnd = matching[0].endTimestamp ?? matching[0].timestamp.addingTimeInterval(60)

        for i in 1..<matching.count {
            let r = matching[i]
            let rEnd = r.endTimestamp ?? r.timestamp.addingTimeInterval(60)
            if r.timestamp.timeIntervalSince(segEnd) < 180 { // gap < 3 min → merge
                segEnd = max(segEnd, rEnd)
            } else {
                segments.append(TimeSegment(start: segStart, end: segEnd))
                segStart = r.timestamp
                segEnd = rEnd
            }
        }
        segments.append(TimeSegment(start: segStart, end: segEnd))
        return segments
    }

    private func mergeConsecutive(_ events: [InferredEvent]) -> [InferredEvent] {
        let sorted = events.sorted { $0.startDate < $1.startDate }
        guard sorted.count > 1 else { return sorted }
        var result: [InferredEvent] = [sorted[0]]
        for i in 1..<sorted.count {
            let prev = result.last!
            let curr = sorted[i]
            if prev.kind == curr.kind &&
               curr.startDate.timeIntervalSince(prev.endDate) < 180 {
                // Merge: extend previous
                result[result.count - 1] = InferredEvent(
                    kind: prev.kind, startDate: prev.startDate, endDate: curr.endDate,
                    confidence: min(prev.confidence, curr.confidence),
                    displayName: prev.displayName, subtitle: nil
                )
            } else {
                result.append(curr)
            }
        }
        return result
    }

    // MARK: - Helpers

    private func overlaps(_ event: InferredEvent, with intervals: [DateInterval]) -> Bool {
        let interval = DateInterval(start: event.startDate, end: event.endDate)
        return intervals.contains { $0.intersects(interval) }
    }

    private func findNearestPlace(to date: Date, in locations: [SensorReading],
                                  places: [KnownPlace]) -> KnownPlace? {
        let nearbyLoc = locations
            .filter { abs($0.timestamp.timeIntervalSince(date)) < 600 }
            .compactMap { reading -> (Double, Double)? in
                switch reading.payload {
                case .location(let lat, let lon, _): return (lat, lon)
                case .visit(let lat, let lon, _, _): return (lat, lon)
                default: return nil
                }
            }
            .first

        guard let (lat, lon) = nearbyLoc else { return nil }
        return places.first { p in
            CLLocation(latitude: lat, longitude: lon)
                .distance(from: CLLocation(latitude: p.latitude, longitude: p.longitude)) < p.radius
        }
    }
}

// Need CoreLocation for distance calculation
import CoreLocation
```

- [ ] **Step 3: Run `xcodegen generate` then run all tests**

Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add ios/ToDay/ToDay/Data/Sensors/PhoneInferenceEngine.swift ios/ToDay/ToDayTests/PhoneInferenceEngineTests.swift
git commit -m "feat: add PhoneInferenceEngine with sleep, commute, exercise, stay, and blank period inference"
```

---

## Task 10: PhoneTimelineDataProvider

**Files:**
- Create: `ToDay/Data/Sensors/PhoneTimelineDataProvider.swift`
- Test: `ToDayTests/PhoneTimelineDataProviderTests.swift`

- [ ] **Step 1: Write tests**

```swift
// ToDayTests/PhoneTimelineDataProviderTests.swift
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

    @MainActor func testPreExistingReadingsAreInferred() async throws {
        // Pre-populate store with motion data
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
}
```

- [ ] **Step 2: Add `TimelineSource.phone` case**

In `SharedDataTypes.swift`, add:

```swift
enum TimelineSource: String, Codable, Sendable {
    case mock
    case healthKit
    case phone        // NEW

    var badgeTitle: String {
        switch self {
        case .mock: return "模拟"
        case .healthKit: return "健康"
        case .phone: return "手机"
        }
    }
    // Update helperText similarly
}
```

- [ ] **Step 3: Implement PhoneTimelineDataProvider**

```swift
// ToDay/Data/Sensors/PhoneTimelineDataProvider.swift
import Foundation

final class PhoneTimelineDataProvider: TimelineDataProviding, @unchecked Sendable {
    private let collectors: [any SensorCollecting]
    private let store: SensorDataStore
    private let inferenceEngine: PhoneInferenceEngine
    private let placeManager: PlaceManager

    init(collectors: [any SensorCollecting], store: SensorDataStore,
         inferenceEngine: PhoneInferenceEngine, placeManager: PlaceManager) {
        self.collectors = collectors
        self.store = store
        self.inferenceEngine = inferenceEngine
        self.placeManager = placeManager
    }

    func loadTimeline(for date: Date) async throws -> DayTimeline {
        // 1. Collect from all available collectors
        for collector in collectors where collector.isAvailable {
            do {
                try await collector.requestAuthorizationIfNeeded()
                let readings = try await collector.collectData(for: date)
                if !readings.isEmpty {
                    try await MainActor.run { try store.save(readings) }
                }
            } catch {
                // Individual collector failure doesn't block others
                continue
            }
        }

        // 2. Read all stored readings for this day
        let allReadings = try await MainActor.run {
            try store.readings(for: Calendar.current.startOfDay(for: date))
        }

        // 3. Update place visits from location data
        updatePlaces(from: allReadings)

        // 4. Infer events
        let events = inferenceEngine.inferEvents(
            from: allReadings, on: date, places: placeManager.allPlaces
        )

        // 5. Build stats
        let stats = buildStats(from: allReadings, events: events)

        // 6. Build summary
        let summary = buildSummary(events: events)

        return DayTimeline(
            date: Calendar.current.startOfDay(for: date),
            summary: summary, source: .phone, stats: stats, entries: events
        )
    }

    // MARK: - Private

    private func updatePlaces(from readings: [SensorReading]) {
        for reading in readings {
            if case .visit(let lat, let lon, let arrival, let departure) = reading.payload {
                let duration = (departure ?? Date()).timeIntervalSince(arrival)
                placeManager.recordVisit(latitude: lat, longitude: lon, duration: duration, date: arrival)
            }
        }
        placeManager.reclassifyPlaces()
    }

    private func buildStats(from readings: [SensorReading], events: [InferredEvent]) -> [TimelineStat] {
        var stats: [TimelineStat] = []

        // Steps
        let totalSteps = readings
            .compactMap { if case .pedometer(let steps, _, _) = $0.payload { return steps } else { return nil } }
            .reduce(0, +)
        if totalSteps > 0 {
            stats.append(TimelineStat(title: "步数", value: "\(totalSteps)"))
        }

        // Distance
        let totalDist = readings
            .compactMap { if case .pedometer(_, let dist, _) = $0.payload { return dist } else { return nil } }
            .reduce(0, +)
        if totalDist > 0 {
            stats.append(TimelineStat(title: "距离", value: String(format: "%.1fkm", totalDist / 1000)))
        }

        // Event count
        stats.append(TimelineStat(title: "事件", value: "\(events.count)"))

        return stats
    }

    private func buildSummary(events: [InferredEvent]) -> String {
        if events.isEmpty { return "暂无数据" }
        let types = Set(events.map(\.kind))
        var parts: [String] = []
        if types.contains(.sleep) { parts.append("睡眠") }
        if types.contains(.commute) { parts.append("通勤") }
        if types.contains(.workout) || types.contains(.activeWalk) { parts.append("运动") }
        return parts.isEmpty ? "日常记录" : parts.joined(separator: " · ")
    }
}
```

- [ ] **Step 4: Run `xcodegen generate` then run all tests**

Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add ios/ToDay/ToDay/Data/Sensors/PhoneTimelineDataProvider.swift ios/ToDay/ToDayTests/PhoneTimelineDataProviderTests.swift ios/ToDay/ToDay/Shared/SharedDataTypes.swift
git commit -m "feat: add PhoneTimelineDataProvider — collect, store, infer, build timeline"
```

---

## Task 11: Wire into AppContainer + BackgroundTaskManager

**Files:**
- Modify: `ToDay/App/AppContainer.swift`
- Modify: `ToDay/Data/BackgroundTaskManager.swift`
- Modify: `ToDay/App/ToDayApp.swift`

- [ ] **Step 1: Update AppContainer to wire new provider**

In `AppContainer.swift`, add the new static properties and update `makeTimelineProvider()`:

```swift
// Add after existing static properties:
private static let sensorDataStore = SensorDataStore(container: modelContainer)
private static let placeManager = PlaceManager()
private static let phoneInferenceEngine = PhoneInferenceEngine()
private static let deviceStateCollector = DeviceStateCollector(store: sensorDataStore)
private static let locationCollector = LocationCollector(store: sensorDataStore)

static func availableCollectors() -> [any SensorCollecting] {
    var collectors: [any SensorCollecting] = [
        MotionCollector(),
        PedometerCollector(),
        deviceStateCollector,
        locationCollector,
    ]
    let hkCollector = HealthKitCollector()
    if hkCollector.isAvailable {
        collectors.append(hkCollector)
    }
    return collectors
}

// Replace makeTimelineProvider():
static func makeTimelineProvider() -> any TimelineDataProviding {
    #if targetEnvironment(simulator)
    return MockTimelineDataProvider()
    #else
    return PhoneTimelineDataProvider(
        collectors: availableCollectors(),
        store: sensorDataStore,
        inferenceEngine: phoneInferenceEngine,
        placeManager: placeManager
    )
    #endif
}

// Add public accessors:
static func getDeviceStateCollector() -> DeviceStateCollector { deviceStateCollector }
static func getLocationCollector() -> LocationCollector { locationCollector }
static func getSensorDataStore() -> SensorDataStore { sensorDataStore }
```

- [ ] **Step 2: Update BackgroundTaskManager**

Replace direct HealthKit calls with PhoneTimelineDataProvider:

In `BackgroundTaskManager.swift`, update `generateTodayTimeline()` and `backfillRecentTimelines()`:

```swift
// Replace HealthKitTimelineDataProvider() with AppContainer's provider
private func generateTodayTimeline() async {
    let provider = AppContainer.makeTimelineProvider()
    do {
        let timeline = try await provider.loadTimeline(for: Date())
        await persistTimeline(timeline)
        updateLastRecordedDate()
        todayEventCount = timeline.entries.count
    } catch {
        // Silently fail in background — will retry next refresh
    }
}

private func backfillRecentTimelines() async {
    let calendar = Calendar.current
    let provider = AppContainer.makeTimelineProvider()
    for dayOffset in 1...7 {
        guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
        let dayStart = calendar.startOfDay(for: date)
        guard !hasPersistedTimeline(for: dayStart) else { continue }
        do {
            let timeline = try await provider.loadTimeline(for: dayStart)
            await persistTimeline(timeline)
        } catch {
            continue
        }
    }
    // Purge old sensor data
    try? await MainActor.run {
        try AppContainer.getSensorDataStore().purge(olderThan: 30)
    }
}
```

- [ ] **Step 3: Update ToDayApp.swift — start device state and location monitoring**

In `ToDayApp.swift`, add to the `.task` block:

```swift
.task {
    AppContainer.getDeviceStateCollector().startMonitoring()
    AppContainer.getLocationCollector().startMonitoring()
    await echoScheduler.onAppLaunch()
}
```

- [ ] **Step 4: Run `xcodegen generate` then run all tests**

Expected: All tests pass (163+ existing + new tests)

- [ ] **Step 5: Commit**

```bash
git add ios/ToDay/ToDay/App/AppContainer.swift ios/ToDay/ToDay/Data/BackgroundTaskManager.swift ios/ToDay/ToDay/App/ToDayApp.swift
git commit -m "feat: wire PhoneTimelineDataProvider into AppContainer and BackgroundTaskManager"
```

---

## Task 12: Permission Updates + project.yml

**Files:**
- Modify: `project.yml`
- Modify: `ToDay/Info.plist` (via project.yml settings)

- [ ] **Step 1: Add Motion permission and upgrade Location to Always**

In `project.yml`, update the Info.plist settings section:

```yaml
# Add under settings > base > INFOPLIST_KEY_*:
INFOPLIST_KEY_NSMotionUsageDescription: "用于识别你的运动状态（步行、跑步、骑车等），自动记录你的活动"
INFOPLIST_KEY_NSLocationAlwaysAndWhenInUseUsageDescription: "用于自动记录你的位置变化和常去地点，即使 App 在后台也能记录"
```

- [ ] **Step 2: Run `xcodegen generate` then build**

Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add ios/ToDay/project.yml
git commit -m "feat: add Motion permission and upgrade Location to Always for background recording"
```

---

## Task 13: Remove Watch Target + Cleanup

**Files:**
- Modify: `project.yml` (remove Watch target)
- Delete: `ToDayWatch/` directory
- Remove: Old providers (after verifying new ones work)

- [ ] **Step 1: Remove Watch target from project.yml**

Delete the entire `ToDayWatch:` target section and its scheme from `project.yml`.

- [ ] **Step 2: Delete Watch directory**

```bash
rm -rf ios/ToDay/ToDayWatch
```

- [ ] **Step 3: Remove old LocationService (replaced by LocationCollector)**

```bash
rm ios/ToDay/ToDay/Data/LocationService.swift
```

Update any remaining references to `LocationService` in the codebase. The main reference was in `ToDayApp.swift` which was already updated in Task 11.

- [ ] **Step 4: Remove old HealthKit provider and inference engine**

```bash
rm ios/ToDay/ToDay/Data/HealthKitTimelineDataProvider.swift
rm ios/ToDay/ToDay/Data/HealthKitEventInferenceEngine.swift
```

**Important:** Keep `HealthAuthorizationGate` — it's used by `HealthKitCollector`. If it was defined inside `HealthKitTimelineDataProvider.swift`, extract it to `ToDay/Data/Sensors/HealthKitCollector.swift` before deleting.

- [ ] **Step 4b: Remove WatchConnectivity code**

Since there's no standalone Watch app, `WCSession` communication is unnecessary. Watch health data is read via iPhone's HealthKit sync.

```bash
rm ios/ToDay/ToDay/Shared/ConnectivityManager.swift
```

In `TodayViewModel.swift`, remove:
- The `#if os(iOS) ... watchSync` property and all references to it
- The `handleExternalRecordsUpdate()` method (or keep it but remove WCSession trigger)
- Import of ConnectivityManager references

In `AppContainer.swift`, remove:
- `PhoneConnectivityManager.shared` and its configuration
- `makePhoneConnectivityManager()` factory method

- [ ] **Step 5: Run `xcodegen generate` then build and test**

```bash
cd ios/ToDay && xcodegen generate
xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

Expected: Build succeeds, all tests pass. Some existing tests (`EventInferenceEngineTests`) may need updating since the engine they tested is removed — either update to test `PhoneInferenceEngine` or remove tests for deleted code.

- [ ] **Step 6: Fix any broken tests**

If `EventInferenceEngineTests.swift` references `HealthKitEventInferenceEngine`, remove that test file (its logic is now tested in `PhoneInferenceEngineTests`).

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "refactor: remove Watch target, old HealthKit provider, and LocationService — phone-first complete"
```

---

## Task 14: Final Integration Verification

- [ ] **Step 1: Run full test suite**

```bash
cd ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

Expected: All tests pass

- [ ] **Step 2: Build for device (verify signing and entitlements)**

```bash
xcodebuild build -scheme ToDay -destination 'generic/platform=iOS' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

Expected: Build succeeds

- [ ] **Step 3: Verify no Watch target references remain**

```bash
grep -r "ToDayWatch\|WatchConnectivityManager\|LocationService\.shared" ios/ToDay/ToDay/ --include="*.swift" || echo "Clean"
```

Expected: "Clean" or only ConnectivityManager references (which are kept for companion app)

- [ ] **Step 4: Commit version bump**

```bash
# Update version in project.yml if needed, then:
git add -A
git commit -m "chore: phone-first auto recording integration verified"
```

---

## Follow-Up Tasks (not in this plan)

These are described in the design spec but deferred to a separate iteration:

1. **Low-confidence event UI** — `.low` confidence events should show dashed border, semi-transparent, with ? icon and tap-to-confirm interaction. Currently they are produced by the inference engine but displayed with the same style as other events.
2. **Place naming inline card** — Show "you visited a new place" card in timeline when conditions are met (new place, user is active, not asked recently).
3. **Learning feedback storage** — Store `(place, timeSlot, weekday) → activity` mapping when user confirms/corrects a guess, and use it to improve future inference confidence.
