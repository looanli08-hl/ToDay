# Plan 1: Data Model Extensions + Navigation Restructure

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the data model layer with ShutterRecord, SpendingRecord, ScreenTimeRecord types and restructure navigation from 3 tabs to 4 tabs — laying the foundation for all subsequent plans.

**Architecture:** Add new Codable model types following existing patterns (MoodRecord as reference). Extend `EventKind` enum with three new cases. Create SwiftData entities and storage protocols mirroring `MoodRecordEntity`/`MoodRecordStoring`. Restructure `AppRootScreen` tab layout.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, XCTest

**Spec:** `docs/superpowers/specs/2026-03-25-auto-journal-evolution-design.md`

---

## File Structure

### New Files

| File | Responsibility |
|------|----------------|
| `ToDay/Shared/ShutterRecord.swift` | ShutterRecord model, ShutterType enum, EchoConfig struct |
| `ToDay/Shared/SpendingRecord.swift` | SpendingRecord model, SpendingCategory enum |
| `ToDay/Shared/ScreenTimeRecord.swift` | ScreenTimeRecord model, AppUsage struct |
| `ToDay/Data/ShutterRecordEntity.swift` | SwiftData entity for ShutterRecord |
| `ToDay/Data/SpendingRecordEntity.swift` | SwiftData entity for SpendingRecord |
| `ToDay/Data/ShutterRecordStoring.swift` | Protocol + SwiftData store for ShutterRecord |
| `ToDay/Data/SpendingRecordStoring.swift` | Protocol + SwiftData store for SpendingRecord |
| `ToDay/Features/Echo/EchoScreen.swift` | Placeholder Echo tab view |
| `ToDayTests/ShutterRecordStoreTests.swift` | Tests for ShutterRecord persistence |
| `ToDayTests/SpendingRecordStoreTests.swift` | Tests for SpendingRecord persistence |
| `ToDayTests/NewEventKindTests.swift` | Tests for new EventKind cases + InferredEvent creation |

### Modified Files

| File | Changes |
|------|---------|
| `ToDay/Shared/SharedDataTypes.swift` | Add `.shutter`, `.screenTime`, `.spending` to `EventKind` |
| `ToDay/App/AppRootScreen.swift` | 3 tabs → 4 tabs (首页/时间线/Echo/设置) |
| `ToDay/App/AppContainer.swift` | Register new SwiftData entities + stores |
| `ToDay/Data/MockTimelineDataProvider.swift` | Add mock shutter/spending events |

All paths are relative to `ios/ToDay/`.

---

## Task 1: Extend EventKind Enum

**Files:**
- Modify: `ios/ToDay/ToDay/Shared/SharedDataTypes.swift:198-206`
- Create: `ios/ToDay/ToDayTests/NewEventKindTests.swift`

- [ ] **Step 1: Write tests for new EventKind cases**

Create `ios/ToDay/ToDayTests/NewEventKindTests.swift`:

```swift
import XCTest
@testable import ToDay

final class NewEventKindTests: XCTestCase {
    func testShutterKindRawValue() {
        XCTAssertEqual(EventKind.shutter.rawValue, "shutter")
    }

    func testScreenTimeKindRawValue() {
        XCTAssertEqual(EventKind.screenTime.rawValue, "screenTime")
    }

    func testSpendingKindRawValue() {
        XCTAssertEqual(EventKind.spending.rawValue, "spending")
    }

    func testNewKindsAreCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let kinds: [EventKind] = [.shutter, .screenTime, .spending]

        for kind in kinds {
            let data = try encoder.encode(kind)
            let decoded = try decoder.decode(EventKind.self, from: data)
            XCTAssertEqual(decoded, kind)
        }
    }

    func testInferredEventWithShutterKind() {
        let now = Date()
        let event = InferredEvent(
            kind: .shutter,
            startDate: now,
            endDate: now,
            confidence: .high,
            displayName: "有感而发"
        )
        XCTAssertEqual(event.kind, .shutter)
        XCTAssertEqual(event.displayName, "有感而发")
    }

    func testInferredEventWithSpendingKind() {
        let now = Date()
        let event = InferredEvent(
            kind: .spending,
            startDate: now,
            endDate: now,
            confidence: .high,
            displayName: "午餐 ¥35"
        )
        XCTAssertEqual(event.kind, .spending)
    }

    func testInferredEventWithScreenTimeKind() {
        let now = Date()
        let later = now.addingTimeInterval(3600)
        let event = InferredEvent(
            kind: .screenTime,
            startDate: now,
            endDate: later,
            confidence: .medium,
            displayName: "屏幕时间 1h"
        )
        XCTAssertEqual(event.kind, .screenTime)
        XCTAssertEqual(event.duration, 3600, accuracy: 0.1)
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/NewEventKindTests 2>&1 | tail -20`

