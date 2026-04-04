# Architecture

**Analysis Date:** 2026-04-04

## Pattern Overview

**Overall:** Feature-Sliced MVVM with Protocol-Oriented Data Layer

**Key Characteristics:**
- SwiftUI views bind to `@ObservableObject` ViewModels; no Redux or Composable Architecture
- Data access gated behind protocols (e.g., `TimelineDataProviding`, `MoodRecordStoring`, `SensorCollecting`) — concrete implementations swappable at `AppContainer` composition root
- All persistent state is SwiftData; zero cloud sync; fully local-first
- `AppContainer` (enum acting as service locator) wires the full dependency graph at startup; ViewModels receive injected dependencies rather than constructing them

## Layers

**App / Composition Root:**
- Purpose: Entry point, scene lifecycle, dependency wiring
- Location: `ios/ToDay/ToDay/App/`
- Contains: `ToDayApp`, `AppContainer`, `AppRootScreen`, `AppConfiguration`
- Depends on: All other layers
- Used by: iOS runtime only

**Features (UI Layer):**
- Purpose: SwiftUI screens, sub-views, and their ViewModels
- Location: `ios/ToDay/ToDay/Features/`
- Contains: Screen views, sheet components, ViewModels; one sub-directory per feature
- Depends on: Shared types, Data layer protocols
- Used by: App layer (navigation), other features (shared ViewModel like `TodayViewModel`)

**Data Layer:**
- Purpose: Sensor collection, persistence, AI services, managers
- Location: `ios/ToDay/ToDay/Data/`
- Contains: Protocol definitions + SwiftData implementations for all stores, sensor collectors, inference engine, Echo AI pipeline
- Depends on: Shared types, SwiftData, system frameworks (CoreLocation, CoreMotion, HealthKit)
- Used by: Features layer via injected protocols

**Shared (Domain Types):**
- Purpose: Value types shared across the whole app — the domain model
- Location: `ios/ToDay/ToDay/Shared/`
- Contains: `SharedDataTypes.swift` (defines `InferredEvent`, `DayTimeline`, `EventKind`, `SensorReading` etc.), record value types (`MoodRecord`, `ShutterRecord`, `SpendingRecord`, `ScreenTimeRecord`), connectivity types
- Depends on: Nothing (pure Swift value types)
- Used by: All other layers

**Models (SwiftData Entities):**
- Purpose: SwiftData `@Model` classes that persist Shared types to disk
- Location: `ios/ToDay/ToDay/Models/` + entity files inline in `Data/`
- Contains: `MoodRecordEntity`, `DayTimelineEntity`, `ShutterRecordEntity`, `SpendingRecordEntity`, `ScreenTimeRecordEntity`, `EchoItemEntity`, `EchoMessageEntity`, `SensorReadingEntity`, `UserProfileEntity`, `DailySummaryEntity`, `ConversationMemoryEntity`, `EchoChatSessionEntity`, `EchoChatMessageEntity`
- Depends on: Shared types (for `toMoodRecord()` / `update(from:)` mapping pattern)
- Used by: Data layer stores

## Data Flow

**Sensor → Timeline (primary auto-recording flow):**

1. `LocationCollector` / `MotionCollector` / `PedometerCollector` / `DeviceStateCollector` / `HealthKitCollector` each implement `SensorCollecting` and write `SensorReading` values to `SensorDataStore` (SwiftData)
2. `PhoneTimelineDataProvider.loadTimeline(for:)` calls all collectors, saves fresh readings to `SensorDataStore`, reads back all readings for the date
3. `PlaceManager` ingests location visit readings, reverse-geocodes unnamed places via `CLGeocoder`
4. `PhoneInferenceEngine.inferEvents(from:on:places:)` applies priority-ordered heuristics (sleep → commute → exercise → location stays → quiet time → blank gaps) to produce `[InferredEvent]`
5. `PhoneTimelineDataProvider` wraps events into a `DayTimeline` (source: `.phone`) and returns it
6. `TodayViewModel.load()` receives the base `DayTimeline` and calls `mergedTimeline(base:)` to overlay manual records (mood, shutter, spending, screen time, annotations), producing the final displayed timeline
7. `TodayScreen` binds to `@Published var timeline: DayTimeline?` and renders via `DayScrollView`

**Manual Record → Timeline:**

1. User action (e.g., quick record sheet) → `TodayViewModel.startMoodRecord(_:)` → `MoodRecordManager.startRecord(_:)` → `MoodRecordStoring.saveRecords()`
2. `TodayViewModel` calls `rebuildTimeline(referenceDate:)` which calls `mergedTimeline(base:)` synchronously
3. `@Published var timeline` updates → SwiftUI re-renders

**Background refresh:**

1. App enters background → `BackgroundTaskManager.scheduleAppRefresh()` registers `BGAppRefreshTask` (identifier: `com.looanli.today.refresh`)
2. System fires task (≥1 hour later) → `BackgroundTaskManager.generateTodayTimeline()` → `PhoneTimelineDataProvider.loadTimeline(for:)` → persists result to `DayTimelineEntity` via SwiftData
3. On foreground return, `TodayViewModel.load(forceReload: true)` reads from disk cache first, then provider if needed

**Echo AI pipeline:**

