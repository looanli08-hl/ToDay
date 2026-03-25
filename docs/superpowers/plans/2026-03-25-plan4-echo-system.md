# Plan 4: Echo 回响 System

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Echo 回响 system — scheduling local notifications to resurface past ShutterRecords at the right time, persisting echo items with SwiftData, replacing the placeholder EchoScreen with a real UI, adding simple care-nudge rules, and exposing Echo configuration in Settings.

**Architecture:** `EchoEngine` is a `@MainActor` service that sits between `ShutterManager` and `UNUserNotificationCenter`. When a ShutterRecord is saved/deleted, EchoEngine schedules/cancels corresponding local notifications. `EchoItem` tracks each scheduled echo (record ID + scheduled date + viewed status). `CareNudgeEngine` computes simple rule-based messages from recent timeline data. The Echo tab displays today's pending echoes and care nudge cards.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, UserNotifications, XCTest

**Spec:** `docs/superpowers/specs/2026-03-25-auto-journal-evolution-design.md` — Section 5

---

## File Structure

### New Files

| File | Responsibility |
|------|----------------|
| `ToDay/Shared/EchoItem.swift` | EchoItem value type — echo ID, shutter record ID, scheduled date, viewed status |
| `ToDay/Data/EchoItemEntity.swift` | SwiftData entity for EchoItem persistence |
| `ToDay/Data/EchoItemStoring.swift` | Protocol + SwiftData store for EchoItem |
| `ToDay/Data/EchoEngine.swift` | Core engine — schedule/cancel notifications, query today's echoes |
| `ToDay/Data/CareNudgeEngine.swift` | Simple rule-based care nudge message generator |
| `ToDay/Shared/CareNudge.swift` | CareNudge value type — nudge kind, message, icon |
| `ToDay/Features/Echo/EchoViewModel.swift` | ViewModel for Echo screen |
| `ToDay/Features/Echo/EchoCardView.swift` | Card component showing a single echo item |
| `ToDay/Features/Echo/CareNudgeCardView.swift` | Card component showing a care nudge message |
| `ToDay/Features/Echo/EchoDetailSheet.swift` | Detail sheet showing full shutter record context |
| `ToDayTests/EchoItemStoreTests.swift` | Tests for EchoItem persistence |
| `ToDayTests/EchoEngineTests.swift` | Tests for EchoEngine scheduling logic |
| `ToDayTests/CareNudgeEngineTests.swift` | Tests for care nudge rule evaluation |

### Modified Files

| File | Changes |
|------|---------|
| `ToDay/App/AppContainer.swift` | Register `EchoItemEntity` in ModelContainer, create `EchoEngine` + `CareNudgeEngine`, wire into `EchoViewModel` |
| `ToDay/App/AppRootScreen.swift` | Pass `EchoViewModel` to `EchoScreen` |
| `ToDay/Features/Echo/EchoScreen.swift` | Replace placeholder with real echo list UI |
| `ToDay/Features/Settings/SettingsView.swift` | Add Echo configuration section |
| `ToDay/Features/Today/TodayViewModel.swift` | Notify `EchoEngine` on shutter save/delete |

All paths are relative to `ios/ToDay/`.

---

## Task 1: EchoItem Data Model

**Files:**
- Create: `ios/ToDay/ToDay/Shared/EchoItem.swift`

- [ ] **Step 1: Create EchoItem.swift**

Create `ios/ToDay/ToDay/Shared/EchoItem.swift`:

```swift
import Foundation

enum EchoStatus: String, Codable, CaseIterable, Sendable {
    case pending   // scheduled, not yet shown
    case viewed    // user has seen it
    case dismissed // user explicitly dismissed
    case snoozed   // user chose to see later
}

struct EchoItem: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let shutterRecordID: UUID
    let scheduledDate: Date
    var status: EchoStatus
    let reminderDayOffset: Int   // 1, 3, 7, or 30
    let createdAt: Date

    init(
        id: UUID = UUID(),
        shutterRecordID: UUID,
        scheduledDate: Date,
        status: EchoStatus = .pending,
        reminderDayOffset: Int,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.shutterRecordID = shutterRecordID
        self.scheduledDate = scheduledDate
        self.status = status
        self.reminderDayOffset = reminderDayOffset
        self.createdAt = createdAt
    }

    /// Human-readable label for how long ago the original record was captured
    var offsetLabel: String {
        switch reminderDayOffset {
        case 1:  return "1 天前"
        case 3:  return "3 天前"
        case 7:  return "1 周前"
        case 30: return "1 个月前"
        default: return "\(reminderDayOffset) 天前"
        }
    }
}
```

- [ ] **Step 2: Regenerate Xcode project and build**

Run: `cd /Users/looanli/Projects/ToDay/ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
cd /Users/looanli/Projects/ToDay/ios/ToDay && git add ToDay/Shared/EchoItem.swift
git commit -m "feat: add EchoItem model with EchoStatus enum"
```

---

## Task 2: EchoItem SwiftData Entity + Storage Protocol

**Files:**
- Create: `ios/ToDay/ToDay/Data/EchoItemEntity.swift`
- Create: `ios/ToDay/ToDay/Data/EchoItemStoring.swift`
- Create: `ios/ToDay/ToDayTests/EchoItemStoreTests.swift`

- [ ] **Step 1: Write tests for EchoItem persistence**

Create `ios/ToDay/ToDayTests/EchoItemStoreTests.swift`:

```swift
import SwiftData
import XCTest
@testable import ToDay

final class EchoItemStoreTests: XCTestCase {
    func testSaveAndLoadPreservesFields() throws {
        let store = makeStore()
        let item = EchoItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000E01")!,
            shutterRecordID: UUID(uuidString: "00000000-0000-0000-0000-000000000801")!,
            scheduledDate: sampleDate(daysFromNow: 3),
            status: .pending,
            reminderDayOffset: 3
        )

        try store.save(item)
        let loaded = store.loadAll()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, item.id)
        XCTAssertEqual(loaded[0].shutterRecordID, item.shutterRecordID)
        XCTAssertEqual(loaded[0].status, .pending)
        XCTAssertEqual(loaded[0].reminderDayOffset, 3)
    }

    func testLoadPendingForDate() throws {
        let store = makeStore()
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        let todayItem = EchoItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000E02")!,
            shutterRecordID: UUID(uuidString: "00000000-0000-0000-0000-000000000802")!,
            scheduledDate: today,
            status: .pending,
            reminderDayOffset: 1
        )
        let tomorrowItem = EchoItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000E03")!,
            shutterRecordID: UUID(uuidString: "00000000-0000-0000-0000-000000000803")!,
            scheduledDate: tomorrow,
            status: .pending,
            reminderDayOffset: 3
        )

        try store.save(todayItem)
        try store.save(tomorrowItem)
        let pending = store.loadPending(for: today)

        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending[0].id, todayItem.id)
    }

    func testUpdateStatus() throws {
        let store = makeStore()
        var item = EchoItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000E04")!,
            shutterRecordID: UUID(uuidString: "00000000-0000-0000-0000-000000000804")!,
            scheduledDate: sampleDate(daysFromNow: 0),
            status: .pending,
            reminderDayOffset: 7
        )

        try store.save(item)
        item.status = .viewed
        try store.save(item)
        let loaded = store.loadAll()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].status, .viewed)
    }

    func testDeleteByShutterRecordID() throws {
        let store = makeStore()
        let shutterID = UUID(uuidString: "00000000-0000-0000-0000-000000000805")!
        let item1 = EchoItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000E05")!,
            shutterRecordID: shutterID,
            scheduledDate: sampleDate(daysFromNow: 1),
            status: .pending,
            reminderDayOffset: 1
        )
        let item2 = EchoItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000E06")!,
            shutterRecordID: shutterID,
            scheduledDate: sampleDate(daysFromNow: 7),
            status: .pending,
            reminderDayOffset: 7
        )

        try store.save(item1)
        try store.save(item2)
        try store.deleteAll(forShutterRecordID: shutterID)
        let loaded = store.loadAll()

        XCTAssertEqual(loaded.count, 0)
    }

    func testDeleteByID() throws {
        let store = makeStore()
        let item = EchoItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000E07")!,
            shutterRecordID: UUID(uuidString: "00000000-0000-0000-0000-000000000806")!,
            scheduledDate: sampleDate(daysFromNow: 3),
            status: .pending,
            reminderDayOffset: 3
        )

        try store.save(item)
        try store.delete(item.id)
        let loaded = store.loadAll()

        XCTAssertEqual(loaded.count, 0)
    }

    private func makeStore() -> SwiftDataEchoItemStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: EchoItemEntity.self, configurations: config)
        return SwiftDataEchoItemStore(container: container)
    }

    private func sampleDate(daysFromNow offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: Date()))!
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

Run: `cd /Users/looanli/Projects/ToDay/ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/EchoItemStoreTests 2>&1 | tail -20`

Expected: Compile error — `EchoItemEntity`, `SwiftDataEchoItemStore` not found

- [ ] **Step 3: Create EchoItemEntity.swift**

Create `ios/ToDay/ToDay/Data/EchoItemEntity.swift`:

```swift
import Foundation
import SwiftData