Expected: Compile error — `EventKind` has no member `shutter`, `screenTime`, `spending`

- [ ] **Step 3: Add new cases to EventKind**

In `ios/ToDay/ToDay/Shared/SharedDataTypes.swift`, find the `EventKind` enum (line 198) and add three cases:

```swift
enum EventKind: String, Codable, CaseIterable, Sendable {
    case sleep
    case workout
    case commute
    case activeWalk
    case quietTime
    case userAnnotated
    case mood
    case shutter
    case screenTime
    case spending
}
```

- [ ] **Step 4: Run tests — expect pass**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/NewEventKindTests 2>&1 | tail -20`

Expected: All 6 tests PASS

- [ ] **Step 5: Run full test suite to check no regressions**

Run: `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All existing tests still pass

- [ ] **Step 6: Commit**

```bash
cd ios/ToDay && git add ToDay/Shared/SharedDataTypes.swift ToDayTests/NewEventKindTests.swift
git commit -m "feat: add shutter, screenTime, spending cases to EventKind"
```

---

## Task 2: ShutterRecord Model + EchoConfig

**Files:**
- Create: `ios/ToDay/ToDay/Shared/ShutterRecord.swift`

- [ ] **Step 1: Create ShutterRecord.swift**

Create `ios/ToDay/ToDay/Shared/ShutterRecord.swift`:

```swift
import Foundation

enum ShutterType: String, Codable, CaseIterable, Sendable {
    case text
    case voice
    case photo
    case video
}

enum EchoFrequency: String, Codable, CaseIterable, Sendable {
    case high    // 1d, 3d, 7d, 30d
    case medium  // 3d, 7d, 30d
    case low     // 7d, 30d
    case off

    var reminderDays: [Int] {
        switch self {
        case .high:   return [1, 3, 7, 30]
        case .medium: return [3, 7, 30]
        case .low:    return [7, 30]
        case .off:    return []
        }
    }
}

struct EchoConfig: Codable, Hashable, Sendable {
    var frequency: EchoFrequency
    var customRemindAt: Date?

    static let `default` = EchoConfig(frequency: .medium, customRemindAt: nil)
}

struct ShutterRecord: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let createdAt: Date
    let type: ShutterType
    var textContent: String?
    var mediaFilename: String?
    var voiceTranscript: String?
    var duration: TimeInterval?
    var latitude: Double?
    var longitude: Double?
    var echoConfig: EchoConfig

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        type: ShutterType,
        textContent: String? = nil,
        mediaFilename: String? = nil,
        voiceTranscript: String? = nil,
        duration: TimeInterval? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        echoConfig: EchoConfig = .default
    ) {
        self.id = id
        self.createdAt = createdAt
        self.type = type
        self.textContent = textContent
        self.mediaFilename = mediaFilename
        self.voiceTranscript = voiceTranscript
        self.duration = duration
        self.latitude = latitude
        self.longitude = longitude
        self.echoConfig = echoConfig
    }

    /// Display text for timeline: content preview or type label
    var displayText: String {
        if let text = textContent, !text.isEmpty {
            return String(text.prefix(50))
        }
        if let transcript = voiceTranscript, !transcript.isEmpty {
            return String(transcript.prefix(50))
        }
        switch type {
        case .text:  return "文字记录"
        case .voice: return "语音记录"
        case .photo: return "照片"
        case .video: return "视频"
        }
    }

    /// Convert to InferredEvent for timeline integration
    func toInferredEvent() -> InferredEvent {
        let endDate = createdAt.addingTimeInterval(duration ?? 0)
        var metrics = EventMetrics()
        if let lat = latitude, let lon = longitude {
            metrics.location = LocationVisit(
                coordinate: CoordinateValue(latitude: lat, longitude: lon),
                arrivalDate: createdAt,
                departureDate: endDate
            )
        }
        return InferredEvent(
            id: id,
            kind: .shutter,
            startDate: createdAt,
            endDate: endDate,
            confidence: .high,
            displayName: displayText,
            subtitle: type.rawValue,
            associatedMetrics: metrics
        )
    }
}
```