1. `EchoScheduler.onAppBackground(...)` is called with today's data summaries
2. `EchoDailySummaryGenerator` builds a prompt via `EchoPromptBuilder` (which queries `EchoMemoryManager` for user profile + conversation history) and calls `EchoAIService.summarize(prompt:)`
3. `EchoAIService` routes to `AppleLocalAIProvider` (free tier, on-device) or `DeepSeekAIProvider` (pro tier, cloud) based on `EchoUserTier`
4. Results stored as `DailySummaryEntity` and `EchoMessageEntity` in SwiftData; `EchoMessageManager` surfaces them in the Echo tab with unread badge count

**State Management:**
- Primary UI state lives in `TodayViewModel` (`@MainActor`, `@Published` properties)
- Each feature has its own ViewModel; `EchoViewModel`, `EchoChatViewModel`, `EchoThreadViewModel` are separate objects
- No global state store; ViewModels communicate through callbacks or shared `TodayViewModel` reference
- WatchConnectivity sync via `PhoneConnectivityManager` / `WatchSyncHelper` pushes daily summaries to Apple Watch

## Key Abstractions

**`TimelineDataProviding` protocol:**
- Purpose: Abstracts the source of timeline data (mock vs. real sensors vs. HealthKit)
- Examples: `ios/ToDay/ToDay/Data/TimelineDataProviding.swift`
- Pattern: `AppContainer.makeTimelineProvider()` returns `MockTimelineDataProvider()` on simulator and `PhoneTimelineDataProvider(...)` on device

**`SensorCollecting` protocol:**
- Purpose: Uniform interface across all sensor types
- Examples: `ios/ToDay/ToDay/Data/Sensors/SensorCollecting.swift`
- Implementations: `LocationCollector`, `MotionCollector`, `PedometerCollector`, `DeviceStateCollector`, `HealthKitCollector`

**`XxxStoring` protocols (MoodRecordStoring, ShutterRecordStoring, etc.):**
- Purpose: Decouple persistence implementation from feature code; enables in-memory fallbacks for tests
- Examples: `ios/ToDay/ToDay/Data/MoodRecordStoring.swift`, `ios/ToDay/ToDay/Data/EchoItemStoring.swift`
- Pattern: Protocol declared in `Data/`, SwiftData implementation (`SwiftDataXxxStore`) implemented inline in same file

**`EchoAIProviding` protocol:**
- Purpose: Abstracts AI backend (local vs. cloud)
- Examples: `ios/ToDay/ToDay/Data/AI/EchoAIProviding.swift`
- Implementations: `AppleLocalAIProvider` (free), `DeepSeekAIProvider` (pro); `EchoAIService` routes between them

**`InferredEvent` value type:**
- Purpose: Universal timeline entry — whether from sensor inference, manual mood record, shutter capture, or spending log
- Location: `ios/ToDay/ToDay/Shared/SharedDataTypes.swift`
- Pattern: Identified by SHA256-derived stable UUID from (kind, startDate, endDate, displayName); supports fluent copying (`withInterval`, `withMetrics`, `applyingAnnotation`)

## Entry Points

**App Entry (`@main`):**
- Location: `ios/ToDay/ToDay/App/ToDayApp.swift`
- Triggers: iOS launches the app
- Responsibilities: Creates root ViewModels via `AppContainer`, injects `modelContainer`, starts sensor monitoring and Echo scheduler on `.task`, schedules background tasks on scene phase change

**`AppRootScreen`:**
- Location: `ios/ToDay/ToDay/App/AppRootScreen.swift`
- Triggers: Rendered by `ToDayApp`
- Responsibilities: Onboarding gate (`@AppStorage("today.hasCompletedOnboarding")`), 5-tab layout (History, Shutter, center + button, Echo, Settings), center record button intercept via `Binding<AppTab>`

**Background Task Entry:**
- Location: `ios/ToDay/ToDay/Data/BackgroundTaskManager.swift`
- Triggers: `BGTaskScheduler` fires `com.looanli.today.refresh` or `com.looanli.today.processing`
- Responsibilities: Timeline generation for today (refresh) or backfill of past 7 days (processing); sensor data purge (keep 30 days)

## Error Handling

**Strategy:** Non-fatal degradation — individual failures do not crash the app or block the UI

**Patterns:**
- `PhoneTimelineDataProvider` catches per-collector failures and continues with remaining collectors
- `TodayViewModel.load()` catches timeline provider errors with a fallback empty `DayTimeline`, allowing manual records to still appear
- SwiftData disk-cache failures are caught and printed; non-critical
- `EchoAIService` throws `EchoAIError.providerUnavailable` when no provider is available; UI shows a recoverable error state

## Cross-Cutting Concerns

**Logging:** `print(...)` statements with bracketed prefixes (e.g., `[PhoneTimelineDataProvider]`, `[BGTask]`). No structured logging framework.

**Validation:** Performed at the ViewModel layer (e.g., guard in `startMoodRecord`); no dedicated validation layer.

**Authentication:** Not applicable — fully local, no user accounts.

**Concurrency:** `@MainActor` on all ViewModels and stores. `SensorCollecting` and `EchoAIProviding` are `Sendable`. SwiftData accessed via `ModelContext` created per operation in background contexts.

**Design Tokens:** Centralized in `ios/ToDay/ToDay/Features/Today/TodayTheme.swift` as `AppColor`, `AppFont`, `AppSpacing`, `AppRadius` enums. `TodayTheme` is a legacy alias layer mapping old names to `AppColor`; new code uses `AppColor` directly.

---

*Architecture analysis: 2026-04-04*
