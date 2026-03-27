# Plan 5: New Data Sources (Screen Time + Spending Input)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add spending input UI, screen time manual input UI, a `SpendingManager` for managing spending records, a `ScreenTimeRecordStoring` persistence layer, and integrate both data sources into the timeline via `TodayViewModel`.

**Architecture:** Create `SpendingManager` (mirrors `MoodRecordManager` pattern) to own spending CRUD. Add `ScreenTimeRecordEntity` + `ScreenTimeRecordStoring` for screen time persistence. Build `SpendingInputView` as a bottom sheet for quick spending entry. Build `ScreenTimeInputView` for manual daily screen time input. Add `toInferredEvent()` to `ScreenTimeRecord`. Merge spending and screen time records into `TodayViewModel.mergedTimeline()` alongside existing mood records.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, XCTest

**Spec:** `docs/superpowers/specs/2026-03-25-auto-journal-evolution-design.md` (sections 7.1, 7.2)

**Important:** Screen Time API (`DeviceActivityReport`) requires Family Controls entitlement and a separate App Extension target. Per spec: "如工程量过大可推迟到 MVP 之后". This plan uses **manual input only** for screen time. The automated `DeviceActivityReport` approach is noted as future work.

---

## File Structure

### New Files

| File | Responsibility |
|------|----------------|
| `ToDay/Data/SpendingManager.swift` | Manages spending record CRUD, mirrors `MoodRecordManager` pattern |
| `ToDay/Data/ScreenTimeRecordEntity.swift` | SwiftData entity for ScreenTimeRecord |
| `ToDay/Data/ScreenTimeRecordStoring.swift` | Protocol + SwiftData store for ScreenTimeRecord |
| `ToDay/Features/Today/SpendingInputView.swift` | Sheet/modal for quick spending entry |
| `ToDay/Features/Today/ScreenTimeInputView.swift` | Sheet/modal for manual screen time input |
| `ToDayTests/ScreenTimeRecordStoreTests.swift` | Tests for ScreenTimeRecord persistence |
| `ToDayTests/SpendingManagerTests.swift` | Tests for SpendingManager logic |
| `ToDayTests/TimelineMergeTests.swift` | Tests for spending + screen time timeline merge |

### Modified Files

| File | Changes |
|------|---------|
| `ToDay/Shared/ScreenTimeRecord.swift` | Add `toInferredEvent()` method |
| `ToDay/App/AppContainer.swift` | Register `ScreenTimeRecordEntity`, add `ScreenTimeRecordStoring` factory, add `SpendingManager` factory |
| `ToDay/Features/Today/TodayViewModel.swift` | Add `SpendingManager` + `ScreenTimeRecordStoring`, merge into timeline, expose spending/screentime actions |
| `ToDay/Data/MockTimelineDataProvider.swift` | Add mock spending/screentime data for simulator |

All paths are relative to `ios/ToDay/`.

---

## Task 1: ScreenTimeRecord toInferredEvent + ScreenTimeRecord Persistence

**Files:**
- Modify: `ios/ToDay/ToDay/Shared/ScreenTimeRecord.swift`
- Create: `ios/ToDay/ToDay/Data/ScreenTimeRecordEntity.swift`
- Create: `ios/ToDay/ToDay/Data/ScreenTimeRecordStoring.swift`
- Create: `ios/ToDay/ToDayTests/ScreenTimeRecordStoreTests.swift`

- [ ] **Step 1: Add toInferredEvent() to ScreenTimeRecord**

In `ios/ToDay/ToDay/Shared/ScreenTimeRecord.swift`, add a `toInferredEvent()` method to `ScreenTimeRecord` at the end of the struct (after the `formattedTotalTime` computed property):

```swift
    func toInferredEvent() -> InferredEvent {
        let displayName = "屏幕时间 \(formattedTotalTime)"
        let topApps = appUsages
            .sorted { $0.duration > $1.duration }
            .prefix(3)
            .map { "\($0.appName) \($0.formattedDuration)" }
        let subtitle: String? = topApps.isEmpty ? nil : topApps.joined(separator: "、")

        // Use noon of the day as start, span the total screen time as duration
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let baseDate = dateFormatter.date(from: dateKey) ?? Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: baseDate)
        let noon = calendar.date(byAdding: .hour, value: 12, to: startOfDay) ?? startOfDay

        return InferredEvent(
            id: id,
            kind: .screenTime,
            startDate: noon,
            endDate: noon,
            confidence: .medium,
            displayName: displayName,
            subtitle: subtitle
        )
    }
```

- [ ] **Step 2: Create ScreenTimeRecordEntity.swift**

Create `ios/ToDay/ToDay/Data/ScreenTimeRecordEntity.swift`:

```swift
import Foundation
import SwiftData

@Model
final class ScreenTimeRecordEntity {
    @Attribute(.unique) var id: UUID
    var dateKey: String
    var totalScreenTime: Double
    var appUsagesData: Data
    var pickupCount: Int

    init(record: ScreenTimeRecord) {
        id = record.id
        dateKey = record.dateKey
        totalScreenTime = record.totalScreenTime
        appUsagesData = (try? JSONEncoder().encode(record.appUsages)) ?? Data()
        pickupCount = record.pickupCount
    }

    func update(from record: ScreenTimeRecord) {
        dateKey = record.dateKey
        totalScreenTime = record.totalScreenTime
        appUsagesData = (try? JSONEncoder().encode(record.appUsages)) ?? Data()
        pickupCount = record.pickupCount
    }

    func toScreenTimeRecord() -> ScreenTimeRecord {
        let appUsages = (try? JSONDecoder().decode([AppUsage].self, from: appUsagesData)) ?? []
        return ScreenTimeRecord(
            id: id,
            dateKey: dateKey,
            totalScreenTime: totalScreenTime,
            appUsages: appUsages,
            pickupCount: pickupCount
        )
    }
}
```

- [ ] **Step 3: Create ScreenTimeRecordStoring.swift**

Create `ios/ToDay/ToDay/Data/ScreenTimeRecordStoring.swift`:

```swift
import Foundation
import SwiftData

protocol ScreenTimeRecordStoring {
    func loadAll() -> [ScreenTimeRecord]
    func loadForDateKey(_ dateKey: String) -> ScreenTimeRecord?
    func save(_ record: ScreenTimeRecord) throws
    func delete(_ id: UUID) throws
}

struct SwiftDataScreenTimeRecordStore: ScreenTimeRecordStoring {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func loadAll() -> [ScreenTimeRecord] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<ScreenTimeRecordEntity>(
            sortBy: [SortDescriptor(\.dateKey, order: .reverse)]
        )
        descriptor.includePendingChanges = false

        guard let entities = try? context.fetch(descriptor) else {
            return []
        }
        return entities.map { $0.toScreenTimeRecord() }
    }

    func loadForDateKey(_ dateKey: String) -> ScreenTimeRecord? {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<ScreenTimeRecordEntity>(
            predicate: #Predicate { $0.dateKey == dateKey }
        )
        descriptor.fetchLimit = 1
        descriptor.includePendingChanges = false

        return try? context.fetch(descriptor).first?.toScreenTimeRecord()
    }

    func save(_ record: ScreenTimeRecord) throws {
        let context = ModelContext(container)
        let id = record.id
        var descriptor = FetchDescriptor<ScreenTimeRecordEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            existing.update(from: record)
        } else {
            // Also check by dateKey to avoid duplicates for the same day
            let dateKey = record.dateKey
            var dateDescriptor = FetchDescriptor<ScreenTimeRecordEntity>(
                predicate: #Predicate { $0.dateKey == dateKey }
            )
            dateDescriptor.fetchLimit = 1

            if let existingDay = try context.fetch(dateDescriptor).first {
                existingDay.update(from: record)
            } else {
                context.insert(ScreenTimeRecordEntity(record: record))
            }
        }

        if context.hasChanges {
            try context.save()
        }
    }

    func delete(_ id: UUID) throws {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<ScreenTimeRecordEntity>(
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

- [ ] **Step 4: Write ScreenTimeRecordStore tests**

Create `ios/ToDay/ToDayTests/ScreenTimeRecordStoreTests.swift`:

```swift
import SwiftData
import XCTest
@testable import ToDay

final class ScreenTimeRecordStoreTests: XCTestCase {
    func testSaveAndLoadPreservesFields() throws {
        let store = makeStore()
        let record = ScreenTimeRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000A01")!,
            dateKey: "2026-03-25",
            totalScreenTime: 5400,
            appUsages: [
                AppUsage(appName: "Xcode", category: "开发", duration: 3600),
                AppUsage(appName: "Safari", category: "浏览", duration: 1800)
            ],
            pickupCount: 42
        )

        try store.save(record)
        let loaded = store.loadAll()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, record.id)
        XCTAssertEqual(loaded[0].dateKey, "2026-03-25")
        XCTAssertEqual(loaded[0].totalScreenTime, 5400, accuracy: 0.1)
        XCTAssertEqual(loaded[0].appUsages.count, 2)
        XCTAssertEqual(loaded[0].appUsages[0].appName, "Xcode")
        XCTAssertEqual(loaded[0].pickupCount, 42)
    }

    func testLoadForDateKey() throws {
        let store = makeStore()
        let record1 = ScreenTimeRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000A02")!,
            dateKey: "2026-03-24",
            totalScreenTime: 7200
        )
        let record2 = ScreenTimeRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000A03")!,
            dateKey: "2026-03-25",
            totalScreenTime: 3600
        )

        try store.save(record1)
        try store.save(record2)

        let found = store.loadForDateKey("2026-03-25")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.totalScreenTime, 3600, accuracy: 0.1)

        let notFound = store.loadForDateKey("2026-03-26")
        XCTAssertNil(notFound)
    }

    func testDeleteRecord() throws {
        let store = makeStore()
        let record = ScreenTimeRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000A04")!,
            dateKey: "2026-03-25",
            totalScreenTime: 3600
        )

        try store.save(record)
        try store.delete(record.id)
        let loaded = store.loadAll()

        XCTAssertEqual(loaded.count, 0)
    }

    func testSaveSameDateKeyUpdatesExisting() throws {
        let store = makeStore()
        let record1 = ScreenTimeRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000A05")!,
            dateKey: "2026-03-25",
            totalScreenTime: 3600,
            pickupCount: 20
        )
        let record2 = ScreenTimeRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000A06")!,
            dateKey: "2026-03-25",
            totalScreenTime: 7200,
            pickupCount: 45
        )

        try store.save(record1)
        try store.save(record2)

        let loaded = store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].totalScreenTime, 7200, accuracy: 0.1)
        XCTAssertEqual(loaded[0].pickupCount, 45)
    }

    func testToInferredEvent() {
        let record = ScreenTimeRecord(
            dateKey: "2026-03-25",
            totalScreenTime: 9000,
            appUsages: [
                AppUsage(appName: "Safari", category: "浏览", duration: 3600),
                AppUsage(appName: "Xcode", category: "开发", duration: 5400)
            ],
            pickupCount: 30
        )

        let event = record.toInferredEvent()
        XCTAssertEqual(event.kind, .screenTime)
        XCTAssertEqual(event.displayName, "屏幕时间 2h 30m")
        XCTAssertEqual(event.confidence, .medium)
        XCTAssertNotNil(event.subtitle)
    }

    private func makeStore() -> SwiftDataScreenTimeRecordStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: ScreenTimeRecordEntity.self, configurations: config)
        return SwiftDataScreenTimeRecordStore(container: container)
    }
}
```

- [ ] **Step 5: Run tests — expect compile failure**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/ScreenTimeRecordStoreTests 2>&1 | tail -20`

Expected: Compile error — `ScreenTimeRecordEntity` not yet registered in main container, but the test creates its own in-memory container so it may pass once the files exist. Verify all 5 tests pass.

- [ ] **Step 6: Register ScreenTimeRecordEntity in AppContainer**

In `ios/ToDay/ToDay/App/AppContainer.swift`, modify `makeModelContainer()` to include `ScreenTimeRecordEntity`.

Find:
```swift
let container = try ModelContainer(
    for: MoodRecordEntity.self,
    DayTimelineEntity.self,
    ShutterRecordEntity.self,
    SpendingRecordEntity.self
)
```