- [ ] **Step 2: Regenerate Xcode project and build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
cd ios/ToDay && git add ToDay/Shared/ShutterRecord.swift
git commit -m "feat: add ShutterRecord model with ShutterType and EchoConfig"
```

---

## Task 3: SpendingRecord Model

**Files:**
- Create: `ios/ToDay/ToDay/Shared/SpendingRecord.swift`

- [ ] **Step 1: Create SpendingRecord.swift**

Create `ios/ToDay/ToDay/Shared/SpendingRecord.swift`:

```swift
import Foundation

enum SpendingCategory: String, Codable, CaseIterable, Sendable {
    case food       // 餐饮
    case transport  // 交通
    case shopping   // 购物
    case entertainment // 娱乐
    case daily      // 日用
    case health     // 医疗/健康
    case education  // 教育
    case other      // 其他

    var displayName: String {
        switch self {
        case .food:          return "餐饮"
        case .transport:     return "交通"
        case .shopping:      return "购物"
        case .entertainment: return "娱乐"
        case .daily:         return "日用"
        case .health:        return "医疗"
        case .education:     return "教育"
        case .other:         return "其他"
        }
    }

    var iconName: String {
        switch self {
        case .food:          return "fork.knife"
        case .transport:     return "car.fill"
        case .shopping:      return "bag.fill"
        case .entertainment: return "gamecontroller.fill"
        case .daily:         return "house.fill"
        case .health:        return "heart.fill"
        case .education:     return "book.fill"
        case .other:         return "ellipsis.circle.fill"
        }
    }
}

struct SpendingRecord: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let amount: Double
    let category: SpendingCategory
    var note: String?
    let createdAt: Date
    var latitude: Double?
    var longitude: Double?

    init(
        id: UUID = UUID(),
        amount: Double,
        category: SpendingCategory,
        note: String? = nil,
        createdAt: Date = Date(),
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = id
        self.amount = amount
        self.category = category
        self.note = note
        self.createdAt = createdAt
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Convert to InferredEvent for timeline integration
    func toInferredEvent() -> InferredEvent {
        let displayName = "\(category.displayName) ¥\(String(format: "%.0f", amount))"
        var metrics = EventMetrics()
        if let lat = latitude, let lon = longitude {
            metrics.location = LocationVisit(
                coordinate: CoordinateValue(latitude: lat, longitude: lon),
                arrivalDate: createdAt,
                departureDate: createdAt
            )
        }
        return InferredEvent(
            id: id,
            kind: .spending,
            startDate: createdAt,
            endDate: createdAt,
            confidence: .high,
            displayName: displayName,
            subtitle: note,
            associatedMetrics: metrics
        )
    }
}
```

- [ ] **Step 2: Build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
cd ios/ToDay && git add ToDay/Shared/SpendingRecord.swift
git commit -m "feat: add SpendingRecord model with SpendingCategory"
```

---

## Task 4: ScreenTimeRecord Model

**Files:**
- Create: `ios/ToDay/ToDay/Shared/ScreenTimeRecord.swift`

- [ ] **Step 1: Create ScreenTimeRecord.swift**

Create `ios/ToDay/ToDay/Shared/ScreenTimeRecord.swift`:

```swift
import Foundation

struct AppUsage: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let appName: String
    let category: String
    let duration: TimeInterval

    init(
        id: UUID = UUID(),
        appName: String,
        category: String,
        duration: TimeInterval
    ) {
        self.id = id
        self.appName = appName
        self.category = category
        self.duration = duration
    }

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

struct ScreenTimeRecord: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let dateKey: String
    let totalScreenTime: TimeInterval
    let appUsages: [AppUsage]
    let pickupCount: Int

    init(
        id: UUID = UUID(),
        dateKey: String,
        totalScreenTime: TimeInterval,
        appUsages: [AppUsage] = [],
        pickupCount: Int = 0
    ) {
        self.id = id
        self.dateKey = dateKey
        self.totalScreenTime = totalScreenTime
        self.appUsages = appUsages
        self.pickupCount = pickupCount
    }

    var formattedTotalTime: String {
        let hours = Int(totalScreenTime) / 3600
        let minutes = (Int(totalScreenTime) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
```

