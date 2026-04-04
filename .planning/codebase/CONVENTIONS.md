# Coding Conventions

**Analysis Date:** 2026-04-04

## Naming Patterns

**Files:**
- Views: `PascalCase` with role suffix — `TodayScreen.swift`, `EventCardView.swift`, `QuickRecordSheet.swift`
- ViewModels: `PascalCase` with `ViewModel` suffix — `TodayViewModel.swift`, `DashboardViewModel.swift`
- Protocols: `PascalCase` with gerund suffix — `MoodRecordStoring`, `SensorCollecting`, `TimelineDataProviding`, `EchoAIProviding`
- Concrete stores: `SwiftData` prefix + type + `Store` suffix — `SwiftDataMoodRecordStore`, `SwiftDataEchoItemStore`
- Entities (SwiftData models): type + `Entity` suffix — `MoodRecordEntity`, `SensorReadingEntity`, `EchoMessageEntity`
- Collectors: type + `Collector` suffix — `LocationCollector`, `MotionCollector`, `PedometerCollector`
- Engines: domain + `Engine` suffix — `PhoneInferenceEngine`, `EchoEngine`, `CareNudgeEngine`

**Types:**
- Structs for value types (records, events, data) — `MoodRecord`, `InferredEvent`, `DayTimeline`, `SensorReading`
- Classes for reference types with identity or delegates — `TodayViewModel`, `LocationCollector`, `EchoMemoryManager`
- Enums for closed sets — `EventKind`, `SensorType`, `EchoAIError`, `AppTab`
- Protocols named as roles (`Storing`, `Providing`, `Collecting`, `Inferring`)

**Functions:**
- camelCase verbs: `loadRecords()`, `saveRecords()`, `inferEvents()`, `rebuildTimeline()`
- Factory methods prefixed `make` — `makeModelContainer()`, `makeTodayViewModel()`, `makeEngine()`
- Getter methods prefixed `get` for non-computed access — `getEchoEngine()`, `getDeviceStateCollector()`
- Internal `private` methods use descriptive verbs — `mergedTimeline(base:)`, `cacheTimeline(_:)`, `refreshDerivedState(referenceDate:)`

**Variables:**
- camelCase: `currentBaseTimeline`, `sensorDataStore`, `echoPromptBuilder`
- Boolean flags: verb + noun pattern — `hasLoadedOnce`, `isLoading`, `showQuickRecord`, `isConfirmedByUser`
- Constants with semantic names — `maxCachedTimelines`, `legacyMoodRecordStoreKey`

**AppStorage / UserDefaults keys:**
- Dot-namespaced strings in reverse-domain style — `"today.hasCompletedOnboarding"`, `"today.echo.lastDailySummaryDate"`, `"today.manualRecords"`

## Code Style

**Formatting:**
- No external formatter configured (no `.swiftformat`, `.editorconfig`). Code follows Xcode defaults.
- Trailing closures used consistently
- `guard` for early exits, not nested `if`
- `@ViewBuilder` for conditional view composition within Views

**Access control:**
- `private` for implementation details within a type
- `private(set)` for published state that only the owning class should mutate — `@Published private(set) var timeline`
- `static` properties on enums for namespace-style organization (`AppColor`, `AppFont`, `AppSpacing`, `AppRadius`)

**Concurrency:**
- `@MainActor` on ViewModels and on SwiftData access methods — `@MainActor final class TodayViewModel`
- `async throws` for all sensor/provider calls
- `Task { @MainActor in ... }` for dispatching delegate callbacks to main actor
- `Sendable` conformance on value types and protocols crossing actor boundaries

**Conditional compilation:**
- `#if os(iOS)` / `#if targetEnvironment(simulator)` to gate platform-specific code
- `#if canImport(HealthKit)` to gate HealthKit extensions

## Design Token System

All UI code uses design tokens from `ios/ToDay/ToDay/Features/Today/TodayTheme.swift`. Never use raw color values in Views.

**Token namespaces:**
- `AppColor.*` — colors (background, surface, semantic event colors)
- `AppFont.*` — typography
- `AppSpacing.*` — spacing (4pt grid: `xxxs`=2, `xxs`=4, `xs`=8, `sm`=12, `md`=16, `lg`=24, `xl`=32, `xxl`=48)
- `AppRadius.*` — corner radii (`sm`=8, `md`=12, `lg`=16, `xl`=20)
- `AppShadow` — `ViewModifier` with `.subtle` and `.elevated` levels; use via `.appShadow(_:)` extension