@Model
final class EchoItemEntity {
    @Attribute(.unique) var id: UUID
    var shutterRecordID: UUID
    var scheduledDate: Date
    var statusRawValue: String
    var reminderDayOffset: Int
    var createdAt: Date

    init(item: EchoItem) {
        id = item.id
        shutterRecordID = item.shutterRecordID
        scheduledDate = item.scheduledDate
        statusRawValue = item.status.rawValue
        reminderDayOffset = item.reminderDayOffset
        createdAt = item.createdAt
    }

    func update(from item: EchoItem) {
        shutterRecordID = item.shutterRecordID
        scheduledDate = item.scheduledDate
        statusRawValue = item.status.rawValue
        reminderDayOffset = item.reminderDayOffset
        createdAt = item.createdAt
    }

    func toEchoItem() -> EchoItem {
        EchoItem(
            id: id,
            shutterRecordID: shutterRecordID,
            scheduledDate: scheduledDate,
            status: EchoStatus(rawValue: statusRawValue) ?? .pending,
            reminderDayOffset: reminderDayOffset,
            createdAt: createdAt
        )
    }
}
```

- [ ] **Step 4: Create EchoItemStoring.swift**

Create `ios/ToDay/ToDay/Data/EchoItemStoring.swift`:

```swift
import Foundation
import SwiftData

protocol EchoItemStoring {
    func loadAll() -> [EchoItem]
    func loadPending(for date: Date) -> [EchoItem]
    func loadHistory(limit: Int) -> [EchoItem]
    func save(_ item: EchoItem) throws
    func delete(_ id: UUID) throws
    func deleteAll(forShutterRecordID shutterRecordID: UUID) throws
}

struct SwiftDataEchoItemStore: EchoItemStoring {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func loadAll() -> [EchoItem] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<EchoItemEntity>(
            sortBy: [SortDescriptor(\.scheduledDate, order: .reverse)]
        )
        descriptor.includePendingChanges = false

        guard let entities = try? context.fetch(descriptor) else {
            return []
        }
        return entities.map { $0.toEchoItem() }
    }

    func loadPending(for date: Date) -> [EchoItem] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let pendingRaw = EchoStatus.pending.rawValue

        let context = ModelContext(container)
        var descriptor = FetchDescriptor<EchoItemEntity>(
            predicate: #Predicate {
                $0.scheduledDate >= startOfDay
                && $0.scheduledDate < endOfDay
                && $0.statusRawValue == pendingRaw
            },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        descriptor.includePendingChanges = false

        guard let entities = try? context.fetch(descriptor) else {
            return []
        }
        return entities.map { $0.toEchoItem() }
    }

    func loadHistory(limit: Int) -> [EchoItem] {
        let viewedRaw = EchoStatus.viewed.rawValue
        let dismissedRaw = EchoStatus.dismissed.rawValue

        let context = ModelContext(container)
        var descriptor = FetchDescriptor<EchoItemEntity>(
            predicate: #Predicate {
                $0.statusRawValue == viewedRaw || $0.statusRawValue == dismissedRaw
            },
            sortBy: [SortDescriptor(\.scheduledDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        descriptor.includePendingChanges = false

        guard let entities = try? context.fetch(descriptor) else {
            return []
        }
        return entities.map { $0.toEchoItem() }
    }

    func save(_ item: EchoItem) throws {
        let context = ModelContext(container)
        let id = item.id
        var descriptor = FetchDescriptor<EchoItemEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            existing.update(from: item)
        } else {
            context.insert(EchoItemEntity(item: item))
        }

        if context.hasChanges {
            try context.save()
        }
    }

    func delete(_ id: UUID) throws {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<EchoItemEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1

        if let entity = try context.fetch(descriptor).first {
            context.delete(entity)
            try context.save()
        }
    }

    func deleteAll(forShutterRecordID shutterRecordID: UUID) throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<EchoItemEntity>(
            predicate: #Predicate { $0.shutterRecordID == shutterRecordID }
        )

        let entities = try context.fetch(descriptor)
        for entity in entities {
            context.delete(entity)
        }
        if context.hasChanges {
            try context.save()
        }
    }
}
```

- [ ] **Step 5: Run tests — expect pass**

Run: `cd /Users/looanli/Projects/ToDay/ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/EchoItemStoreTests 2>&1 | tail -20`

Expected: All 5 tests PASS

- [ ] **Step 6: Run full test suite to check no regressions**

Run: `cd /Users/looanli/Projects/ToDay/ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All existing tests still pass

- [ ] **Step 7: Commit**

```bash
cd /Users/looanli/Projects/ToDay/ios/ToDay && git add ToDay/Data/EchoItemEntity.swift ToDay/Data/EchoItemStoring.swift ToDayTests/EchoItemStoreTests.swift
git commit -m "feat: add EchoItem SwiftData entity and storage protocol with tests"
```

---

## Task 3: Register EchoItemEntity in AppContainer

**Files:**
- Modify: `ios/ToDay/ToDay/App/AppContainer.swift`

- [ ] **Step 1: Add EchoItemEntity to ModelContainer and create store factory**

In `ios/ToDay/ToDay/App/AppContainer.swift`, add the echo item store as a static property alongside the other stores:

Find the line:
```swift
    private static let screenTimeRecordStore = SwiftDataScreenTimeRecordStore(container: modelContainer)
```

Add after it:
```swift
    private static let echoItemStore = SwiftDataEchoItemStore(container: modelContainer)
```

Find the `makeScreenTimeRecordStore()` function:
```swift
    static func makeScreenTimeRecordStore() -> any ScreenTimeRecordStoring {
        screenTimeRecordStore
    }
```

Add after it:
```swift
    static func makeEchoItemStore() -> any EchoItemStoring {
        echoItemStore
    }
```

Find the `ModelContainer` creation in `makeModelContainer()`:
```swift
            let container = try ModelContainer(
                for: MoodRecordEntity.self,
                DayTimelineEntity.self,
                ShutterRecordEntity.self,
                SpendingRecordEntity.self,
                ScreenTimeRecordEntity.self
            )
```

Add `EchoItemEntity.self`:
```swift
            let container = try ModelContainer(
                for: MoodRecordEntity.self,
                DayTimelineEntity.self,
                ShutterRecordEntity.self,
                SpendingRecordEntity.self,
                ScreenTimeRecordEntity.self,
                EchoItemEntity.self
            )
```

- [ ] **Step 2: Build**

Run: `cd /Users/looanli/Projects/ToDay/ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
cd /Users/looanli/Projects/ToDay/ios/ToDay && git add ToDay/App/AppContainer.swift
git commit -m "feat: register EchoItemEntity in AppContainer ModelContainer"
```

---

## Task 4: EchoEngine — Core Scheduling Logic

**Files:**
- Create: `ios/ToDay/ToDay/Data/EchoEngine.swift`
- Create: `ios/ToDay/ToDayTests/EchoEngineTests.swift`

- [ ] **Step 1: Write tests for EchoEngine scheduling logic**

Create `ios/ToDay/ToDayTests/EchoEngineTests.swift`:

```swift
import SwiftData
import XCTest
@testable import ToDay

final class EchoEngineTests: XCTestCase {
    func testScheduleCreatesEchoItemsForMediumFrequency() async throws {
        let (engine, echoStore, _) = makeEngine()
        let record = makeShutterRecord(echoFrequency: .medium)

        await engine.scheduleEchoes(for: record)

        let items = echoStore.loadAll()
        // medium frequency = 3, 7, 30 day offsets
        XCTAssertEqual(items.count, 3)
        let offsets = Set(items.map(\.reminderDayOffset))
        XCTAssertEqual(offsets, [3, 7, 30])
    }

    func testScheduleCreatesEchoItemsForHighFrequency() async throws {
        let (engine, echoStore, _) = makeEngine()
        let record = makeShutterRecord(echoFrequency: .high)

        await engine.scheduleEchoes(for: record)

        let items = echoStore.loadAll()
        // high frequency = 1, 3, 7, 30 day offsets
        XCTAssertEqual(items.count, 4)
        let offsets = Set(items.map(\.reminderDayOffset))
        XCTAssertEqual(offsets, [1, 3, 7, 30])
    }

    func testScheduleCreatesNoItemsForOffFrequency() async throws {
        let (engine, echoStore, _) = makeEngine()
        let record = makeShutterRecord(echoFrequency: .off)

        await engine.scheduleEchoes(for: record)

        let items = echoStore.loadAll()
        XCTAssertEqual(items.count, 0)
    }

    func testCancelRemovesAllEchoItemsForRecord() async throws {
        let (engine, echoStore, _) = makeEngine()
        let record = makeShutterRecord(echoFrequency: .medium)

        await engine.scheduleEchoes(for: record)
        XCTAssertEqual(echoStore.loadAll().count, 3)

        await engine.cancelEchoes(forShutterRecordID: record.id)

        let items = echoStore.loadAll()
        XCTAssertEqual(items.count, 0)
    }

    func testScheduledDatesAreCorrect() async throws {
        let (engine, echoStore, _) = makeEngine()
        let createdAt = Date()
        let record = ShutterRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000901")!,
            createdAt: createdAt,
            type: .text,
            textContent: "Test",
            echoConfig: EchoConfig(frequency: .low)
        )

        await engine.scheduleEchoes(for: record)

        let items = echoStore.loadAll().sorted { $0.reminderDayOffset < $1.reminderDayOffset }
        let calendar = Calendar.current
        // low = 7, 30
        XCTAssertEqual(items.count, 2)
        XCTAssert(calendar.isDate(
            items[0].scheduledDate,
            inSameDayAs: calendar.date(byAdding: .day, value: 7, to: createdAt)!
        ))
        XCTAssert(calendar.isDate(
            items[1].scheduledDate,
            inSameDayAs: calendar.date(byAdding: .day, value: 30, to: createdAt)!
        ))
    }

    func testTodayEchoesReturnsPendingForToday() async throws {
        let (engine, echoStore, _) = makeEngine()
        let today = Calendar.current.startOfDay(for: Date())
        let shutterID = UUID(uuidString: "00000000-0000-0000-0000-000000000902")!

        let todayItem = EchoItem(
            shutterRecordID: shutterID,
            scheduledDate: today,
            status: .pending,
            reminderDayOffset: 3
        )
        try echoStore.save(todayItem)

        let pending = await engine.todayEchoes()
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending[0].shutterRecordID, shutterID)
    }

    func testMarkAsViewedUpdatesStatus() async throws {
        let (engine, echoStore, _) = makeEngine()
        let item = EchoItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000E10")!,
            shutterRecordID: UUID(uuidString: "00000000-0000-0000-0000-000000000903")!,
            scheduledDate: Calendar.current.startOfDay(for: Date()),
            status: .pending,
            reminderDayOffset: 1
        )
        try echoStore.save(item)

        await engine.markAsViewed(echoID: item.id)

        let loaded = echoStore.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].status, .viewed)
    }

    func testDismissUpdatesStatus() async throws {
        let (engine, echoStore, _) = makeEngine()
        let item = EchoItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000E11")!,
            shutterRecordID: UUID(uuidString: "00000000-0000-0000-0000-000000000904")!,
            scheduledDate: Calendar.current.startOfDay(for: Date()),
            status: .pending,
            reminderDayOffset: 7
        )
        try echoStore.save(item)

        await engine.dismiss(echoID: item.id)

        let loaded = echoStore.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].status, .dismissed)
    }

    func testSnoozeReschedulesToTomorrow() async throws {
        let (engine, echoStore, _) = makeEngine()
        let today = Calendar.current.startOfDay(for: Date())
        let item = EchoItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000E12")!,
            shutterRecordID: UUID(uuidString: "00000000-0000-0000-0000-000000000905")!,
            scheduledDate: today,
            status: .pending,
            reminderDayOffset: 3
        )
        try echoStore.save(item)

        await engine.snooze(echoID: item.id)

        let loaded = echoStore.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].status, .snoozed)
        // Should have a new pending item for tomorrow
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let tomorrowPending = echoStore.loadPending(for: tomorrow)
        XCTAssertEqual(tomorrowPending.count, 1)
    }

    // MARK: - Helpers

    private func makeEngine() -> (EchoEngine, SwiftDataEchoItemStore, MockNotificationCenter) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: EchoItemEntity.self, configurations: config)
        let echoStore = SwiftDataEchoItemStore(container: container)
        let mockNotifications = MockNotificationCenter()
        let engine = EchoEngine(
            echoStore: echoStore,
            notificationScheduler: mockNotifications
        )
        return (engine, echoStore, mockNotifications)
    }

    private func makeShutterRecord(echoFrequency: EchoFrequency) -> ShutterRecord {
        ShutterRecord(
            type: .text,
            textContent: "Test record",
            echoConfig: EchoConfig(frequency: echoFrequency)
        )
    }
}

/// Mock notification center for testing — does not actually post notifications
final class MockNotificationCenter: EchoNotificationScheduling {
    private(set) var scheduledIdentifiers: [String] = []
    private(set) var removedIdentifiers: [String] = []

    func scheduleEchoNotification(identifier: String, title: String, body: String, triggerDate: Date) {
        scheduledIdentifiers.append(identifier)
    }

    func removeNotifications(identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

Run: `cd /Users/looanli/Projects/ToDay/ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/EchoEngineTests 2>&1 | tail -20`

Expected: Compile error — `EchoEngine`, `EchoNotificationScheduling` not found

- [ ] **Step 3: Create EchoEngine.swift**

Create `ios/ToDay/ToDay/Data/EchoEngine.swift`:

```swift
import Foundation
import UserNotifications

// MARK: - Notification Scheduling Protocol

protocol EchoNotificationScheduling: Sendable {
    func scheduleEchoNotification(identifier: String, title: String, body: String, triggerDate: Date)
    func removeNotifications(identifiers: [String])
}

// MARK: - UNUserNotificationCenter Conformance

final class SystemNotificationScheduler: EchoNotificationScheduling {
    func scheduleEchoNotification(identifier: String, title: String, body: String, triggerDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "ECHO_REMINDER"

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[EchoEngine] Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }

    func removeNotifications(identifiers: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

// MARK: - Echo Engine

@MainActor
final class EchoEngine {
    private let echoStore: any EchoItemStoring
    private let notificationScheduler: any EchoNotificationScheduling
    private let calendar: Calendar

    /// User preference: default echo time of day (hour component, 0-23). Default = 9 (9:00 AM)
    var echoHour: Int {
        get { UserDefaults.standard.integer(forKey: "today.echo.hour").clamped(to: 0...23, default: 9) }
        set { UserDefaults.standard.set(newValue, forKey: "today.echo.hour") }
    }

    /// User preference: care nudges enabled
    var careNudgesEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "today.echo.careNudges") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "today.echo.careNudges") }
    }

    /// User preference: global echo frequency override (nil = use per-record config)
    var globalFrequency: EchoFrequency? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: "today.echo.globalFrequency") else { return nil }
            return EchoFrequency(rawValue: raw)
        }
        set { UserDefaults.standard.set(newValue?.rawValue, forKey: "today.echo.globalFrequency") }
    }

    init(
        echoStore: any EchoItemStoring,
        notificationScheduler: any EchoNotificationScheduling = SystemNotificationScheduler(),
        calendar: Calendar = .current
    ) {
        self.echoStore = echoStore
        self.notificationScheduler = notificationScheduler
        self.calendar = calendar
    }

    // MARK: - Scheduling

    /// Schedule echo reminders for a newly saved ShutterRecord
    func scheduleEchoes(for record: ShutterRecord) {
        let frequency = globalFrequency ?? record.echoConfig.frequency
        guard frequency != .off else { return }

        let reminderDays = frequency.reminderDays

        for dayOffset in reminderDays {
            guard let scheduledDate = echoDate(from: record.createdAt, dayOffset: dayOffset) else { continue }

            let item = EchoItem(
                shutterRecordID: record.id,
                scheduledDate: scheduledDate,
                status: .pending,
                reminderDayOffset: dayOffset
            )

            try? echoStore.save(item)

            // Schedule local notification
            let preview = record.displayText
            let identifier = notificationIdentifier(echoID: item.id)
            notificationScheduler.scheduleEchoNotification(
                identifier: identifier,
                title: "回响",
                body: "\(item.offsetLabel)你说：「\(preview)」",
                triggerDate: scheduledDate
            )
        }
    }

    /// Cancel all echoes for a deleted ShutterRecord
    func cancelEchoes(forShutterRecordID shutterRecordID: UUID) {
        let items = echoStore.loadAll().filter { $0.shutterRecordID == shutterRecordID }
        let identifiers = items.map { notificationIdentifier(echoID: $0.id) }

        if !identifiers.isEmpty {
            notificationScheduler.removeNotifications(identifiers: identifiers)
        }

        try? echoStore.deleteAll(forShutterRecordID: shutterRecordID)
    }

    // MARK: - Queries

    /// Get today's pending echoes
    func todayEchoes() -> [EchoItem] {
        echoStore.loadPending(for: Date())
    }

    /// Get past viewed/dismissed echoes
    func echoHistory(limit: Int = 50) -> [EchoItem] {
        echoStore.loadHistory(limit: limit)
    }

    // MARK: - Actions

    /// Mark an echo as viewed
    func markAsViewed(echoID: UUID) {
        guard var item = findItem(id: echoID) else { return }
        item.status = .viewed
        try? echoStore.save(item)
    }

    /// Dismiss an echo
    func dismiss(echoID: UUID) {
        guard var item = findItem(id: echoID) else { return }
        item.status = .dismissed
        try? echoStore.save(item)

        // Cancel any pending notification
        notificationScheduler.removeNotifications(identifiers: [notificationIdentifier(echoID: echoID)])
    }

    /// Snooze an echo to tomorrow
    func snooze(echoID: UUID) {
        guard var item = findItem(id: echoID) else { return }

        // Mark original as snoozed
        item.status = .snoozed
        try? echoStore.save(item)

        // Cancel original notification
        notificationScheduler.removeNotifications(identifiers: [notificationIdentifier(echoID: echoID)])

        // Create new echo for tomorrow
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        guard let tomorrowDate = echoDateForHour(on: tomorrow) else { return }

        let newItem = EchoItem(
            shutterRecordID: item.shutterRecordID,
            scheduledDate: tomorrowDate,
            status: .pending,
            reminderDayOffset: item.reminderDayOffset
        )
        try? echoStore.save(newItem)

        // Schedule new notification
        notificationScheduler.scheduleEchoNotification(
            identifier: notificationIdentifier(echoID: newItem.id),
            title: "回响",
            body: "你有一条待查看的回响",
            triggerDate: tomorrowDate
        )
    }

    // MARK: - Notification Permissions

    /// Request notification authorization if not already granted
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                print("[EchoEngine] Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private Helpers

    private func findItem(id: UUID) -> EchoItem? {
        echoStore.loadAll().first { $0.id == id }
    }

    private func echoDate(from recordDate: Date, dayOffset: Int) -> Date? {
        guard let targetDay = calendar.date(byAdding: .day, value: dayOffset, to: recordDate) else { return nil }
        return echoDateForHour(on: targetDay)
    }

    private func echoDateForHour(on date: Date) -> Date? {
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(bySettingHour: echoHour, minute: 0, second: 0, of: startOfDay)
    }

    private func notificationIdentifier(echoID: UUID) -> String {
        "echo-\(echoID.uuidString)"
    }
}

// MARK: - Int Clamped Extension

private extension Int {
    func clamped(to range: ClosedRange<Int>, default defaultValue: Int) -> Int {
        if self == 0 && UserDefaults.standard.object(forKey: "today.echo.hour") == nil {
            return defaultValue
        }
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
```

- [ ] **Step 4: Run tests — expect pass**

Run: `cd /Users/looanli/Projects/ToDay/ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/EchoEngineTests 2>&1 | tail -20`

Expected: All 9 tests PASS

- [ ] **Step 5: Run full test suite to check no regressions**

Run: `cd /Users/looanli/Projects/ToDay/ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All existing tests still pass

- [ ] **Step 6: Commit**

```bash
cd /Users/looanli/Projects/ToDay/ios/ToDay && git add ToDay/Data/EchoEngine.swift ToDayTests/EchoEngineTests.swift
git commit -m "feat: add EchoEngine with notification scheduling, cancel, snooze logic"
```

---

## Task 5: CareNudge Model + Engine

**Files:**
- Create: `ios/ToDay/ToDay/Shared/CareNudge.swift`
- Create: `ios/ToDay/ToDay/Data/CareNudgeEngine.swift`
- Create: `ios/ToDay/ToDayTests/CareNudgeEngineTests.swift`

- [ ] **Step 1: Write tests for CareNudgeEngine**

Create `ios/ToDay/ToDayTests/CareNudgeEngineTests.swift`:

```swift
import XCTest
@testable import ToDay

final class CareNudgeEngineTests: XCTestCase {
    func testConsecutiveWorkoutDaysReturnsEncouragement() {
        let engine = CareNudgeEngine()
        // 3 consecutive days with workouts
        let timelines = (0..<3).map { dayOffset -> DayTimeline in
            let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date())!
            let workout = InferredEvent(
                kind: .workout,
                startDate: date,
                endDate: date.addingTimeInterval(1800),
                confidence: .high,
                displayName: "跑步"
            )
            return DayTimeline(
                date: date,
                summary: "",
                source: .mock,
                stats: [],
                entries: [workout]
            )
        }

        let nudges = engine.evaluate(recentTimelines: timelines, shutterRecords: [])

        XCTAssertTrue(nudges.contains(where: { $0.kind == .exerciseStreak }))
    }

    func testHighScreenTimeReturnsReminder() {
        let engine = CareNudgeEngine()
        let today = Date()
        let screenTimeEvent = InferredEvent(
            kind: .screenTime,
            startDate: today,
            endDate: today,
            confidence: .high,
            displayName: "屏幕时间 8h"
        )
        let timeline = DayTimeline(
            date: today,
            summary: "",
            source: .mock,
            stats: [TimelineStat(title: "屏幕时间", value: "8h 0m")],
            entries: [screenTimeEvent]
        )

        let nudges = engine.evaluate(
            recentTimelines: [timeline],
            shutterRecords: [],
            screenTimeHours: 8.0
        )

        XCTAssertTrue(nudges.contains(where: { $0.kind == .highScreenTime }))
    }

    func testNoShutterRecordsForDaysReturnsCheckIn() {
        let engine = CareNudgeEngine()
        // No shutter records, 5 days of timelines
        let timelines = (0..<5).map { dayOffset -> DayTimeline in
            let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date())!
            return DayTimeline(date: date, summary: "", source: .mock, stats: [], entries: [])
        }

        let nudges = engine.evaluate(recentTimelines: timelines, shutterRecords: [])

        XCTAssertTrue(nudges.contains(where: { $0.kind == .noShutterCheckIn }))
    }

    func testNoNudgesWhenDataNormal() {
        let engine = CareNudgeEngine()
        let today = Date()
        let record = ShutterRecord(
            createdAt: today,
            type: .text,
            textContent: "Normal day"
        )
        let timeline = DayTimeline(date: today, summary: "", source: .mock, stats: [], entries: [])

        let nudges = engine.evaluate(
            recentTimelines: [timeline],
            shutterRecords: [record],
            screenTimeHours: 2.0
        )

        // Should have no nudges: only 1 day (no exercise streak), screen time normal, has shutter records
        XCTAssertFalse(nudges.contains(where: { $0.kind == .exerciseStreak }))
        XCTAssertFalse(nudges.contains(where: { $0.kind == .highScreenTime }))
        XCTAssertFalse(nudges.contains(where: { $0.kind == .noShutterCheckIn }))
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

Run: `cd /Users/looanli/Projects/ToDay/ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/CareNudgeEngineTests 2>&1 | tail -20`

Expected: Compile error — `CareNudge`, `CareNudgeEngine` not found

- [ ] **Step 3: Create CareNudge.swift**

Create `ios/ToDay/ToDay/Shared/CareNudge.swift`:

```swift
import Foundation

enum CareNudgeKind: String, Codable, CaseIterable, Sendable {
    case exerciseStreak    // consecutive workout days
    case highScreenTime    // screen time above threshold
    case noShutterCheckIn  // no shutter records for days
}

struct CareNudge: Identifiable, Hashable, Sendable {
    let id: UUID
    let kind: CareNudgeKind
    let message: String
    let subtitle: String?
    let iconName: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        kind: CareNudgeKind,
        message: String,
        subtitle: String? = nil,
        iconName: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.message = message
        self.subtitle = subtitle
        self.iconName = iconName
        self.createdAt = createdAt
    }
}
```

- [ ] **Step 4: Create CareNudgeEngine.swift**

Create `ios/ToDay/ToDay/Data/CareNudgeEngine.swift`:

```swift
import Foundation

final class CareNudgeEngine {
    /// Minimum consecutive workout days to trigger encouragement
    private let exerciseStreakThreshold = 3