- [ ] **Step 2: Build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
cd ios/ToDay && git add ToDay/Shared/ScreenTimeRecord.swift
git commit -m "feat: add ScreenTimeRecord model with AppUsage"
```

---

## Task 5: SwiftData Entities

**Files:**
- Create: `ios/ToDay/ToDay/Data/ShutterRecordEntity.swift`
- Create: `ios/ToDay/ToDay/Data/SpendingRecordEntity.swift`
- Modify: `ios/ToDay/ToDay/App/AppContainer.swift:48-50`

- [ ] **Step 1: Create ShutterRecordEntity.swift**

Create `ios/ToDay/ToDay/Data/ShutterRecordEntity.swift`:

```swift
import Foundation
import SwiftData

@Model
final class ShutterRecordEntity {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var typeRawValue: String
    var textContent: String?
    var mediaFilename: String?
    var voiceTranscript: String?
    var duration: Double?
    var latitude: Double?
    var longitude: Double?
    var echoConfigData: Data

    init(record: ShutterRecord) {
        id = record.id
        createdAt = record.createdAt
        typeRawValue = record.type.rawValue
        textContent = record.textContent
        mediaFilename = record.mediaFilename
        voiceTranscript = record.voiceTranscript
        duration = record.duration
        latitude = record.latitude
        longitude = record.longitude
        echoConfigData = (try? JSONEncoder().encode(record.echoConfig)) ?? Data()
    }

    func update(from record: ShutterRecord) {
        createdAt = record.createdAt
        typeRawValue = record.type.rawValue
        textContent = record.textContent
        mediaFilename = record.mediaFilename
        voiceTranscript = record.voiceTranscript
        duration = record.duration
        latitude = record.latitude
        longitude = record.longitude
        echoConfigData = (try? JSONEncoder().encode(record.echoConfig)) ?? Data()
    }

    func toShutterRecord() -> ShutterRecord {
        let echoConfig = (try? JSONDecoder().decode(EchoConfig.self, from: echoConfigData)) ?? .default
        return ShutterRecord(
            id: id,
            createdAt: createdAt,
            type: ShutterType(rawValue: typeRawValue) ?? .text,
            textContent: textContent,
            mediaFilename: mediaFilename,
            voiceTranscript: voiceTranscript,
            duration: duration,
            latitude: latitude,
            longitude: longitude,
            echoConfig: echoConfig
        )
    }
}
```

- [ ] **Step 2: Create SpendingRecordEntity.swift**

Create `ios/ToDay/ToDay/Data/SpendingRecordEntity.swift`:

```swift
import Foundation
import SwiftData

@Model
final class SpendingRecordEntity {
    @Attribute(.unique) var id: UUID
    var amount: Double
    var categoryRawValue: String
    var note: String?
    var createdAt: Date
    var latitude: Double?
    var longitude: Double?

    init(record: SpendingRecord) {
        id = record.id
        amount = record.amount
        categoryRawValue = record.category.rawValue
        note = record.note
        createdAt = record.createdAt
        latitude = record.latitude
        longitude = record.longitude
    }

    func update(from record: SpendingRecord) {
        amount = record.amount
        categoryRawValue = record.category.rawValue
        note = record.note
        createdAt = record.createdAt
        latitude = record.latitude
        longitude = record.longitude
    }

    func toSpendingRecord() -> SpendingRecord {
        SpendingRecord(
            id: id,
            amount: amount,
            category: SpendingCategory(rawValue: categoryRawValue) ?? .other,
            note: note,
            createdAt: createdAt,
            latitude: latitude,
            longitude: longitude
        )
    }
}
```

- [ ] **Step 3: Register new entities in AppContainer**

In `ios/ToDay/ToDay/App/AppContainer.swift`, modify `makeModelContainer()` to include the new entity types.

Find this line:
```swift
let container = try ModelContainer(for: MoodRecordEntity.self, DayTimelineEntity.self)
```

Replace with:
```swift
let container = try ModelContainer(
    for: MoodRecordEntity.self,
    DayTimelineEntity.self,
    ShutterRecordEntity.self,
    SpendingRecordEntity.self
)
```

- [ ] **Step 4: Build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
cd ios/ToDay && git add ToDay/Data/ShutterRecordEntity.swift ToDay/Data/SpendingRecordEntity.swift ToDay/App/AppContainer.swift
git commit -m "feat: add SwiftData entities for ShutterRecord and SpendingRecord"
```