Replace with:
```swift
let container = try ModelContainer(
    for: MoodRecordEntity.self,
    DayTimelineEntity.self,
    ShutterRecordEntity.self,
    SpendingRecordEntity.self,
    ScreenTimeRecordEntity.self
)
```

Also add the store property after the existing `spendingRecordStore` line:

```swift
private static let screenTimeRecordStore = SwiftDataScreenTimeRecordStore(container: modelContainer)
```

And add the factory method after `makeSpendingRecordStore()`:

```swift
static func makeScreenTimeRecordStore() -> any ScreenTimeRecordStoring {
    screenTimeRecordStore
}
```

- [ ] **Step 7: Build and run tests**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/ScreenTimeRecordStoreTests 2>&1 | tail -20`

Expected: All 5 tests PASS

- [ ] **Step 8: Run full test suite**

Run: `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All existing tests still pass

- [ ] **Step 9: Commit**

```bash
cd ios/ToDay && git add ToDay/Shared/ScreenTimeRecord.swift ToDay/Data/ScreenTimeRecordEntity.swift ToDay/Data/ScreenTimeRecordStoring.swift ToDay/App/AppContainer.swift ToDayTests/ScreenTimeRecordStoreTests.swift
git commit -m "feat: add ScreenTimeRecord persistence layer and toInferredEvent"
```

---

## Task 2: SpendingManager

**Files:**
- Create: `ios/ToDay/ToDay/Data/SpendingManager.swift`
- Create: `ios/ToDay/ToDayTests/SpendingManagerTests.swift`

- [ ] **Step 1: Write SpendingManager tests**

Create `ios/ToDay/ToDayTests/SpendingManagerTests.swift`:

```swift
import SwiftData
import XCTest
@testable import ToDay

final class SpendingManagerTests: XCTestCase {
    func testAddRecordAppearsInRecords() {
        let manager = makeManager()
        let record = SpendingRecord(amount: 35.5, category: .food, note: "午餐")

        manager.addRecord(record)

        XCTAssertEqual(manager.records.count, 1)
        XCTAssertEqual(manager.records[0].amount, 35.5, accuracy: 0.01)
        XCTAssertEqual(manager.records[0].category, .food)
    }

    func testRecordsForDate() {
        let manager = makeManager()
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let todayRecord = SpendingRecord(amount: 20, category: .food, createdAt: today)
        let yesterdayRecord = SpendingRecord(amount: 50, category: .shopping, createdAt: yesterday)

        manager.addRecord(todayRecord)
        manager.addRecord(yesterdayRecord)

        let todayRecords = manager.records(on: today)
        XCTAssertEqual(todayRecords.count, 1)
        XCTAssertEqual(todayRecords[0].category, .food)
    }

    func testRemoveRecord() {
        let manager = makeManager()
        let record = SpendingRecord(amount: 100, category: .entertainment)

        manager.addRecord(record)
        manager.removeRecord(id: record.id)

        XCTAssertEqual(manager.records.count, 0)
    }

    func testTodayTotal() {
        let manager = makeManager()
        let today = Date()

        manager.addRecord(SpendingRecord(amount: 35, category: .food, createdAt: today))
        manager.addRecord(SpendingRecord(amount: 15, category: .transport, createdAt: today))

        let total = manager.todayTotal(on: today)
        XCTAssertEqual(total, 50, accuracy: 0.01)
    }

    func testReloadFromStore() {
        let store = makeStore()
        let record = SpendingRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000B01")!,
            amount: 42,
            category: .daily
        )
        try! store.save(record)

        let manager = SpendingManager(recordStore: store)

        XCTAssertEqual(manager.records.count, 1)
        XCTAssertEqual(manager.records[0].id, record.id)
    }

    private func makeStore() -> SwiftDataSpendingRecordStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: SpendingRecordEntity.self, configurations: config)
        return SwiftDataSpendingRecordStore(container: container)
    }

    private func makeManager() -> SpendingManager {
        SpendingManager(recordStore: makeStore())
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/SpendingManagerTests 2>&1 | tail -20`

Expected: Compile error — `SpendingManager` not defined

- [ ] **Step 3: Create SpendingManager.swift**

Create `ios/ToDay/ToDay/Data/SpendingManager.swift`:

```swift
import Foundation

/// Manages CRUD for spending records. Owned by TodayViewModel.
@MainActor
final class SpendingManager {
    private(set) var records: [SpendingRecord] = []

    private let recordStore: any SpendingRecordStoring
    private let calendar: Calendar

    init(recordStore: any SpendingRecordStoring, calendar: Calendar = .current) {
        self.recordStore = recordStore
        self.calendar = calendar
        reloadFromStore()
    }

    // MARK: - Queries

    func records(on date: Date) -> [SpendingRecord] {
        records
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func todayTotal(on date: Date) -> Double {
        records(on: date).reduce(0) { $0 + $1.amount }
    }

    // MARK: - Mutations

    func addRecord(_ record: SpendingRecord) {
        records.insert(record, at: 0)
        records.sort { $0.createdAt > $1.createdAt }
        persistRecord(record)
    }

    func removeRecord(id: UUID) {
        records.removeAll { $0.id == id }
        try? recordStore.delete(id)
    }

    func reloadFromStore() {
        records = recordStore.loadAll()
    }

    // MARK: - Private

    private func persistRecord(_ record: SpendingRecord) {
        try? recordStore.save(record)
    }
}
```

- [ ] **Step 4: Run tests — expect pass**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/SpendingManagerTests 2>&1 | tail -20`

Expected: All 5 tests PASS

- [ ] **Step 5: Run full test suite**

Run: `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
cd ios/ToDay && git add ToDay/Data/SpendingManager.swift ToDayTests/SpendingManagerTests.swift
git commit -m "feat: add SpendingManager for spending record CRUD"
```

---

## Task 3: SpendingInputView

**Files:**
- Create: `ios/ToDay/ToDay/Features/Today/SpendingInputView.swift`

- [ ] **Step 1: Create SpendingInputView.swift**

Create `ios/ToDay/ToDay/Features/Today/SpendingInputView.swift`:

```swift
import SwiftUI