    /// Screen time hours threshold for gentle reminder
    private let screenTimeHoursThreshold: Double = 6.0

    /// Days without shutter records to trigger check-in
    private let noShutterDaysThreshold = 3

    /// Evaluate recent data and return applicable care nudges.
    ///
    /// - Parameters:
    ///   - recentTimelines: Recent day timelines, most recent first
    ///   - shutterRecords: All available shutter records
    ///   - screenTimeHours: Today's screen time in hours (optional, used for high screen time check)
    /// - Returns: Array of CareNudge messages to show
    func evaluate(
        recentTimelines: [DayTimeline],
        shutterRecords: [ShutterRecord],
        screenTimeHours: Double? = nil
    ) -> [CareNudge] {
        var nudges: [CareNudge] = []

        if let exerciseNudge = checkExerciseStreak(timelines: recentTimelines) {
            nudges.append(exerciseNudge)
        }

        if let screenTimeNudge = checkScreenTime(hours: screenTimeHours) {
            nudges.append(screenTimeNudge)
        }

        if let shutterNudge = checkShutterActivity(records: shutterRecords) {
            nudges.append(shutterNudge)
        }

        return nudges
    }

    // MARK: - Rule: Consecutive Exercise Days

    private func checkExerciseStreak(timelines: [DayTimeline]) -> CareNudge? {
        let calendar = Calendar.current
        var consecutiveDays = 0

        // Sort by date descending (most recent first)
        let sorted = timelines.sorted { $0.date > $1.date }

        for (index, timeline) in sorted.enumerated() {
            let hasWorkout = timeline.entries.contains { $0.kind == .workout }
            if hasWorkout {
                // Check that this day is consecutive with the previous one
                if index == 0 {
                    consecutiveDays = 1
                } else {
                    let previousDate = sorted[index - 1].date
                    let daysBetween = calendar.dateComponents([.day], from: timeline.date, to: previousDate).day ?? 0
                    if daysBetween == 1 {
                        consecutiveDays += 1
                    } else {
                        break
                    }
                }
            } else {
                break
            }
        }

        guard consecutiveDays >= exerciseStreakThreshold else { return nil }

        return CareNudge(
            kind: .exerciseStreak,
            message: "连续 \(consecutiveDays) 天运动了，太棒了！",
            subtitle: "坚持下去，身体会感谢你的",
            iconName: "flame.fill"
        )
    }

    // MARK: - Rule: High Screen Time

    private func checkScreenTime(hours: Double?) -> CareNudge? {
        guard let hours, hours >= screenTimeHoursThreshold else { return nil }

        let hoursInt = Int(hours)
        return CareNudge(
            kind: .highScreenTime,
            message: "今天屏幕时间已经 \(hoursInt) 小时了",
            subtitle: "站起来走走，看看窗外的风景吧",
            iconName: "iphone.gen3.slash"
        )
    }

    // MARK: - Rule: No Shutter Records