---

## Task 6: Storage Protocols + SwiftData Stores

**Files:**
- Create: `ios/ToDay/ToDay/Data/ShutterRecordStoring.swift`
- Create: `ios/ToDay/ToDay/Data/SpendingRecordStoring.swift`
- Create: `ios/ToDay/ToDayTests/ShutterRecordStoreTests.swift`
- Create: `ios/ToDay/ToDayTests/SpendingRecordStoreTests.swift`

- [ ] **Step 1: Write ShutterRecordStore tests**

Create `ios/ToDay/ToDayTests/ShutterRecordStoreTests.swift`:

```swift
import SwiftData
import XCTest
@testable import ToDay

final class ShutterRecordStoreTests: XCTestCase {
    func testSaveAndLoadPreservesFields() throws {
        let store = makeStore()
        let record = ShutterRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000801")!,
            createdAt: sampleDate(hour: 14, minute: 30),
            type: .text,
            textContent: "突然想到一个好主意",
            latitude: 31.2304,
            longitude: 121.4737,
            echoConfig: EchoConfig(frequency: .high, customRemindAt: nil)
        )

        try store.save(record)
        let loaded = store.loadAll()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, record.id)
        XCTAssertEqual(loaded[0].type, .text)
        XCTAssertEqual(loaded[0].textContent, "突然想到一个好主意")
        XCTAssertEqual(loaded[0].latitude, 31.2304, accuracy: 0.0001)
        XCTAssertEqual(loaded[0].echoConfig.frequency, .high)
    }

    func testSaveVoiceRecord() throws {
        let store = makeStore()
        let record = ShutterRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000802")!,
            createdAt: sampleDate(hour: 9, minute: 15),
            type: .voice,
            mediaFilename: "voice_001.m4a",
            voiceTranscript: "今天天气真好",
            duration: 5.2
        )

        try store.save(record)
        let loaded = store.loadAll()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].type, .voice)
        XCTAssertEqual(loaded[0].mediaFilename, "voice_001.m4a")
        XCTAssertEqual(loaded[0].voiceTranscript, "今天天气真好")
        XCTAssertEqual(loaded[0].duration, 5.2, accuracy: 0.01)
    }

    func testDeleteRecord() throws {
        let store = makeStore()
        let record = ShutterRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000803")!,
            createdAt: sampleDate(hour: 10, minute: 0),
            type: .photo,
            mediaFilename: "photo_001.jpg"
        )

        try store.save(record)
        try store.delete(record.id)
        let loaded = store.loadAll()

        XCTAssertEqual(loaded.count, 0)
    }

    func testLoadReturnsCreatedAtDescending() throws {
        let store = makeStore()
        let older = ShutterRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000804")!,
            createdAt: sampleDate(hour: 8, minute: 0),
            type: .text,
            textContent: "早上"
        )
        let newer = ShutterRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000805")!,
            createdAt: sampleDate(hour: 12, minute: 0),
            type: .text,
            textContent: "中午"
        )

        try store.save(older)
        try store.save(newer)
        let loaded = store.loadAll()

        XCTAssertEqual(loaded.map(\.id), [newer.id, older.id])
    }

    private func makeStore() -> SwiftDataShutterRecordStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: ShutterRecordEntity.self, configurations: config)
        return SwiftDataShutterRecordStore(container: container)
    }

    private func sampleDate(hour: Int, minute: Int) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        let base = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_710_000_000))
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
    }
}
```

- [ ] **Step 2: Write SpendingRecordStore tests**

Create `ios/ToDay/ToDayTests/SpendingRecordStoreTests.swift`:

```swift
import SwiftData
import XCTest
@testable import ToDay

final class SpendingRecordStoreTests: XCTestCase {
    func testSaveAndLoadPreservesFields() throws {
        let store = makeStore()
        let record = SpendingRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000901")!,
            amount: 35.5,
            category: .food,
            note: "午餐",
            createdAt: sampleDate(hour: 12, minute: 15),
            latitude: 31.2304,
            longitude: 121.4737
        )

        try store.save(record)
        let loaded = store.loadAll()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, record.id)
        XCTAssertEqual(loaded[0].amount, 35.5, accuracy: 0.01)
        XCTAssertEqual(loaded[0].category, .food)
        XCTAssertEqual(loaded[0].note, "午餐")
        XCTAssertEqual(loaded[0].latitude, 31.2304, accuracy: 0.0001)
    }

    func testDeleteRecord() throws {
        let store = makeStore()
        let record = SpendingRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000902")!,
            amount: 15.0,
            category: .transport,
            createdAt: sampleDate(hour: 8, minute: 30)
        )

        try store.save(record)
        try store.delete(record.id)
        let loaded = store.loadAll()

        XCTAssertEqual(loaded.count, 0)
    }

    func testLoadReturnsCreatedAtDescending() throws {
        let store = makeStore()
        let older = SpendingRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000903")!,
            amount: 20.0,
            category: .food,
            createdAt: sampleDate(hour: 8, minute: 0)
        )
        let newer = SpendingRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000904")!,
            amount: 50.0,
            category: .shopping,
            createdAt: sampleDate(hour: 15, minute: 0)
        )

        try store.save(older)
        try store.save(newer)
        let loaded = store.loadAll()

        XCTAssertEqual(loaded.map(\.id), [newer.id, older.id])
    }

    private func makeStore() -> SwiftDataSpendingRecordStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: SpendingRecordEntity.self, configurations: config)
        return SwiftDataSpendingRecordStore(container: container)
    }

    private func sampleDate(hour: Int, minute: Int) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        let base = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_710_000_000))
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
    }
}
```

- [ ] **Step 3: Run tests — expect compile failure**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/ShutterRecordStoreTests -only-testing:ToDayTests/SpendingRecordStoreTests 2>&1 | tail -20`

Expected: Compile error — `SwiftDataShutterRecordStore` and `SwiftDataSpendingRecordStore` not defined

- [ ] **Step 4: Create ShutterRecordStoring.swift**

Create `ios/ToDay/ToDay/Data/ShutterRecordStoring.swift`:

```swift
import Foundation
import SwiftData

protocol ShutterRecordStoring {
    func loadAll() -> [ShutterRecord]
    func loadForDate(_ date: Date) -> [ShutterRecord]
    func save(_ record: ShutterRecord) throws
    func delete(_ id: UUID) throws
}

struct SwiftDataShutterRecordStore: ShutterRecordStoring {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func loadAll() -> [ShutterRecord] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<ShutterRecordEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.includePendingChanges = false

        guard let entities = try? context.fetch(descriptor) else {
            return []
        }
        return entities.map { $0.toShutterRecord() }
    }

    func loadForDate(_ date: Date) -> [ShutterRecord] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let context = ModelContext(container)
        var descriptor = FetchDescriptor<ShutterRecordEntity>(
            predicate: #Predicate { $0.createdAt >= startOfDay && $0.createdAt < endOfDay },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.includePendingChanges = false

        guard let entities = try? context.fetch(descriptor) else {
            return []
        }
        return entities.map { $0.toShutterRecord() }
    }

    func save(_ record: ShutterRecord) throws {
        let context = ModelContext(container)
        let id = record.id
        var descriptor = FetchDescriptor<ShutterRecordEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            existing.update(from: record)
        } else {
            context.insert(ShutterRecordEntity(record: record))
        }

        if context.hasChanges {
            try context.save()
        }
    }

    func delete(_ id: UUID) throws {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<ShutterRecordEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1

        if let entity = try context.fetch(descriptor).first {
            context.delete(entity)
            try context.save()
        }
    }
}
```

- [ ] **Step 5: Create SpendingRecordStoring.swift**

Create `ios/ToDay/ToDay/Data/SpendingRecordStoring.swift`:

```swift
import Foundation
import SwiftData