struct SpendingInputView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String = ""
    @State private var selectedCategory: SpendingCategory = .food
    @State private var note: String = ""
    @State private var createdAt: Date = Date()
    @State private var isSubmitting = false

    let onSave: (SpendingRecord) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    amountSection
                    categoryGrid
                    noteSection
                    timeSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 120)
            }
            .background(TodayTheme.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(TodayTheme.inkSoft)
                            .frame(width: 32, height: 32)
                            .background(TodayTheme.card)
                            .clipShape(Circle())
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                saveButton
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .background(TodayTheme.background.opacity(0.96))
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("记一笔")
                    .font(.system(size: 28, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(TodayTheme.ink)

                Text("金额 + 分类，轻松记下每一笔开销。")
                    .font(.system(size: 14))
                    .foregroundStyle(TodayTheme.inkMuted)
                    .lineSpacing(3)
            }

            Spacer()

            Text("消费")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(TodayTheme.teal)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(TodayTheme.tealSoft)
                .clipShape(Capsule())
        }
    }

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("金额")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(TodayTheme.inkMuted)

            HStack(spacing: 8) {
                Text("¥")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(TodayTheme.ink)

                TextField("0", text: $amountText)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(TodayTheme.ink)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
            }
            .padding(14)
            .background(TodayTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(TodayTheme.border, lineWidth: 1)
            )
        }
    }

    private var categoryGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("分类")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(TodayTheme.inkMuted)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(SpendingCategory.allCases, id: \.self) { category in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedCategory = category
                        }
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: category.iconName)
                                .font(.system(size: 18))
                            Text(category.displayName)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            selectedCategory == category
                                ? TodayTheme.tealSoft
                                : TodayTheme.card
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(
                                    selectedCategory == category
                                        ? TodayTheme.teal
                                        : Color.clear,
                                    lineWidth: 2
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(
                        selectedCategory == category
                            ? TodayTheme.teal
                            : TodayTheme.inkSoft
                    )
                }
            }
        }
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("备注")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(TodayTheme.inkMuted)

            TextField("写一句话备注…", text: $note)
                .textFieldStyle(.plain)
                .padding(14)
                .background(TodayTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(TodayTheme.border, lineWidth: 1)
                )
        }
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("消费时间")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(TodayTheme.inkMuted)

            DatePicker(
                "消费时间",
                selection: $createdAt,
                in: ...Date(),
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TodayTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(TodayTheme.border, lineWidth: 1)
            )
        }
    }

    private var saveButton: some View {
        Button {
            guard !isSubmitting else { return }
            guard let amount = parsedAmount, amount > 0 else { return }

            isSubmitting = true
            let record = SpendingRecord(
                amount: amount,
                category: selectedCategory,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note.trimmingCharacters(in: .whitespacesAndNewlines),
                createdAt: createdAt
            )
            onSave(record)
            dismiss()
        } label: {
            Text("保存")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(TodayTheme.teal)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(parsedAmount == nil || parsedAmount == 0 || isSubmitting)
        .opacity(parsedAmount == nil || parsedAmount == 0 || isSubmitting ? 0.45 : 1)
    }

    // MARK: - Helpers

    private var parsedAmount: Double? {
        Double(amountText.trimmingCharacters(in: .whitespaces))
    }
}
```

- [ ] **Step 2: Build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
cd ios/ToDay && git add ToDay/Features/Today/SpendingInputView.swift
git commit -m "feat: add SpendingInputView for quick spending entry"
```

---

## Task 4: ScreenTimeInputView

**Files:**
- Create: `ios/ToDay/ToDay/Features/Today/ScreenTimeInputView.swift`

- [ ] **Step 1: Create ScreenTimeInputView.swift**

Create `ios/ToDay/ToDay/Features/Today/ScreenTimeInputView.swift`:

```swift
import SwiftUI

struct ScreenTimeInputView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var hours: Int = 0
    @State private var minutes: Int = 0
    @State private var pickupCount: Int = 0
    @State private var appEntries: [AppEntryDraft] = [AppEntryDraft()]
    @State private var isSubmitting = false

    let dateKey: String
    let existingRecord: ScreenTimeRecord?
    let onSave: (ScreenTimeRecord) -> Void

    init(dateKey: String, existingRecord: ScreenTimeRecord? = nil, onSave: @escaping (ScreenTimeRecord) -> Void) {
        self.dateKey = dateKey
        self.existingRecord = existingRecord
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    totalTimeSection
                    pickupSection
                    appUsageSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 120)
            }
            .background(TodayTheme.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(TodayTheme.inkSoft)
                            .frame(width: 32, height: 32)
                            .background(TodayTheme.card)
                            .clipShape(Circle())
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                saveButton
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .background(TodayTheme.background.opacity(0.96))
            }
            .onAppear {
                if let existing = existingRecord {
                    let totalSeconds = Int(existing.totalScreenTime)
                    hours = totalSeconds / 3600
                    minutes = (totalSeconds % 3600) / 60
                    pickupCount = existing.pickupCount
                    appEntries = existing.appUsages.map { usage in
                        AppEntryDraft(
                            appName: usage.appName,
                            category: usage.category,
                            durationMinutes: String(Int(usage.duration / 60))
                        )
                    }
                    if appEntries.isEmpty {
                        appEntries = [AppEntryDraft()]
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("屏幕时间")
                    .font(.system(size: 28, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(TodayTheme.ink)

                Text("记录今天的屏幕使用情况。\n可以在 设置 > 屏幕使用时间 中查看系统数据。")
                    .font(.system(size: 14))
                    .foregroundStyle(TodayTheme.inkMuted)
                    .lineSpacing(3)
            }

            Spacer()

            Text("屏幕")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(TodayTheme.blue)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(TodayTheme.blueSoft)
                .clipShape(Capsule())
        }
    }

    private var totalTimeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("总时长")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(TodayTheme.inkMuted)

            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Picker("小时", selection: $hours) {
                        ForEach(0..<24) { h in
                            Text("\(h)").tag(h)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 60, height: 100)
                    .clipped()

                    Text("小时")
                        .font(.system(size: 14))
                        .foregroundStyle(TodayTheme.inkSoft)
                }

                HStack(spacing: 6) {
                    Picker("分钟", selection: $minutes) {
                        ForEach(0..<60) { m in
                            Text("\(m)").tag(m)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 60, height: 100)
                    .clipped()

                    Text("分钟")
                        .font(.system(size: 14))
                        .foregroundStyle(TodayTheme.inkSoft)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(TodayTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(TodayTheme.border, lineWidth: 1)
            )
        }
    }

    private var pickupSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("拿起次数")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(TodayTheme.inkMuted)

            HStack(spacing: 12) {
                Button {
                    if pickupCount > 0 { pickupCount -= 1 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(TodayTheme.inkMuted)
                }
                .buttonStyle(.plain)

                Text("\(pickupCount)")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundStyle(TodayTheme.ink)
                    .frame(minWidth: 50)

                Button {
                    pickupCount += 1
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(TodayTheme.blue)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("次")
                    .font(.system(size: 14))
                    .foregroundStyle(TodayTheme.inkSoft)
            }
            .padding(14)
            .background(TodayTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(TodayTheme.border, lineWidth: 1)
            )
        }
    }

    private var appUsageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("常用 App（可选）")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(TodayTheme.inkMuted)

                Spacer()

                if appEntries.count < 5 {
                    Button {
                        appEntries.append(AppEntryDraft())
                    } label: {
                        Label("添加", systemImage: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(TodayTheme.blue)
                    }
                }
            }

            ForEach(appEntries.indices, id: \.self) { index in
                HStack(spacing: 8) {
                    TextField("App 名称", text: $appEntries[index].appName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))

                    TextField("分类", text: $appEntries[index].category)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .frame(width: 60)

                    TextField("分钟", text: $appEntries[index].durationMinutes)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, design: .monospaced))
                        .keyboardType(.numberPad)
                        .frame(width: 50)

                    if appEntries.count > 1 {
                        Button {
                            appEntries.remove(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(TodayTheme.inkFaint)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(TodayTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(TodayTheme.border, lineWidth: 1)
                )
            }
        }
    }

    private var saveButton: some View {
        Button {
            guard !isSubmitting else { return }
            let totalSeconds = TimeInterval(hours * 3600 + minutes * 60)
            guard totalSeconds > 0 else { return }

            isSubmitting = true

            let appUsages: [AppUsage] = appEntries.compactMap { entry in
                let name = entry.appName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty,
                      let mins = Int(entry.durationMinutes.trimmingCharacters(in: .whitespaces)),
                      mins > 0 else { return nil }
                return AppUsage(
                    appName: name,
                    category: entry.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "其他" : entry.category.trimmingCharacters(in: .whitespacesAndNewlines),
                    duration: TimeInterval(mins * 60)
                )
            }

            let record = ScreenTimeRecord(
                id: existingRecord?.id ?? UUID(),
                dateKey: dateKey,
                totalScreenTime: totalSeconds,
                appUsages: appUsages,
                pickupCount: pickupCount
            )
            onSave(record)
            dismiss()
        } label: {
            Text(existingRecord == nil ? "保存" : "更新")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(TodayTheme.blue)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(totalTimeInvalid || isSubmitting)
        .opacity(totalTimeInvalid || isSubmitting ? 0.45 : 1)
    }

    private var totalTimeInvalid: Bool {
        hours == 0 && minutes == 0
    }
}

private struct AppEntryDraft: Identifiable {
    let id = UUID()
    var appName: String = ""
    var category: String = ""
    var durationMinutes: String = ""
}
```

- [ ] **Step 2: Build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
cd ios/ToDay && git add ToDay/Features/Today/ScreenTimeInputView.swift
git commit -m "feat: add ScreenTimeInputView for manual screen time entry"
```

---

## Task 5: Integrate Spending + Screen Time into TodayViewModel

**Files:**
- Modify: `ios/ToDay/ToDay/Features/Today/TodayViewModel.swift`
- Modify: `ios/ToDay/ToDay/App/AppContainer.swift`
- Create: `ios/ToDay/ToDayTests/TimelineMergeTests.swift`

- [ ] **Step 1: Write timeline merge tests**

Create `ios/ToDay/ToDayTests/TimelineMergeTests.swift`:

```swift
import SwiftData
import XCTest
@testable import ToDay

@MainActor
final class TimelineMergeTests: XCTestCase {
    func testSpendingRecordsMergedIntoTimeline() async throws {
        let vm = makeViewModel()
        await vm.load(forceReload: true)

        // Add a spending record
        let record = SpendingRecord(amount: 35, category: .food, note: "午餐")
        vm.addSpendingRecord(record)

        // Timeline should contain the spending event
        let spendingEvents = vm.timeline?.entries.filter { $0.kind == .spending } ?? []
        XCTAssertEqual(spendingEvents.count, 1)
        XCTAssertTrue(spendingEvents[0].displayName.contains("¥35"))
    }

    func testScreenTimeRecordMergedIntoTimeline() async throws {
        let vm = makeViewModel()
        await vm.load(forceReload: true)

        // Add a screen time record
        let dateKey = Self.dateKeyFormatter.string(from: Date())
        let record = ScreenTimeRecord(
            dateKey: dateKey,
            totalScreenTime: 5400,
            appUsages: [
                AppUsage(appName: "Safari", category: "浏览", duration: 3600)
            ],
            pickupCount: 20
        )
        vm.saveScreenTimeRecord(record)

        // Timeline should contain the screen time event
        let screenTimeEvents = vm.timeline?.entries.filter { $0.kind == .screenTime } ?? []
        XCTAssertEqual(screenTimeEvents.count, 1)
        XCTAssertTrue(screenTimeEvents[0].displayName.contains("1h 30m"))
    }

    func testSpendingRecordRemoval() async throws {
        let vm = makeViewModel()
        await vm.load(forceReload: true)

        let record = SpendingRecord(amount: 50, category: .shopping)
        vm.addSpendingRecord(record)

        XCTAssertFalse(vm.spendingRecords(forCurrentDay: true).isEmpty)

        vm.removeSpendingRecord(id: record.id)

        XCTAssertTrue(vm.spendingRecords(forCurrentDay: true).isEmpty)
    }

    // MARK: - Helpers