    private func checkShutterActivity(records: [ShutterRecord]) -> CareNudge? {
        let calendar = Calendar.current
        let now = Date()

        // Find the most recent shutter record
        let sorted = records.sorted { $0.createdAt > $1.createdAt }

        if let latest = sorted.first {
            let daysSince = calendar.dateComponents([.day], from: latest.createdAt, to: now).day ?? 0
            guard daysSince >= noShutterDaysThreshold else { return nil }

            return CareNudge(
                kind: .noShutterCheckIn,
                message: "已经 \(daysSince) 天没有记录了",
                subtitle: "哪怕一句话，也值得被记住",
                iconName: "camera.metering.unknown"
            )
        } else {
            // No records at all
            return CareNudge(
                kind: .noShutterCheckIn,
                message: "试试记录一下生活中的小事吧",
                subtitle: "一段文字、一张照片、一句语音，都可以",
                iconName: "camera.metering.unknown"
            )
        }
    }
}
```

- [ ] **Step 5: Run tests — expect pass**

Run: `cd /Users/looanli/Projects/ToDay/ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/CareNudgeEngineTests 2>&1 | tail -20`

Expected: All 4 tests PASS

- [ ] **Step 6: Run full test suite to check no regressions**

Run: `cd /Users/looanli/Projects/ToDay/ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All existing tests still pass

- [ ] **Step 7: Commit**

```bash
cd /Users/looanli/Projects/ToDay/ios/ToDay && git add ToDay/Shared/CareNudge.swift ToDay/Data/CareNudgeEngine.swift ToDayTests/CareNudgeEngineTests.swift
git commit -m "feat: add CareNudge model and CareNudgeEngine with rule-based nudges"
```

---

## Task 6: EchoViewModel

**Files:**
- Create: `ios/ToDay/ToDay/Features/Echo/EchoViewModel.swift`

- [ ] **Step 1: Create EchoViewModel.swift**

Create `ios/ToDay/ToDay/Features/Echo/EchoViewModel.swift`:

```swift
import Foundation
import SwiftData

@MainActor
final class EchoViewModel: ObservableObject {
    // MARK: - Published State

    @Published private(set) var todayEchoes: [EchoItem] = []
    @Published private(set) var careNudges: [CareNudge] = []
    @Published private(set) var historyEchoes: [EchoItem] = []
    @Published private(set) var isLoading = false
    @Published var selectedEchoItem: EchoItem?

    // MARK: - Dependencies

    private let echoEngine: EchoEngine
    private let careNudgeEngine: CareNudgeEngine
    private let shutterRecordStore: any ShutterRecordStoring
    private let screenTimeStore: any ScreenTimeRecordStoring

    // Store a reference to load shutter records for display
    private var shutterRecordCache: [UUID: ShutterRecord] = [:]

    init(
        echoEngine: EchoEngine,
        careNudgeEngine: CareNudgeEngine = CareNudgeEngine(),
        shutterRecordStore: any ShutterRecordStoring,
        screenTimeStore: any ScreenTimeRecordStoring
    ) {
        self.echoEngine = echoEngine
        self.careNudgeEngine = careNudgeEngine
        self.shutterRecordStore = shutterRecordStore
        self.screenTimeStore = screenTimeStore
    }

    // MARK: - Loading

    func load(recentTimelines: [DayTimeline] = []) {
        isLoading = true

        // Load today's echoes
        todayEchoes = echoEngine.todayEchoes()

        // Load history
        historyEchoes = echoEngine.echoHistory(limit: 30)

        // Cache shutter records for display
        let allRecords = shutterRecordStore.loadAll()
        shutterRecordCache = Dictionary(uniqueKeysWithValues: allRecords.map { ($0.id, $0) })

        // Compute care nudges if enabled
        if echoEngine.careNudgesEnabled {
            let dateKey = Self.dateKeyFormatter.string(from: Date())
            let screenTimeRecord = screenTimeStore.loadForDateKey(dateKey)
            let screenTimeHours = screenTimeRecord.map { $0.totalScreenTime / 3600.0 }

            careNudges = careNudgeEngine.evaluate(
                recentTimelines: recentTimelines,
                shutterRecords: allRecords,
                screenTimeHours: screenTimeHours
            )
        } else {
            careNudges = []
        }

        isLoading = false
    }

    // MARK: - Actions

    func markAsViewed(_ echoItem: EchoItem) {
        echoEngine.markAsViewed(echoID: echoItem.id)
        todayEchoes = echoEngine.todayEchoes()
        historyEchoes = echoEngine.echoHistory(limit: 30)
    }

    func dismiss(_ echoItem: EchoItem) {
        echoEngine.dismiss(echoID: echoItem.id)
        todayEchoes = echoEngine.todayEchoes()
    }

    func snooze(_ echoItem: EchoItem) {
        echoEngine.snooze(echoID: echoItem.id)
        todayEchoes = echoEngine.todayEchoes()
    }

    // MARK: - Data Lookup

    /// Get the ShutterRecord for an echo item
    func shutterRecord(for echoItem: EchoItem) -> ShutterRecord? {
        shutterRecordCache[echoItem.shutterRecordID]
    }

    // MARK: - Echo Settings (Passthrough)

    var echoHour: Int {
        get { echoEngine.echoHour }
        set {
            echoEngine.echoHour = newValue
            objectWillChange.send()
        }
    }

    var careNudgesEnabled: Bool {
        get { echoEngine.careNudgesEnabled }
        set {
            echoEngine.careNudgesEnabled = newValue
            objectWillChange.send()
        }
    }

    var globalFrequency: EchoFrequency? {
        get { echoEngine.globalFrequency }
        set {
            echoEngine.globalFrequency = newValue
            objectWillChange.send()
        }
    }

    // MARK: - Formatters

    private static let dateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
```

- [ ] **Step 2: Build**

Run: `cd /Users/looanli/Projects/ToDay/ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
cd /Users/looanli/Projects/ToDay/ios/ToDay && git add ToDay/Features/Echo/EchoViewModel.swift
git commit -m "feat: add EchoViewModel with echo loading, actions, and care nudge integration"
```

---

## Task 7: Echo UI Components

**Files:**
- Create: `ios/ToDay/ToDay/Features/Echo/EchoCardView.swift`
- Create: `ios/ToDay/ToDay/Features/Echo/CareNudgeCardView.swift`
- Create: `ios/ToDay/ToDay/Features/Echo/EchoDetailSheet.swift`

- [ ] **Step 1: Create EchoCardView.swift**

Create `ios/ToDay/ToDay/Features/Echo/EchoCardView.swift`:

```swift
import SwiftUI

struct EchoCardView: View {
    let echoItem: EchoItem
    let shutterRecord: ShutterRecord?
    let onTap: () -> Void
    let onDismiss: () -> Void
    let onSnooze: () -> Void

    var body: some View {
        ContentCard {
            VStack(alignment: .leading, spacing: 12) {
                // Header: offset label + type badge
                HStack {
                    EyebrowLabel(echoItem.offsetLabel.uppercased())

                    Spacer()

                    if let record = shutterRecord {
                        Image(systemName: iconName(for: record.type))
                            .font(.system(size: 12))
                            .foregroundStyle(TodayTheme.inkMuted)
                    }
                }

                // Content preview
                if let record = shutterRecord {
                    Text(record.displayText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(TodayTheme.ink)
                        .lineLimit(3)
                } else {
                    Text("记录已删除")
                        .font(.system(size: 14))
                        .foregroundStyle(TodayTheme.inkMuted)
                        .italic()
                }

                // Timestamp
                if let record = shutterRecord {
                    Text(Self.dateFormatter.string(from: record.createdAt))
                        .font(.system(size: 12))
                        .foregroundStyle(TodayTheme.inkFaint)
                }

                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        onTap()
                    } label: {
                        Text("查看")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(TodayTheme.teal)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(TodayTheme.tealSoft)
                            .clipShape(Capsule())
                    }

                    Button {
                        onSnooze()
                    } label: {
                        Text("明天再看")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(TodayTheme.inkMuted)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(TodayTheme.elevatedCard)
                            .clipShape(Capsule())
                    }

                    Spacer()

                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(TodayTheme.inkFaint)
                            .frame(width: 28, height: 28)
                            .background(TodayTheme.elevatedCard)
                            .clipShape(Circle())
                    }
                }
            }
        }
    }

    private func iconName(for type: ShutterType) -> String {
        switch type {
        case .text:  return "text.quote"
        case .voice: return "waveform"
        case .photo: return "photo"
        case .video: return "video"
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 HH:mm"
        return f
    }()
}
```

- [ ] **Step 2: Create CareNudgeCardView.swift**

Create `ios/ToDay/ToDay/Features/Echo/CareNudgeCardView.swift`:

```swift
import SwiftUI

struct CareNudgeCardView: View {
    let nudge: CareNudge

    var body: some View {
        ContentCard(background: cardBackground) {
            HStack(spacing: 14) {
                Image(systemName: nudge.iconName)
                    .font(.system(size: 22))
                    .foregroundStyle(iconColor)
                    .frame(width: 40, height: 40)
                    .background(iconBackground)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(nudge.message)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(TodayTheme.ink)

                    if let subtitle = nudge.subtitle {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(TodayTheme.inkMuted)
                    }
                }

                Spacer()
            }
        }
    }

    private var cardBackground: Color {
        switch nudge.kind {
        case .exerciseStreak:
            return TodayTheme.tealSoft
        case .highScreenTime:
            return TodayTheme.orangeSoft
        case .noShutterCheckIn:
            return TodayTheme.purpleSoft
        }
    }

    private var iconColor: Color {
        switch nudge.kind {
        case .exerciseStreak:
            return TodayTheme.teal
        case .highScreenTime:
            return TodayTheme.orange
        case .noShutterCheckIn:
            return TodayTheme.purple
        }
    }

    private var iconBackground: Color {
        switch nudge.kind {
        case .exerciseStreak:
            return TodayTheme.teal.opacity(0.15)
        case .highScreenTime:
            return TodayTheme.orange.opacity(0.15)
        case .noShutterCheckIn:
            return TodayTheme.purple.opacity(0.15)
        }
    }
}
```

- [ ] **Step 3: Create EchoDetailSheet.swift**

Create `ios/ToDay/ToDay/Features/Echo/EchoDetailSheet.swift`:

```swift
import SwiftUI

struct EchoDetailSheet: View {
    let echoItem: EchoItem
    let shutterRecord: ShutterRecord?
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Offset label
                    HStack {
                        Text(echoItem.offsetLabel)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(TodayTheme.teal)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(TodayTheme.tealSoft)
                            .clipShape(Capsule())

                        Spacer()
                    }

                    if let record = shutterRecord {
                        // Content
                        VStack(alignment: .leading, spacing: 12) {
                            // Type indicator
                            HStack(spacing: 6) {
                                Image(systemName: iconName(for: record.type))
                                    .font(.system(size: 13))
                                    .foregroundStyle(TodayTheme.inkMuted)
                                Text(typeLabel(for: record.type))
                                    .font(.system(size: 13))
                                    .foregroundStyle(TodayTheme.inkMuted)
                            }

                            // Main content
                            if let text = record.textContent, !text.isEmpty {
                                Text(text)
                                    .font(.system(size: 18, weight: .regular))
                                    .foregroundStyle(TodayTheme.ink)
                                    .lineSpacing(6)
                            }

                            if let transcript = record.voiceTranscript, !transcript.isEmpty {
                                Text(transcript)
                                    .font(.system(size: 18, weight: .regular))
                                    .foregroundStyle(TodayTheme.ink)
                                    .lineSpacing(6)
                            }

                            if record.type == .voice, let duration = record.duration {
                                HStack(spacing: 6) {
                                    Image(systemName: "waveform")
                                        .font(.system(size: 13))
                                    Text(formatDuration(duration))
                                        .font(.system(size: 13))
                                }
                                .foregroundStyle(TodayTheme.inkMuted)
                            }
                        }

                        Divider()
                            .overlay(TodayTheme.border)

                        // Context: when
                        VStack(alignment: .leading, spacing: 8) {
                            EyebrowLabel("记录时间")
                            Text(Self.fullDateFormatter.string(from: record.createdAt))
                                .font(.system(size: 15))
                                .foregroundStyle(TodayTheme.ink)
                        }

                        // Context: location (if available)
                        if record.latitude != nil && record.longitude != nil {
                            VStack(alignment: .leading, spacing: 8) {
                                EyebrowLabel("位置")
                                Text("(\(String(format: "%.4f", record.latitude!)), \(String(format: "%.4f", record.longitude!)))")
                                    .font(.system(size: 15))
                                    .foregroundStyle(TodayTheme.ink)
                            }
                        }
                    } else {
                        // Record deleted
                        VStack(spacing: 12) {
                            Image(systemName: "doc.questionmark")
                                .font(.system(size: 32))
                                .foregroundStyle(TodayTheme.inkFaint)
                            Text("原始记录已被删除")
                                .font(.system(size: 15))
                                .foregroundStyle(TodayTheme.inkMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
                .padding(20)
            }
            .background(TodayTheme.background)
            .navigationTitle("回响详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        onDismiss()
                        dismiss()
                    }
                    .foregroundStyle(TodayTheme.teal)
                }
            }
        }
    }

    private func iconName(for type: ShutterType) -> String {
        switch type {
        case .text:  return "text.quote"
        case .voice: return "waveform"
        case .photo: return "photo"
        case .video: return "video"
        }
    }

    private func typeLabel(for type: ShutterType) -> String {
        switch type {
        case .text:  return "文字记录"
        case .voice: return "语音记录"
        case .photo: return "照片"
        case .video: return "视频"
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        if seconds < 60 {
            return "\(seconds)秒"
        }
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return "\(minutes)分\(remainingSeconds)秒"
    }

    private static let fullDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月d日 EEEE HH:mm"
        return f
    }()
}
```

- [ ] **Step 4: Build**

Run: `cd /Users/looanli/Projects/ToDay/ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
cd /Users/looanli/Projects/ToDay/ios/ToDay && git add ToDay/Features/Echo/EchoCardView.swift ToDay/Features/Echo/CareNudgeCardView.swift ToDay/Features/Echo/EchoDetailSheet.swift
git commit -m "feat: add EchoCardView, CareNudgeCardView, and EchoDetailSheet UI components"
```

---

## Task 8: Replace Placeholder EchoScreen

**Files:**
- Modify: `ios/ToDay/ToDay/Features/Echo/EchoScreen.swift`

- [ ] **Step 1: Replace EchoScreen with real implementation**

Replace the entire contents of `ios/ToDay/ToDay/Features/Echo/EchoScreen.swift`:

```swift
import SwiftUI

struct EchoScreen: View {
    @ObservedObject var viewModel: EchoViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if viewModel.isLoading {
                        ProgressView()
                            .padding(.top, 40)
                    } else if viewModel.todayEchoes.isEmpty && viewModel.careNudges.isEmpty {
                        emptyState
                    } else {
                        // Today's echoes section
                        if !viewModel.todayEchoes.isEmpty {
                            sectionHeader("今日回响", count: viewModel.todayEchoes.count)

                            ForEach(viewModel.todayEchoes) { echoItem in
                                EchoCardView(
                                    echoItem: echoItem,
                                    shutterRecord: viewModel.shutterRecord(for: echoItem),
                                    onTap: {
                                        viewModel.markAsViewed(echoItem)
                                        viewModel.selectedEchoItem = echoItem
                                    },
                                    onDismiss: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            viewModel.dismiss(echoItem)
                                        }
                                    },
                                    onSnooze: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            viewModel.snooze(echoItem)
                                        }
                                    }
                                )
                            }
                        }

                        // Care nudges section
                        if !viewModel.careNudges.isEmpty {
                            sectionHeader("关怀", count: nil)

                            ForEach(viewModel.careNudges) { nudge in
                                CareNudgeCardView(nudge: nudge)
                            }
                        }

                        // History section
                        if !viewModel.historyEchoes.isEmpty {
                            sectionHeader("历史回响", count: nil)

                            ForEach(viewModel.historyEchoes) { echoItem in
                                historyRow(echoItem)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(TodayTheme.background)
            .navigationTitle("Echo")
            .sheet(item: $viewModel.selectedEchoItem) { echoItem in
                EchoDetailSheet(
                    echoItem: echoItem,
                    shutterRecord: viewModel.shutterRecord(for: echoItem),
                    onDismiss: {
                        viewModel.selectedEchoItem = nil
                    }
                )
            }
            .onAppear {
                viewModel.load()
            }
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 60)

            Image(systemName: "bell.badge")
                .font(.system(size: 48))
                .foregroundStyle(TodayTheme.inkFaint)

            Text("回响")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(TodayTheme.ink)

            Text("你的灵光一现，会在对的时刻回来找你")
                .font(.system(size: 15))
                .foregroundStyle(TodayTheme.inkMuted)
                .multilineTextAlignment(.center)

            Text("使用快门记录生活碎片后，它们会在未来合适的日子重新出现")
                .font(.system(size: 13))
                .foregroundStyle(TodayTheme.inkFaint)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private func sectionHeader(_ title: String, count: Int?) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(TodayTheme.inkMuted)
                .tracking(1.2)

            if let count {
                Text("\(count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TodayTheme.teal)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(TodayTheme.tealSoft)
                    .clipShape(Capsule())
            }

            Spacer()
        }
        .padding(.top, 8)
    }

    private func historyRow(_ echoItem: EchoItem) -> some View {
        let record = viewModel.shutterRecord(for: echoItem)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(record?.displayText ?? "记录已删除")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(TodayTheme.ink)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(echoItem.offsetLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(TodayTheme.inkMuted)

                    Text("·")
                        .foregroundStyle(TodayTheme.inkFaint)

                    Text(Self.shortDateFormatter.string(from: echoItem.scheduledDate))
                        .font(.system(size: 12))
                        .foregroundStyle(TodayTheme.inkFaint)
                }
            }

            Spacer()

            statusBadge(echoItem.status)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(TodayTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(TodayTheme.border, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func statusBadge(_ status: EchoStatus) -> some View {
        let (text, color): (String, Color) = {
            switch status {
            case .pending:   return ("待查看", TodayTheme.teal)
            case .viewed:    return ("已查看", TodayTheme.inkMuted)
            case .dismissed: return ("已跳过", TodayTheme.inkFaint)
            case .snoozed:   return ("已推迟", TodayTheme.accent)
            }
        }()

        return Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(color)
    }

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M/d"
        return f
    }()
}
```

- [ ] **Step 2: Build — expect compile failure due to EchoScreen signature change**

The new `EchoScreen` requires `viewModel` parameter. The next task will fix the call site.

Run: `cd /Users/looanli/Projects/ToDay/ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: Compile error in `AppRootScreen.swift` — `EchoScreen()` needs `viewModel` argument

- [ ] **Step 3: Commit (partial — will fix call site in next task)**

```bash
cd /Users/looanli/Projects/ToDay/ios/ToDay && git add ToDay/Features/Echo/EchoScreen.swift
git commit -m "feat: replace placeholder EchoScreen with real echo list UI"
```

---

## Task 9: Wire EchoEngine + EchoViewModel into AppContainer and AppRootScreen

**Files:**
- Modify: `ios/ToDay/ToDay/App/AppContainer.swift`
- Modify: `ios/ToDay/ToDay/App/AppRootScreen.swift`

- [ ] **Step 1: Add EchoEngine and EchoViewModel factories to AppContainer**

In `ios/ToDay/ToDay/App/AppContainer.swift`, add after the `echoItemStore` static property:

```swift
    @MainActor
    private static let echoEngine = EchoEngine(
        echoStore: echoItemStore
    )
```

Add a factory method after `makeEchoItemStore()`:

```swift
    @MainActor
    static func makeEchoViewModel() -> EchoViewModel {
        EchoViewModel(
            echoEngine: echoEngine,
            shutterRecordStore: makeShutterRecordStore(),
            screenTimeStore: makeScreenTimeRecordStore()
        )
    }
```

Also expose `echoEngine` for TodayViewModel to use:

```swift
    @MainActor
    static func getEchoEngine() -> EchoEngine {
        echoEngine
    }
```

- [ ] **Step 2: Update AppRootScreen to pass EchoViewModel**

In `ios/ToDay/ToDay/App/AppRootScreen.swift`, add a new property:

Find:
```swift
    @ObservedObject var todayViewModel: TodayViewModel
    @State private var selectedTab: AppTab = .home
```

Add after:
```swift
    @ObservedObject var echoViewModel: EchoViewModel
```

Find:
```swift
                    EchoScreen()
```

Replace with:
```swift
                    EchoScreen(viewModel: echoViewModel)
```

- [ ] **Step 3: Update the call site that creates AppRootScreen**

Find the file that instantiates `AppRootScreen` and add the `echoViewModel` parameter.

Search for `AppRootScreen(` in the codebase. In `ios/ToDay/ToDay/App/ToDayApp.swift` (or wherever the root is created), find:

```swift
AppRootScreen(todayViewModel: todayViewModel)
```

Add `echoViewModel`:

```swift
AppRootScreen(todayViewModel: todayViewModel, echoViewModel: echoViewModel)
```

Make sure `echoViewModel` is created at the app level using:

```swift
@StateObject private var echoViewModel = AppContainer.makeEchoViewModel()
```

- [ ] **Step 4: Build**

Run: `cd /Users/looanli/Projects/ToDay/ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Run full test suite**

Run: `cd /Users/looanli/Projects/ToDay/ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
cd /Users/looanli/Projects/ToDay/ios/ToDay && git add ToDay/App/AppContainer.swift ToDay/App/AppRootScreen.swift ToDay/App/ToDayApp.swift
git commit -m "feat: wire EchoEngine and EchoViewModel into AppContainer and AppRootScreen"
```

---

## Task 10: Integrate EchoEngine with TodayViewModel (Shutter Save/Delete)

**Files:**
- Modify: `ios/ToDay/ToDay/Features/Today/TodayViewModel.swift`

- [ ] **Step 1: Add EchoEngine dependency to TodayViewModel**

In `ios/ToDay/ToDay/Features/Today/TodayViewModel.swift`, add a new stored property in the `// MARK: - Managers` section:

Find:
```swift
    private let annotationStore: AnnotationStore
```

Add after:
```swift
    private let echoEngine: EchoEngine?
```

- [ ] **Step 2: Accept EchoEngine in init**

Find the init signature and add `echoEngine` parameter:

In the init parameter list, after `insightComposer: TodayInsightComposer = TodayInsightComposer(),` add:

```swift
        echoEngine: EchoEngine? = nil,
```

In the init body, after `self.annotationStore = AnnotationStore(calendar: calendar)`, add:

```swift
        self.echoEngine = echoEngine
```

- [ ] **Step 3: Call EchoEngine when saving a ShutterRecord**

Find the `saveShutterRecord` method:

```swift
    func saveShutterRecord(_ record: ShutterRecord) {
        shutterManager.save(record)
        showShutterPanel = false
        isRecordingVoice = false
        rebuildTimeline(referenceDate: currentBaseTimeline?.date ?? Date())
    }
```

Replace with:

```swift
    func saveShutterRecord(_ record: ShutterRecord) {
        shutterManager.save(record)
        echoEngine?.scheduleEchoes(for: record)
        showShutterPanel = false
        isRecordingVoice = false
        rebuildTimeline(referenceDate: currentBaseTimeline?.date ?? Date())
    }
```

- [ ] **Step 4: Call EchoEngine when deleting a ShutterRecord**

Find the `deleteShutterRecord` method:

```swift
    func deleteShutterRecord(id: UUID) {
        shutterManager.delete(id: id)
        rebuildTimeline(referenceDate: currentBaseTimeline?.date ?? Date())
    }
```

Replace with:

```swift
    func deleteShutterRecord(id: UUID) {
        shutterManager.delete(id: id)
        echoEngine?.cancelEchoes(forShutterRecordID: id)
        rebuildTimeline(referenceDate: currentBaseTimeline?.date ?? Date())
    }
```

- [ ] **Step 5: Pass EchoEngine from AppContainer**

In `ios/ToDay/ToDay/App/AppContainer.swift`, update `makeTodayViewModel()`:

Find:
```swift
        let viewModel = TodayViewModel(
            provider: makeTimelineProvider(),
            recordStore: makeMoodRecordStore(),
            shutterRecordStore: makeShutterRecordStore(),
            spendingRecordStore: makeSpendingRecordStore(),
            screenTimeRecordStore: makeScreenTimeRecordStore(),
            phoneConnectivityManager: phoneConnectivityManager,
            modelContainer: modelContainer
        )
```

Replace with:

```swift
        let viewModel = TodayViewModel(
            provider: makeTimelineProvider(),
            recordStore: makeMoodRecordStore(),
            shutterRecordStore: makeShutterRecordStore(),
            spendingRecordStore: makeSpendingRecordStore(),
            screenTimeRecordStore: makeScreenTimeRecordStore(),
            echoEngine: echoEngine,
            phoneConnectivityManager: phoneConnectivityManager,
            modelContainer: modelContainer
        )
```

- [ ] **Step 6: Build**

Run: `cd /Users/looanli/Projects/ToDay/ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 7: Run full test suite**

Run: `cd /Users/looanli/Projects/ToDay/ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All tests pass (existing tests pass echoEngine=nil by default)

- [ ] **Step 8: Commit**

```bash
cd /Users/looanli/Projects/ToDay/ios/ToDay && git add ToDay/Features/Today/TodayViewModel.swift ToDay/App/AppContainer.swift
git commit -m "feat: integrate EchoEngine with TodayViewModel for shutter save/delete hooks"
```

---

## Task 11: Echo Settings Section in SettingsView

**Files:**
- Modify: `ios/ToDay/ToDay/Features/Settings/SettingsView.swift`

- [ ] **Step 1: Add EchoViewModel to SettingsView**

In `ios/ToDay/ToDay/Features/Settings/SettingsView.swift`, add a property:

Find:
```swift
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
```

Add after `@Environment(\.modelContext) private var modelContext`:

```swift
    @ObservedObject var echoViewModel: EchoViewModel
```

- [ ] **Step 2: Add Echo configuration section**

In the `body`, find the `Section("数据权限")` closing brace and add a new section after it:

After:
```swift
                Section("数据权限") {
                    ...
                }
```

Add:

```swift
                Section("Echo 回响") {
                    // Global frequency
                    HStack {
                        Text("回响频率")
                            .foregroundStyle(TodayTheme.ink)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { echoViewModel.globalFrequency ?? .medium },
                            set: { echoViewModel.globalFrequency = $0 }
                        )) {
                            Text("高").tag(EchoFrequency.high)
                            Text("中").tag(EchoFrequency.medium)
                            Text("低").tag(EchoFrequency.low)
                            Text("关闭").tag(EchoFrequency.off)
                        }
                        .pickerStyle(.menu)
                        .tint(TodayTheme.teal)
                    }

                    // Echo hour
                    HStack {
                        Text("回响时间")
                            .foregroundStyle(TodayTheme.ink)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { echoViewModel.echoHour },
                            set: { echoViewModel.echoHour = $0 }
                        )) {
                            ForEach(6..<23, id: \.self) { hour in
                                Text(String(format: "%02d:00", hour)).tag(hour)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(TodayTheme.teal)
                    }

                    // Care nudges toggle
                    Toggle(isOn: Binding(
                        get: { echoViewModel.careNudgesEnabled },
                        set: { echoViewModel.careNudgesEnabled = $0 }
                    )) {
                        Text("关怀推送")
                            .foregroundStyle(TodayTheme.ink)
                    }
                    .tint(TodayTheme.teal)
                }
```

- [ ] **Step 3: Update all SettingsView call sites to pass echoViewModel**

Find all places `SettingsView()` is instantiated (likely in `AppRootScreen.swift`):

Find:
```swift
                    SettingsView()
```

Replace with:
```swift
                    SettingsView(echoViewModel: echoViewModel)
```

- [ ] **Step 4: Build**

Run: `cd /Users/looanli/Projects/ToDay/ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
cd /Users/looanli/Projects/ToDay/ios/ToDay && git add ToDay/Features/Settings/SettingsView.swift ToDay/App/AppRootScreen.swift
git commit -m "feat: add Echo configuration section to SettingsView"
```

---

## Task 12: Request Notification Permission on First Echo Schedule

**Files:**
- Modify: `ios/ToDay/ToDay/Data/EchoEngine.swift`

- [ ] **Step 1: Auto-request permission on first schedule**

In `ios/ToDay/ToDay/Data/EchoEngine.swift`, add a stored property to track if permission was requested:

Find:
```swift
    private let calendar: Calendar
```

Add after:
```swift
    private var hasRequestedPermission = false
```

In the `scheduleEchoes(for:)` method, add permission request at the top:

Find:
```swift
    func scheduleEchoes(for record: ShutterRecord) {
        let frequency = globalFrequency ?? record.echoConfig.frequency
        guard frequency != .off else { return }
```

Replace with:
```swift
    func scheduleEchoes(for record: ShutterRecord) {
        let frequency = globalFrequency ?? record.echoConfig.frequency
        guard frequency != .off else { return }

        if !hasRequestedPermission {
            requestNotificationPermission()
            hasRequestedPermission = true
        }
```

- [ ] **Step 2: Build**

Run: `cd /Users/looanli/Projects/ToDay/ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Run full test suite**

Run: `cd /Users/looanli/Projects/ToDay/ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
cd /Users/looanli/Projects/ToDay/ios/ToDay && git add ToDay/Data/EchoEngine.swift
git commit -m "feat: auto-request notification permission on first echo schedule"
```

---

## Task 13: Final Integration Build + Full Test Suite

**Files:** None (verification only)

- [ ] **Step 1: Regenerate Xcode project**

Run: `cd /Users/looanli/Projects/ToDay/ios/ToDay && xcodegen generate`

- [ ] **Step 2: Full build**

Run: `cd /Users/looanli/Projects/ToDay/ios/ToDay && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Full test suite**

Run: `cd /Users/looanli/Projects/ToDay/ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All tests pass (including the 3 new test files: EchoItemStoreTests, EchoEngineTests, CareNudgeEngineTests)

- [ ] **Step 4: Verify Watch build is not broken**

Run: `cd /Users/looanli/Projects/ToDay/ios/ToDay && xcodebuild build -scheme ToDayWatch -destination 'generic/platform=watchOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED (new files are in `ToDay/Data/` and `ToDay/Features/Echo/`, not in `ToDay/Shared/`, so Watch target only picks up the Shared types)

**Note:** `EchoItem.swift` and `CareNudge.swift` are in `ToDay/Shared/` and will be compiled into the Watch target via `project.yml` config (`- path: ToDay/Shared`). Verify that these files have no iOS-only imports (they don't — they only use Foundation). `EchoItemEntity.swift` is in `ToDay/Data/` which is only compiled for the iOS target, so no watch issues.

- [ ] **Step 5: Commit (if any last-minute fixes were needed)**

```bash
cd /Users/looanli/Projects/ToDay/ios/ToDay && git status
# Only commit if there are changes
```