protocol SpendingRecordStoring {
    func loadAll() -> [SpendingRecord]
    func loadForDate(_ date: Date) -> [SpendingRecord]
    func save(_ record: SpendingRecord) throws
    func delete(_ id: UUID) throws
}

struct SwiftDataSpendingRecordStore: SpendingRecordStoring {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func loadAll() -> [SpendingRecord] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<SpendingRecordEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.includePendingChanges = false

        guard let entities = try? context.fetch(descriptor) else {
            return []
        }
        return entities.map { $0.toSpendingRecord() }
    }

    func loadForDate(_ date: Date) -> [SpendingRecord] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let context = ModelContext(container)
        var descriptor = FetchDescriptor<SpendingRecordEntity>(
            predicate: #Predicate { $0.createdAt >= startOfDay && $0.createdAt < endOfDay },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.includePendingChanges = false

        guard let entities = try? context.fetch(descriptor) else {
            return []
        }
        return entities.map { $0.toSpendingRecord() }
    }

    func save(_ record: SpendingRecord) throws {
        let context = ModelContext(container)
        let id = record.id
        var descriptor = FetchDescriptor<SpendingRecordEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            existing.update(from: record)
        } else {
            context.insert(SpendingRecordEntity(record: record))
        }

        if context.hasChanges {
            try context.save()
        }
    }

    func delete(_ id: UUID) throws {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<SpendingRecordEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1

        if let entity = try context.fetch(descriptor).first {
            context.delete(entity)
            try context.save()
        }
    }
}
```

- [ ] **Step 6: Register stores in AppContainer**

In `ios/ToDay/ToDay/App/AppContainer.swift`, add store properties after the existing `moodRecordStore` line (line 11):

```swift
private static let moodRecordStore = SwiftDataMoodRecordStore(container: modelContainer)
private static let shutterRecordStore = SwiftDataShutterRecordStore(container: modelContainer)
private static let spendingRecordStore = SwiftDataSpendingRecordStore(container: modelContainer)
```

Add factory methods after `makeMoodRecordStore()`:

```swift
static func makeShutterRecordStore() -> any ShutterRecordStoring {
    shutterRecordStore
}

static func makeSpendingRecordStore() -> any SpendingRecordStoring {
    spendingRecordStore
}
```

- [ ] **Step 7: Run tests — expect pass**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/ShutterRecordStoreTests -only-testing:ToDayTests/SpendingRecordStoreTests 2>&1 | tail -20`

Expected: All 8 tests PASS

- [ ] **Step 8: Run full test suite**

Run: `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All tests pass (existing + new)

- [ ] **Step 9: Commit**

```bash
cd ios/ToDay && git add ToDay/Data/ShutterRecordStoring.swift ToDay/Data/SpendingRecordStoring.swift ToDay/App/AppContainer.swift ToDayTests/ShutterRecordStoreTests.swift ToDayTests/SpendingRecordStoreTests.swift
git commit -m "feat: add storage protocols and SwiftData stores for Shutter and Spending records"
```

---

## Task 7: Navigation Restructure (3 Tabs → 4 Tabs)

**Files:**
- Modify: `ios/ToDay/ToDay/App/AppRootScreen.swift`
- Create: `ios/ToDay/ToDay/Features/Echo/EchoScreen.swift`

- [ ] **Step 1: Create placeholder EchoScreen**

Create directory and file `ios/ToDay/ToDay/Features/Echo/EchoScreen.swift`:

```swift
import SwiftUI

struct EchoScreen: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "bell.badge")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("回响")
                    .font(.title2)
                Text("你的灵光一现，会在对的时刻回来找你")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Echo")
        }
    }
}
```

- [ ] **Step 2: Restructure AppRootScreen tabs**

Replace the entire content of `ios/ToDay/ToDay/App/AppRootScreen.swift` with:

```swift
import SwiftUI

private enum AppTab: Hashable {
    case home
    case timeline
    case echo
    case settings
}