    private static let dateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private func makeViewModel() -> TodayViewModel {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: MoodRecordEntity.self,
            DayTimelineEntity.self,
            ShutterRecordEntity.self,
            SpendingRecordEntity.self,
            ScreenTimeRecordEntity.self,
            configurations: config
        )
        let moodStore = SwiftDataMoodRecordStore(container: container)
        let spendingStore = SwiftDataSpendingRecordStore(container: container)
        let screenTimeStore = SwiftDataScreenTimeRecordStore(container: container)

        return TodayViewModel(
            provider: MockTimelineDataProvider(),
            recordStore: moodStore,
            spendingRecordStore: spendingStore,
            screenTimeRecordStore: screenTimeStore,
            modelContainer: container
        )
    }
}
```

- [ ] **Step 2: Update AppContainer to pass spending and screen time stores to TodayViewModel**

In `ios/ToDay/ToDay/App/AppContainer.swift`, modify `makeTodayViewModel()` to pass the new stores:

Find:
```swift
    @MainActor
    static func makeTodayViewModel() -> TodayViewModel {
        let viewModel = TodayViewModel(
            provider: makeTimelineProvider(),
            recordStore: makeMoodRecordStore(),
            phoneConnectivityManager: phoneConnectivityManager,
            modelContainer: modelContainer
        )
        phoneConnectivityManager.bind(todayViewModel: viewModel)
        return viewModel
    }
```

Replace with:
```swift
    @MainActor
    static func makeTodayViewModel() -> TodayViewModel {
        let viewModel = TodayViewModel(
            provider: makeTimelineProvider(),
            recordStore: makeMoodRecordStore(),
            spendingRecordStore: makeSpendingRecordStore(),
            screenTimeRecordStore: makeScreenTimeRecordStore(),
            phoneConnectivityManager: phoneConnectivityManager,
            modelContainer: modelContainer
        )
        phoneConnectivityManager.bind(todayViewModel: viewModel)
        return viewModel
    }
```

- [ ] **Step 3: Update TodayViewModel to integrate spending and screen time**

In `ios/ToDay/ToDay/Features/Today/TodayViewModel.swift`, apply the following changes:

**3a. Add new published state and managers after the existing managers section (line 22):**

Find:
```swift
    // MARK: - Managers

    private let recordManager: MoodRecordManager
    private let annotationStore: AnnotationStore
    private let insightComposer: TodayInsightComposer
    #if os(iOS)
    private let watchSync: WatchSyncHelper
    #endif
```

Replace with:
```swift
    // MARK: - Managers

    private let recordManager: MoodRecordManager
    private let spendingManager: SpendingManager
    private let screenTimeStore: any ScreenTimeRecordStoring
    private let annotationStore: AnnotationStore
    private let insightComposer: TodayInsightComposer
    #if os(iOS)
    private let watchSync: WatchSyncHelper
    #endif
```

**3b. Add new published state for showing input sheets. After the `quickRecordMode` published property:**

Find:
```swift
    @Published var showQuickRecord = false
    @Published private(set) var quickRecordMode: QuickRecordSheetMode = .flexible
```

Replace with:
```swift
    @Published var showQuickRecord = false
    @Published private(set) var quickRecordMode: QuickRecordSheetMode = .flexible
    @Published var showSpendingInput = false
    @Published var showScreenTimeInput = false