**Semantic event colors (never mix purposes):**
- `AppColor.sleep` — sleep events
- `AppColor.workout` — workout events
- `AppColor.walk` — active walk events
- `AppColor.mood` — mood records
- `AppColor.shutter` — shutter/photo records
- `AppColor.screen` — screen time
- `AppColor.commute` — commute events
- `AppColor.echo` — Echo AI feature

**Legacy alias:** `TodayTheme.*` exists as a compatibility shim. New code uses `AppColor` / `AppFont` / `AppSpacing` directly. `TodayTheme` will be removed once all callsites migrate.

## Architecture Patterns

**Protocol + concrete pairs:**
Every data store defines a protocol and at least two implementations: a SwiftData production store and an in-memory store for tests.
```swift
protocol MoodRecordStoring { ... }            // ios/ToDay/ToDay/Data/MoodRecordStoring.swift
struct SwiftDataMoodRecordStore: MoodRecordStoring { ... }
struct UserDefaultsMoodRecordStore: MoodRecordStoring { ... }
```

**Dependency injection via `AppContainer`:**
`ios/ToDay/ToDay/App/AppContainer.swift` is a static service locator. All ViewModels receive dependencies as constructor parameters. Tests supply protocols backed by in-memory fakes.

**MVVM:**
- Views own no business logic
- ViewModels are `@MainActor final class` conforming to `ObservableObject`
- Data types are value types (`struct`)

**Entity ↔ Model conversion:**
SwiftData `@Model` entities have `init(from:)` and `update(from:)` methods accepting the domain value type, plus a `toXxx()` method returning the value type.

**Immutable updates on `InferredEvent`:**
Mutations return new instances via copying methods — `withInterval(_:)`, `withSubtitle(_:)`, `withMetrics(_:)`, `applyingAnnotation(_:)` — located in `ios/ToDay/ToDay/Shared/SharedDataTypes.swift`.

## Import Organization

Standard pattern (no enforced linter):
1. `Foundation` / `SwiftUI` / `Combine`
2. System frameworks (`SwiftData`, `CoreLocation`, `HealthKit`)
3. `@testable import ToDay` (test files only)

## Error Handling

**Strategy:** Errors are handled at the call site; non-critical failures are silenced with `try?`.

**Patterns:**
- SwiftData store operations throw; callers use `try?` for non-critical disk writes (e.g., `try? store.save([reading])` in `LocationCollector`)
- Timeline loading catches errors and falls back to empty data rather than propagating to UI — comment: `// HealthKit unavailable — still show mood/shutter records`
- `fatalError` used only for unrecoverable startup failures: `fatalError("无法创建 MoodRecord SwiftData 容器：\(error.localizedDescription)")`
- `assertionFailure` used for migration failures that are non-fatal but should surface in debug builds
- UI-visible errors stored as `@Published var errorMessage: String?` on ViewModels

**Error types:**
- `TimelineDataError` (enum, `LocalizedError`) in `ios/ToDay/ToDay/Data/TimelineDataProviding.swift`
- `EchoAIError` (enum, `LocalizedError`) in `ios/ToDay/ToDay/Data/AI/EchoAIProviding.swift`

## Logging

- No logging framework; no `print` or `os.log` calls found in production code
- Debug information surfaced via `assertionFailure` in migration paths

## Comments

**When to comment:**
- `// MARK: -` sections used consistently to divide types into logical groups
- Inline comments explain non-obvious logic: `// Priority 1: Sleep`, `// Disk cache failure is non-critical`
- Code intent documented when it would otherwise be ambiguous

**Chinese comments:** Used freely in business logic and UI strings; all user-facing strings are Chinese.

**Block comments:** Used for design token file header (ASCII box art explaining the token system).

## Module Design

**Exports:** No barrel `index.swift` files; all types are `internal` by default and accessed via `@testable import ToDay` in tests.

**Encapsulation:** Types expose minimal public surface; `private(set)` for state, `private` for helpers.

---

*Convention analysis: 2026-04-04*