struct AppRootScreen: View {
    @AppStorage("today.hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @ObservedObject var todayViewModel: TodayViewModel
    @State private var selectedTab: AppTab = .home

    var body: some View {
        if hasCompletedOnboarding {
            TabView(selection: $selectedTab) {
                TodayScreen(
                    viewModel: todayViewModel,
                    onOpenHistory: { selectedTab = .timeline }
                )
                .tabItem {
                    Label("首页", systemImage: "square.grid.2x2.fill")
                }
                .tag(AppTab.home)

                HistoryScreen(viewModel: todayViewModel)
                .tabItem {
                    Label("时间线", systemImage: "clock.fill")
                }
                .tag(AppTab.timeline)

                EchoScreen()
                .tabItem {
                    Label("Echo", systemImage: "bell.badge.fill")
                }
                .tag(AppTab.echo)

                SettingsView()
                    .tabItem {
                        Label("设置", systemImage: "gear")
                    }
                    .tag(AppTab.settings)
            }
            .tint(TodayTheme.teal)
        } else {
            OnboardingView {
                hasCompletedOnboarding = true
            }
        }
    }
}
```

- [ ] **Step 3: Build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Run full test suite**

Run: `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
cd ios/ToDay && git add ToDay/Features/Echo/EchoScreen.swift ToDay/App/AppRootScreen.swift
git commit -m "feat: restructure navigation to 4 tabs (home, timeline, echo, settings)"
```

---

## Task 8: Update Mock Data with New Event Types

**Files:**
- Modify: `ios/ToDay/ToDay/Data/MockTimelineDataProvider.swift`

- [ ] **Step 1: Add shutter and spending events to mock data**

In `ios/ToDay/ToDay/Data/MockTimelineDataProvider.swift`, find where mock `InferredEvent` entries are created and add new events to the entries array. Add these events among the existing mock events, ordered by time:

```swift
// Add after the morning workout event (around 10:00)
InferredEvent(
    kind: .shutter,
    startDate: time(10, 15),
    endDate: time(10, 15),
    confidence: .high,
    displayName: "路上看到一只猫，很可爱",
    subtitle: "text"
),

// Add around lunch time (12:00-12:30)
InferredEvent(
    kind: .spending,
    startDate: time(12, 20),
    endDate: time(12, 20),
    confidence: .high,
    displayName: "餐饮 ¥35",
    subtitle: "午餐便当"
),

// Add in the afternoon (15:00)
InferredEvent(
    kind: .screenTime,
    startDate: time(13, 0),
    endDate: time(15, 30),
    confidence: .medium,
    displayName: "屏幕时间 2h 30m",
    subtitle: "主要使用：Xcode、Safari"
),

// Add another shutter event (16:00)
InferredEvent(
    kind: .shutter,
    startDate: time(16, 0),
    endDate: time(16, 0),
    confidence: .high,
    displayName: "突然想到一个产品创意...",
    subtitle: "voice"
),

// Add evening spending
InferredEvent(
    kind: .spending,
    startDate: time(18, 30),
    endDate: time(18, 30),
    confidence: .high,
    displayName: "餐饮 ¥68",
    subtitle: "晚餐"
),
```

Also update the mock summary and stats to reflect new data. Add to the stats array:

```swift
TimelineStat(title: "屏幕时间", value: "3h 15m"),
TimelineStat(title: "消费", value: "¥103"),
TimelineStat(title: "快门", value: "2 条"),
```

**Note:** The exact insertion point depends on the existing mock code structure. Place events in chronological order among existing events. Adapt the `time()` helper calls to match the existing pattern in the file.

- [ ] **Step 2: Build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Run full test suite**

Run: `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
cd ios/ToDay && git add ToDay/Data/MockTimelineDataProvider.swift
git commit -m "feat: add shutter, spending, screenTime events to mock data"
```

---

## Summary

After completing all 8 tasks, the codebase will have:

- **3 new model types**: `ShutterRecord`, `SpendingRecord`, `ScreenTimeRecord`
- **2 new SwiftData entities**: `ShutterRecordEntity`, `SpendingRecordEntity`
- **2 new storage protocols + implementations**: `ShutterRecordStoring`, `SpendingRecordStoring`
- **3 new EventKind cases**: `.shutter`, `.screenTime`, `.spending`
- **4-tab navigation**: 首页 / 时间线 / Echo / 设置
- **Placeholder Echo screen**: Ready for Plan 4
- **Updated mock data**: New event types visible in simulator
- **3 new test files**: 14+ new tests covering models and persistence

This provides the complete foundation for Plans 2-5.