```

**3c. Update the init method to accept new stores:**

Find:
```swift
    init(
        provider: any TimelineDataProviding,
        recordStore: any MoodRecordStoring,
        insightComposer: TodayInsightComposer = TodayInsightComposer(),
        phoneConnectivityManager: PhoneConnectivityManager? = nil,
        modelContainer: ModelContainer,
        calendar: Calendar = .current
    ) {
        self.provider = provider
        self.modelContainer = modelContainer
        self.calendar = calendar
        self.insightComposer = insightComposer
        self.recordManager = MoodRecordManager(recordStore: recordStore, calendar: calendar)
        self.annotationStore = AnnotationStore(calendar: calendar)
        #if os(iOS)
        self.watchSync = WatchSyncHelper(connectivityManager: phoneConnectivityManager, calendar: calendar)
        #endif
```

Replace with:
```swift
    init(
        provider: any TimelineDataProviding,
        recordStore: any MoodRecordStoring,
        spendingRecordStore: (any SpendingRecordStoring)? = nil,
        screenTimeRecordStore: (any ScreenTimeRecordStoring)? = nil,
        insightComposer: TodayInsightComposer = TodayInsightComposer(),
        phoneConnectivityManager: PhoneConnectivityManager? = nil,
        modelContainer: ModelContainer,
        calendar: Calendar = .current
    ) {
        self.provider = provider
        self.modelContainer = modelContainer
        self.calendar = calendar
        self.insightComposer = insightComposer
        self.recordManager = MoodRecordManager(recordStore: recordStore, calendar: calendar)
        self.spendingManager = SpendingManager(
            recordStore: spendingRecordStore ?? InMemorySpendingRecordStore(),
            calendar: calendar
        )
        self.screenTimeStore = screenTimeRecordStore ?? InMemoryScreenTimeRecordStore()
        self.annotationStore = AnnotationStore(calendar: calendar)
        #if os(iOS)
        self.watchSync = WatchSyncHelper(connectivityManager: phoneConnectivityManager, calendar: calendar)
        #endif
```

**3d. Add spending and screen time public methods after the Quick Record Sheet section (after `openPointComposer()`):**

Find:
```swift
    func openPointComposer() {
        quickRecordMode = .pointOnly
        showQuickRecord = true
    }
```

Replace with:
```swift
    func openPointComposer() {
        quickRecordMode = .pointOnly
        showQuickRecord = true
    }

    // MARK: - Spending Records

    func addSpendingRecord(_ record: SpendingRecord) {
        spendingManager.addRecord(record)
        rebuildTimeline(referenceDate: currentBaseTimeline?.date ?? Date())
    }

    func removeSpendingRecord(id: UUID) {
        spendingManager.removeRecord(id: id)
        rebuildTimeline(referenceDate: currentBaseTimeline?.date ?? Date())
    }

    func spendingRecords(forCurrentDay: Bool) -> [SpendingRecord] {
        let date = currentBaseTimeline?.date ?? Date()
        return forCurrentDay ? spendingManager.records(on: date) : spendingManager.records
    }

    var todaySpendingTotal: Double {
        spendingManager.todayTotal(on: currentBaseTimeline?.date ?? Date())
    }

    // MARK: - Screen Time Records

    func saveScreenTimeRecord(_ record: ScreenTimeRecord) {
        try? screenTimeStore.save(record)
        rebuildTimeline(referenceDate: currentBaseTimeline?.date ?? Date())
    }

    func currentDateKey() -> String {
        let date = currentBaseTimeline?.date ?? Date()
        return Self.dateKeyFormatter.string(from: date)
    }

    func existingScreenTimeRecord() -> ScreenTimeRecord? {
        screenTimeStore.loadForDateKey(currentDateKey())
    }

    private static let dateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
```

**3e. Update `mergedTimeline(base:)` to include spending and screen time events:**

Find:
```swift
    private func mergedTimeline(base: DayTimeline) -> DayTimeline {
        let recordsForDay = recordManager.records(on: base.date)
        let manualEntries = recordsForDay.map { $0.toInferredEvent(referenceDate: Date(), calendar: calendar) }
        let annotationsForDay = annotationStore.annotations(on: base.date)
        let notesCount = recordsForDay.filter(MoodRecordManager.hasNote).count

        var stats = base.stats
        stats.append(TimelineStat(title: "记录", value: "\(recordsForDay.count)"))
        if !annotationsForDay.isEmpty {
            stats.append(TimelineStat(title: "标注", value: "\(annotationsForDay.count)"))
        }
        if notesCount > 0 {
            stats.append(TimelineStat(title: "备注", value: "\(notesCount)"))
        }
        if let active = recordManager.activeRecord {
            stats.append(TimelineStat(title: "当前", value: active.mood.rawValue))
        }

        var matchedIDs = Set<UUID>()
        let annotatedBase = base.entries.map { event -> InferredEvent in
            guard let annotation = annotationStore.annotation(for: event.id) else { return event }
            matchedIDs.insert(annotation.id)
            return event.applyingAnnotation(annotation.title)
        }
        let syntheticEntries = annotationsForDay
            .filter { !matchedIDs.contains($0.id) }
            .map(\.asEvent)

        let entries = (manualEntries + syntheticEntries + annotatedBase).sorted { lhs, rhs in
            lhs.startDate == rhs.startDate
                ? lhs.id.uuidString < rhs.id.uuidString
                : lhs.startDate < rhs.startDate
        }

        return DayTimeline(date: base.date, summary: base.summary, source: base.source, stats: stats, entries: entries)
    }
```

Replace with:
```swift
    private func mergedTimeline(base: DayTimeline) -> DayTimeline {
        let recordsForDay = recordManager.records(on: base.date)
        let manualEntries = recordsForDay.map { $0.toInferredEvent(referenceDate: Date(), calendar: calendar) }
        let annotationsForDay = annotationStore.annotations(on: base.date)
        let notesCount = recordsForDay.filter(MoodRecordManager.hasNote).count

        // Spending events
        let spendingForDay = spendingManager.records(on: base.date)
        let spendingEntries = spendingForDay.map { $0.toInferredEvent() }

        // Screen time event
        let dateKey = Self.dateKeyFormatter.string(from: base.date)
        let screenTimeRecord = screenTimeStore.loadForDateKey(dateKey)
        let screenTimeEntries: [InferredEvent] = screenTimeRecord.map { [$0.toInferredEvent()] } ?? []

        var stats = base.stats
        stats.append(TimelineStat(title: "记录", value: "\(recordsForDay.count)"))
        if !annotationsForDay.isEmpty {
            stats.append(TimelineStat(title: "标注", value: "\(annotationsForDay.count)"))
        }
        if notesCount > 0 {
            stats.append(TimelineStat(title: "备注", value: "\(notesCount)"))
        }
        if let active = recordManager.activeRecord {
            stats.append(TimelineStat(title: "当前", value: active.mood.rawValue))
        }
        if !spendingForDay.isEmpty {
            let total = spendingForDay.reduce(0) { $0 + $1.amount }
            stats.append(TimelineStat(title: "消费", value: "¥\(String(format: "%.0f", total))"))
        }
        if let st = screenTimeRecord {
            stats.append(TimelineStat(title: "屏幕时间", value: st.formattedTotalTime))
        }

        var matchedIDs = Set<UUID>()
        let annotatedBase = base.entries.map { event -> InferredEvent in
            guard let annotation = annotationStore.annotation(for: event.id) else { return event }
            matchedIDs.insert(annotation.id)
            return event.applyingAnnotation(annotation.title)
        }
        let syntheticEntries = annotationsForDay
            .filter { !matchedIDs.contains($0.id) }
            .map(\.asEvent)

        let entries = (manualEntries + syntheticEntries + annotatedBase + spendingEntries + screenTimeEntries).sorted { lhs, rhs in
            lhs.startDate == rhs.startDate
                ? lhs.id.uuidString < rhs.id.uuidString
                : lhs.startDate < rhs.startDate
        }

        return DayTimeline(date: base.date, summary: base.summary, source: base.source, stats: stats, entries: entries)
    }
```

**3f. Add in-memory fallback stores at the bottom of TodayViewModel.swift, after the closing brace of `TodayViewModel`:**

```swift
// MARK: - In-Memory Fallback Stores

/// Fallback spending store when no SwiftData store is provided (e.g. tests).
private final class InMemorySpendingRecordStore: SpendingRecordStoring {
    private var records: [SpendingRecord] = []

    func loadAll() -> [SpendingRecord] { records }

    func loadForDate(_ date: Date) -> [SpendingRecord] {
        let calendar = Calendar.current
        return records.filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
    }

    func save(_ record: SpendingRecord) throws {
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            records[index] = record
        } else {
            records.append(record)
        }
    }

    func delete(_ id: UUID) throws {
        records.removeAll { $0.id == id }
    }
}

/// Fallback screen time store when no SwiftData store is provided (e.g. tests).
private final class InMemoryScreenTimeRecordStore: ScreenTimeRecordStoring {
    private var records: [ScreenTimeRecord] = []

    func loadAll() -> [ScreenTimeRecord] { records }

    func loadForDateKey(_ dateKey: String) -> ScreenTimeRecord? {
        records.first { $0.dateKey == dateKey }
    }

    func save(_ record: ScreenTimeRecord) throws {
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            records[index] = record
        } else if let index = records.firstIndex(where: { $0.dateKey == record.dateKey }) {
            records[index] = record
        } else {
            records.append(record)
        }
    }

    func delete(_ id: UUID) throws {
        records.removeAll { $0.id == id }
    }
}
```

- [ ] **Step 4: Build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Run new tests**

Run: `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/TimelineMergeTests 2>&1 | tail -20`

Expected: All 3 tests PASS

- [ ] **Step 6: Run full test suite**

Run: `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All tests pass. If existing tests fail due to new `init` parameters, the optional defaults (`nil`) should handle backward compatibility. If any test creates `TodayViewModel` directly without the new parameters, the default `nil` values will use in-memory stores — no changes needed.

