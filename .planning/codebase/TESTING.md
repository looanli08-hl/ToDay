# Testing Patterns

**Analysis Date:** 2026-04-04

## Test Framework

**Runner:**
- XCTest (Apple's built-in framework)
- No separate config file; target defined in `ios/ToDay/ToDay.xcodeproj` / `project.yml`

**Assertion Library:**
- XCTest assertions (`XCTAssertEqual`, `XCTAssertTrue`, `XCTAssertNil`, `XCTAssertFalse`, `XCTAssertGreaterThan`, `XCTAssertGreaterThanOrEqual`, `XCTUnwrap`, `XCTFail`)

**Run Commands:**
```bash
# Run all tests (from repo root)
cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Regenerate project before testing (required after file changes)
cd ios/ToDay && xcodegen generate
```

**Required test count:** 180+ tests must pass after every change (per `ios/ToDay/CLAUDE.md`).

## Test File Organization

**Location:** `ios/ToDay/ToDayTests/` — separate target, not co-located with source files.

**Naming:**
- Pattern: `{TypeUnderTest}Tests.swift`
- Examples: `TodayViewModelSessionTests.swift`, `PhoneInferenceEngineTests.swift`, `EchoAIServiceTests.swift`

**Directory structure:**
```
ios/ToDay/
├── ToDay/             — production code
│   ├── App/
│   ├── Data/
│   ├── Features/
│   ├── Models/
│   └── Shared/
└── ToDayTests/        — all test files (flat, no subdirectories)
    ├── CareNudgeEngineTests.swift
    ├── DashboardViewModelTests.swift
    ├── EchoAIServiceTests.swift
    ├── EchoEngineTests.swift
    ├── EchoMemoryManagerTests.swift
    ├── EchoPromptBuilderTests.swift
    ├── EchoSchedulerTests.swift
    ├── LocationCollectorTests.swift
    ├── PhoneInferenceEngineTests.swift
    ├── PlaceManagerTests.swift
    ├── SensorDataStoreTests.swift
    ├── TimelineMergeTests.swift
    ├── TodayViewModelSessionTests.swift
    └── ... (33 test files total)
```

## Test Structure

**Suite organization:**
```swift
import XCTest
@testable import ToDay  // always present

@MainActor              // when testing @MainActor types
final class ExampleTests: XCTestCase {
    // MARK: - Helpers (private factory methods at the bottom)
    private func makeEngine() -> (EchoEngine, SwiftDataEchoItemStore, MockNotificationCenter) { ... }
    private func makeViewModel() -> TodayViewModel { ... }
}
```

**Setup/teardown pattern** (used when fixtures require cleanup):
```swift
final class EchoMemoryManagerTests: XCTestCase {
    private var container: ModelContainer!
    private var manager: EchoMemoryManager!

    @MainActor
    override func setUp() {
        super.setUp()
        // Always: in-memory SwiftData container
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: UserProfileEntity.self, ..., configurations: [config])
        manager = EchoMemoryManager(container: container)
    }

    override func tearDown() {
        container = nil
        manager = nil
        super.tearDown()
    }
}
```

**Teardown with UserDefaults cleanup:**
```swift
override func tearDown() {
    // Clean up UserDefaults keys used by scheduler
    UserDefaults.standard.removeObject(forKey: "today.echo.lastDailySummaryDate")
    super.tearDown()
}
```

**Simple tests (no persistent fixtures)** use private factory helpers at bottom of file rather than `setUp`:
```swift
// EchoEngineTests.swift
private func makeEngine() -> (EchoEngine, SwiftDataEchoItemStore, MockNotificationCenter) {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: EchoItemEntity.self, configurations: config)
    let echoStore = SwiftDataEchoItemStore(container: container)
    let mockNotifications = MockNotificationCenter()
    let engine = EchoEngine(echoStore: echoStore, notificationScheduler: mockNotifications)
    return (engine, echoStore, mockNotifications)
}
```

## SwiftData in Tests

**Universal pattern:** Use `ModelConfiguration(isStoredInMemoryOnly: true)` for all SwiftData tests. Never use the on-disk container.

```swift
let config = ModelConfiguration(isStoredInMemoryOnly: true)
let container = try! ModelContainer(for: MoodRecordEntity.self, DayTimelineEntity.self, configurations: config)
```

- Declare only the entities needed for the test, not the full schema
- Wrap SwiftData access in `@MainActor` when required by the store type
- `try!` is acceptable for in-memory container construction (unrecoverable if it fails anyway)

## Mocking

**Pattern:** Protocol-backed fakes defined directly in test files or at the bottom of the test file.

**Two types of fakes used:**

**1. In-memory store fakes** (implement the `Storing` protocol with a simple array):
```swift
// TodayViewModelSessionTests.swift
private final class InMemoryMoodRecordStore: MoodRecordStoring {
    var records: [MoodRecord]
    init(records: [MoodRecord] = []) { self.records = records }
    func loadRecords() -> [MoodRecord] { records }
    func saveRecords(_ records: [MoodRecord]) throws { self.records = records }
}
```

**2. Stub providers** (implement `TimelineDataProviding` to return deterministic data):
```swift
private struct StubTimelineProvider: TimelineDataProviding {
    let source: TimelineSource = .mock
    func loadTimeline(for date: Date) async throws -> DayTimeline {
        DayTimeline(date: date, summary: "测试时间线", source: source, stats: [...], entries: [])
    }
}
```

**3. Mock service implementations** with call tracking (for verifying interactions):
```swift
// EchoAIServiceTests.swift
final class MockAIProvider: EchoAIProviding, @unchecked Sendable {
    var respondResult: String = "mock response"
    var shouldFail = false
    var isAvailable: Bool = true
    private(set) var respondCallCount = 0

    func respond(messages: [EchoChatMessage]) async throws -> String {
        respondCallCount += 1
        if shouldFail { throw EchoAIError.invalidResponse }
        return respondResult
    }
}
```

`MockAIProvider` is defined in `EchoAIServiceTests.swift` and reused across `EchoSchedulerTests.swift`, `EchoPromptBuilderTests.swift`, and `EchoDailySummaryGeneratorTests.swift`.

**`MockNotificationCenter`** in `EchoEngineTests.swift` implements `EchoNotificationScheduling` and records scheduled/removed identifiers.

**What to mock:**
- External services (AI providers, notification centers)
- Data stores (replace with in-memory fakes via protocol)
- Timeline providers (replace with `StubTimelineProvider` / `MockTimelineDataProvider`)

**What NOT to mock:**
- SwiftData containers — use real `ModelContainer` with `isStoredInMemoryOnly: true`
- Value type business logic (inference engine, managers) — instantiate directly

## Test Data

**UUIDs:** Fixed, deterministic UUIDs used throughout to make tests reproducible:
```swift
MoodRecord(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000211")!,
    ...
)
```

**Dates:** Helper closures at file scope or per-test:
```swift
// TodayViewModelSessionTests.swift
private func sameDay(hour: Int, minute: Int) -> Date {
    let calendar = Calendar.current
    return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
}

// DashboardViewModelTests.swift (inner helper)
func time(_ hour: Int, _ minute: Int = 0) -> Date {
    calendar.date(byAdding: .minute, value: (hour * 60) + minute, to: startOfDay) ?? startOfDay
}
```

**Mock timelines:** Fully composed `DayTimeline` with realistic `InferredEvent` arrays, defined in `private func mockTimeline()` helpers within each test class.

**Image data for photo tests:**
```swift
private func sampleJPEGData() -> Data {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16))
    return renderer.image { ctx in UIColor.systemTeal.setFill(); ... }.jpegData(compressionQuality: 0.9) ?? Data()
}
```

## Coverage

**Requirements:** No enforced minimum. 180+ tests must pass (count enforced by build protocol, not coverage tool).

**View coverage:**
```bash
# Add -enableCodeCoverage YES for coverage report
xcodebuild test -scheme ToDay -destination '...' -enableCodeCoverage YES ...
```

## Test Types

**Unit Tests (majority of suite):**
- Business logic: `PhoneInferenceEngineTests`, `CareNudgeEngineTests`, `EchoEngineTests`, `EchoPromptBuilderTests`
- Data stores: `SensorDataStoreTests`, `SpendingRecordStoreTests`, `SwiftDataMoodRecordStoreTests`
- Managers: `SpendingManagerTests`, `ShutterManagerTests`, `EchoMemoryManagerTests`, `PlaceManagerTests`
- ViewModels: `TodayViewModelSessionTests`, `DashboardViewModelTests`, `EchoChatViewModelTests`
- Model encoding: `NewEventKindTests`, `SensorTypesTests`

**Integration Tests:**
- `TimelineMergeTests` — exercises full `TodayViewModel` with real SwiftData stores and mock provider
- `EchoSchedulerTests` — exercises scheduler with real memory manager and mock AI

**E2E Tests:** Not present.

**UI Tests:** Not present (no `XCUITest` target).

## Common Patterns

**Async testing:**
```swift
// ViewModels must be @MainActor for async test methods
@MainActor
final class TodayViewModelSessionTests: XCTestCase {
    func testStartAndFinishMoodSessionUpdatesTimelineEvent() async {
        let viewModel = TodayViewModel(...)
        await viewModel.load(forceReload: true)
        // assertions...
    }
}
```

**Error path testing:**
```swift
func testThrowsWhenNoProviderAvailable() async {
    service.currentTier = .pro
    proProvider.isAvailable = false
    freeProvider.isAvailable = false

    do {
        _ = try await service.respond(messages: messages)
        XCTFail("Expected error")
    } catch {
        XCTAssertTrue(error is EchoAIError)
    }
}
```

**Payload pattern matching in assertions:**
```swift
if case .visit(let lat, let lon, _, let dep) = readings.first?.payload {
    XCTAssertEqual(lat, 31.23, accuracy: 0.01)
} else {
    XCTFail("Expected visit payload")
}
```

**Count-then-verify pattern:**
```swift
// Capture baseline count before action
let baseSpendingCount = vm.timeline?.entries.filter { $0.kind == .spending }.count ?? 0
vm.addSpendingRecord(record)
XCTAssertEqual(spendingEvents.count, baseSpendingCount + 1)
```

**UserDefaults isolation:** Tests that touch `UserDefaults.standard` write to a `suiteName`-namespaced defaults (`UserDefaults(suiteName: "test.\(UUID().uuidString)")!`) or clean up in `tearDown`.

---

*Testing analysis: 2026-04-04*