- [ ] **Step 7: Commit**

```bash
cd ios/ToDay && git add ToDay/Features/Today/TodayViewModel.swift ToDay/App/AppContainer.swift ToDayTests/TimelineMergeTests.swift
git commit -m "feat: integrate spending and screen time records into timeline merge"
```

---

## Task 6: Wire Input Views to TodayScreen

**Files:**
- Modify: `ios/ToDay/ToDay/Features/Today/TodayScreen.swift`

- [ ] **Step 1: Add spending and screen time buttons + sheet bindings to TodayScreen**

In `ios/ToDay/ToDay/Features/Today/TodayScreen.swift`, add sheet modifiers for the new input views. The exact insertion point depends on the current TodayScreen structure. Add the following modifiers alongside the existing `.sheet(isPresented: $viewModel.showQuickRecord)`:

After the existing `showQuickRecord` sheet modifier, add:

```swift
.sheet(isPresented: $viewModel.showSpendingInput) {
    SpendingInputView { record in
        viewModel.addSpendingRecord(record)
    }
}
.sheet(isPresented: $viewModel.showScreenTimeInput) {
    ScreenTimeInputView(
        dateKey: viewModel.currentDateKey(),
        existingRecord: viewModel.existingScreenTimeRecord()
    ) { record in
        viewModel.saveScreenTimeRecord(record)
    }
}
```

Also add entry point buttons. Find a suitable location in TodayScreen's UI (near the existing quick record button area or as additional action buttons). Add spending and screen time action buttons:

```swift
// Spending quick entry button
Button {
    viewModel.showSpendingInput = true
} label: {
    Label("记一笔", systemImage: "yensign.circle.fill")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(TodayTheme.teal)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(TodayTheme.tealSoft)
        .clipShape(Capsule())
}

// Screen time entry button
Button {
    viewModel.showScreenTimeInput = true
} label: {
    Label("屏幕时间", systemImage: "iphone.gen3")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(TodayTheme.blue)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(TodayTheme.blueSoft)
        .clipShape(Capsule())
}
```

**Note:** The exact placement of these buttons depends on the existing TodayScreen layout. Place them in an `HStack` near the existing "记录此刻" button or in the stat card area. Inspect the current `TodayScreen.swift` layout and place the buttons where they fit naturally with the existing UI flow.

- [ ] **Step 2: Build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Run full test suite**

Run: `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
cd ios/ToDay && git add ToDay/Features/Today/TodayScreen.swift
git commit -m "feat: wire spending and screen time input views to TodayScreen"
```

---

## Task 7: Update Mock Data

**Files:**
- Modify: `ios/ToDay/ToDay/Data/MockTimelineDataProvider.swift`

- [ ] **Step 1: Verify mock data already includes new event types**

Check if `MockTimelineDataProvider` already includes `.spending` and `.screenTime` events from Plan 1 Task 8. If yes, skip this task. If not, add mock events.

In `ios/ToDay/ToDay/Data/MockTimelineDataProvider.swift`, verify or add mock events to the entries array (ordered chronologically among existing events):

```swift
// Add around lunch time
InferredEvent(
    kind: .spending,
    startDate: time(12, 20),
    endDate: time(12, 20),
    confidence: .high,
    displayName: "餐饮 ¥35",
    subtitle: "午餐便当"
),

// Add in the afternoon
InferredEvent(
    kind: .screenTime,
    startDate: time(12, 0),
    endDate: time(12, 0),
    confidence: .medium,
    displayName: "屏幕时间 3h 15m",
    subtitle: "Xcode 1h 30m、Safari 45m、微信 30m"
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

Also add to mock stats array:
```swift
TimelineStat(title: "消费", value: "¥103"),
TimelineStat(title: "屏幕时间", value: "3h 15m"),
```

**Note:** Adapt the `time()` helper calls to match the existing pattern in the file.

- [ ] **Step 2: Build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Run full test suite**

Run: `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
cd ios/ToDay && git add ToDay/Data/MockTimelineDataProvider.swift
git commit -m "feat: ensure mock data includes spending and screenTime events"
```

---

## Summary

After completing all 7 tasks, the codebase will have:

- **SpendingManager**: Full CRUD for spending records, mirrors MoodRecordManager pattern
- **ScreenTimeRecord persistence**: `ScreenTimeRecordEntity` + `ScreenTimeRecordStoring` protocol + SwiftData implementation
- **ScreenTimeRecord.toInferredEvent()**: Converts screen time records to timeline events
- **SpendingInputView**: Quick spending entry sheet (amount + category grid + optional note + time picker)
- **ScreenTimeInputView**: Manual screen time input sheet (total time picker + pickup count + optional app usage list)
- **Timeline integration**: Both data sources merged into `TodayViewModel.mergedTimeline()` with stats
- **TodayScreen wiring**: Sheet bindings + entry point buttons for both input views
- **4 new test files**: ~18 new tests covering persistence, manager logic, and timeline merge

### Not in scope (future work)

- **DeviceActivityReport integration**: Requires Family Controls entitlement + App Extension target. Deferred per spec: "如工程量过大可推迟到 MVP 之后"
- **Automated bank/payment integration**: No system API available
- **CSV import**: Post-MVP feature
- **AI categorization**: Post-MVP feature
