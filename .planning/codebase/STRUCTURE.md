# Codebase Structure

**Analysis Date:** 2026-04-04

## Directory Layout

```
ToDay/                              # Repo root
├── ios/
│   └── ToDay/
│       ├── ToDay/                  # Main app source (primary focus)
│       │   ├── App/                # Entry point, composition root, root navigation
│       │   ├── Data/               # All data layer code
│       │   │   ├── Sensors/        # Sensor collectors, inference, place management
│       │   │   └── AI/             # Echo AI pipeline
│       │   ├── Features/           # Feature modules (UI + ViewModel per feature)
│       │   │   ├── Today/          # Today screen and its sub-views
│       │   │   │   └── ScrollCanvas/  # DayScrollView timeline rendering
│       │   │   ├── History/        # History screen
│       │   │   ├── Echo/           # Echo AI companion screens
│       │   │   ├── Dashboard/      # Dashboard cards and stats
│       │   │   ├── Shutter/        # Shutter (media capture) screens
│       │   │   ├── Settings/       # Settings screen
│       │   │   └── Onboarding/     # First-run onboarding
│       │   ├── Shared/             # Domain value types shared across layers
│       │   ├── Models/             # SwiftData entity extensions
│       │   └── Resources/          # Assets.xcassets, App Icon
│       ├── ToDayTests/             # XCTest unit tests (mirrors source structure)
│       ├── project.yml             # XcodeGen project definition
│       └── docs/                   # App Store assets
├── web/                            # Next.js web app (paused; browser extension era)
├── design/                         # Design reference files
├── docs/                           # Project-level docs
└── .planning/                      # GSD planning documents
    └── codebase/
```

## Directory Purposes

**`ios/ToDay/ToDay/App/`:**
- Purpose: iOS app lifecycle and dependency composition
- Key files:
  - `ToDayApp.swift` — `@main` entry, scene lifecycle handlers, sensor/Echo startup
  - `AppContainer.swift` — singleton service locator; constructs and owns all shared dependencies (stores, collectors, AI services)
  - `AppRootScreen.swift` — root navigation: onboarding gate + 5-tab layout with center record button
  - `AppConfiguration.swift` — static app metadata (support email, legal URLs)

**`ios/ToDay/ToDay/Data/`:**
- Purpose: All non-UI logic — persistence, sensors, AI, and domain managers
- Key files:
  - `TimelineDataProviding.swift` — protocol defining the timeline source contract
  - `MockTimelineDataProvider.swift` — used on simulator; returns synthetic events
  - `BackgroundTaskManager.swift` — registers and handles BGTaskScheduler tasks
  - `EchoEngine.swift` — schedules Echo notification reminders for shutter records
  - `MoodRecordManager.swift`, `ShutterManager.swift`, `SpendingManager.swift` — domain managers wrapping stores
  - `AnnotationStore.swift` — in-memory user annotation overlay for timeline events
  - `SensorDataStore.swift` — SwiftData store for raw `SensorReading` values

**`ios/ToDay/ToDay/Data/Sensors/`:**
- Purpose: On-device passive data collection
- Key files:
  - `SensorCollecting.swift` — protocol: `collectData(for:)`, `isAvailable`, `sensorType`
  - `SensorTypes.swift` — `SensorType` enum, `SensorReading` struct, `SensorPayload` enum
  - `LocationCollector.swift` — CLLocationManager significant changes + visits
  - `MotionCollector.swift` — CMMotionActivityManager activity recognition
  - `PedometerCollector.swift` — CMPedometer step/distance/floor data
  - `DeviceStateCollector.swift` — screen lock/unlock, charging events
  - `HealthKitCollector.swift` — HealthKit queries (workouts, sleep, heart rate)
  - `PhoneInferenceEngine.swift` — converts raw `[SensorReading]` → `[InferredEvent]` via priority heuristics
  - `PhoneTimelineDataProvider.swift` — orchestrates collect → save → infer → assemble `DayTimeline`
  - `PlaceManager.swift` — tracks known places, geocodes unnamed locations via CLGeocoder

**`ios/ToDay/ToDay/Data/AI/`:**
- Purpose: Echo AI companion intelligence layer
- Key files:
  - `EchoAIProviding.swift` — protocol + types: `EchoChatMessage`, `EchoPersonality`, `EchoUserTier`, `EchoAIError`
  - `EchoAIService.swift` — routes between `AppleLocalAIProvider` (free) and `DeepSeekAIProvider` (pro)
  - `AppleLocalAIProvider.swift` — on-device Apple Foundation Models
  - `DeepSeekAIProvider.swift` — DeepSeek cloud API
  - `EchoPromptBuilder.swift` — constructs system+user prompts from context + memory
  - `EchoMemoryManager.swift` — reads/writes `UserProfileEntity`, `DailySummaryEntity`, `ConversationMemoryEntity`
  - `EchoDailySummaryGenerator.swift` — generates daily summaries from today's data
  - `EchoWeeklyProfileUpdater.swift` — updates user personality profile weekly
  - `EchoScheduler.swift` — orchestrates AI jobs on app launch/background
  - `EchoMessageManager.swift` — manages `EchoMessageEntity` inbox + unread badge count
  - `EchoChatSession.swift` — manages chat thread message history

**`ios/ToDay/ToDay/Features/Today/`:**
- Purpose: Main "Today Canvas" screen — the core product UI
- Key files:
  - `TodayScreen.swift` — primary view; header, flow signature, scroll canvas, summary, weekly insight, recent days
  - `TodayViewModel.swift` — `@MainActor ObservableObject`; owns timeline loading, caching, merge, and all record mutations
  - `TodayTheme.swift` — design token system: `AppColor`, `AppFont`, `AppSpacing`, `AppRadius`; reusable components `ContentCard`, `EyebrowLabel`, `FlexibleBadgeRow`
  - `TodayFlowViews.swift` — flow signature visualization (timeline overview strip)
  - `TodayInsightComposer.swift` — builds `TodayInsightSummary` and `WeeklyInsightSummary` from record data
  - `QuickRecordSheet.swift` — mood record creation sheet
  - `AnnotationSheet.swift` — event annotation sheet
  - `EventDetailView.swift` — event detail sheet
  - `ScrollCanvas/DayScrollView.swift` — vertical timeline canvas rendering `DayTimeline`
  - `ScrollCanvas/EventCardView.swift` — individual event card within the canvas
  - `ScrollCanvas/ScrollShareService.swift` — renders the timeline as a `UIImage` for sharing

**`ios/ToDay/ToDay/Features/History/`:**
- Purpose: Browse past days' timelines with date strip navigation
- Key files: `HistoryScreen.swift`, `HistoryDayDetailScreen.swift`, `WeeklyInsightView.swift`

**`ios/ToDay/ToDay/Features/Echo/`:**
- Purpose: Echo AI companion inbox and chat interface
- Key files: `EchoScreen.swift`, `EchoViewModel.swift`, `EchoMessageListView.swift`, `EchoChatScreen.swift`, `EchoChatViewModel.swift`, `EchoThreadView.swift`, `EchoThreadViewModel.swift`, `EchoMirrorSheet.swift`, `EchoDailyInsightCard.swift`

**`ios/ToDay/ToDay/Features/Shutter/`:**
- Purpose: Capture moments via text, voice, photo, or video
- Key files: `ShutterPanel.swift`, `ShutterAlbumScreen.swift`, `ShutterTextComposer.swift`, `VoiceRecordingOverlay.swift`, `CameraPickerView.swift`

**`ios/ToDay/ToDay/Features/Dashboard/`:**
- Purpose: Summary card view of today's health metrics
- Key files: `DashboardView.swift`, `DashboardViewModel.swift`, `DashboardCardView.swift`, `RecordPanel.swift`

**`ios/ToDay/ToDay/Shared/`:**
- Purpose: Pure value types that form the domain model — the only layer with zero dependencies
- Key files:
  - `SharedDataTypes.swift` — `InferredEvent`, `DayTimeline`, `TimelineStat`, `EventKind`, `EventConfidence`, `EventMetrics`, `SensorReading`, `SensorPayload`, `DayRawData`, `LocationVisit`, `WorkoutSample`, `SleepSample`, etc.
  - `MoodRecord.swift` — mood entry value type + `Mood` enum
  - `ShutterRecord.swift` — shutter capture value type
  - `SpendingRecord.swift` — spending entry value type
  - `ScreenTimeRecord.swift` — daily screen time value type
  - `EchoItem.swift` — Echo notification item value type
  - `EchoMessage.swift` — Echo inbox message value type
  - `WatchMessage.swift`, `ConnectivityManager.swift` — WatchConnectivity transport types

**`ios/ToDay/ToDayTests/`:**
- Purpose: XCTest unit tests; mirrors source structure by component name
- Key test files: `TodayViewModelSessionTests.swift`, `TimelineMergeTests.swift`, `PhoneInferenceEngineTests.swift`, `PhoneTimelineDataProviderTests.swift`, `EchoAIServiceTests.swift`, `SensorDataStoreTests.swift`

## Key File Locations

**Entry Points:**
- `ios/ToDay/ToDay/App/ToDayApp.swift` — `@main`; scene lifecycle
- `ios/ToDay/ToDay/App/AppContainer.swift` — dependency composition root
- `ios/ToDay/ToDay/App/AppRootScreen.swift` — root navigation shell

**Design System:**
- `ios/ToDay/ToDay/Features/Today/TodayTheme.swift` — all design tokens (`AppColor`, `AppFont`, `AppSpacing`, `AppRadius`) and shared components

**Domain Model:**
- `ios/ToDay/ToDay/Shared/SharedDataTypes.swift` — canonical definitions for `InferredEvent`, `DayTimeline`, `EventKind`

**Timeline Pipeline:**
- `ios/ToDay/ToDay/Data/Sensors/PhoneTimelineDataProvider.swift` — full sensor → timeline assembly
- `ios/ToDay/ToDay/Data/Sensors/PhoneInferenceEngine.swift` — event inference heuristics
- `ios/ToDay/ToDay/Features/Today/TodayViewModel.swift` — timeline loading, caching, merge

**Timeline Rendering:**
- `ios/ToDay/ToDay/Features/Today/ScrollCanvas/DayScrollView.swift` — vertical canvas
- `ios/ToDay/ToDay/Features/Today/ScrollCanvas/EventCardView.swift` — individual event card

**Configuration:**
- `ios/ToDay/ToDay/App/AppConfiguration.swift` — app metadata (URLs, email)
- `ios/ToDay/project.yml` — XcodeGen project definition (source of truth for Xcode project)

## Naming Conventions

**Files:**
- Feature screen views: `{Feature}Screen.swift` (e.g., `TodayScreen.swift`, `HistoryScreen.swift`)
- Sheet/sub-views: `{Noun}Sheet.swift` or `{Noun}View.swift` (e.g., `QuickRecordSheet.swift`, `EventDetailView.swift`)
- ViewModels: `{Feature}ViewModel.swift` (e.g., `TodayViewModel.swift`)
- Protocols: Suffixed with the capability they represent (`TimelineDataProviding`, `SensorCollecting`, `MoodRecordStoring`)
- SwiftData entities: `{Domain}Entity.swift` (e.g., `MoodRecordEntity.swift`)
- Domain managers: `{Domain}Manager.swift` (e.g., `MoodRecordManager.swift`, `ShutterManager.swift`)

**Types:**
- Protocols: gerund/adjective descriptors (`TimelineDataProviding`, `EchoAIProviding`, `SensorCollecting`)
- Enums for namespacing design tokens: `AppColor`, `AppFont`, `AppSpacing`, `AppRadius`
- SwiftData `@Model` classes: `{Name}Entity` suffix
- Value types (Shared): no suffix, plain domain names (`MoodRecord`, `InferredEvent`, `DayTimeline`)

**Directories:**
- Feature directories match their SwiftUI screen name without "Screen" suffix (e.g., `Features/Today/`, `Features/Echo/`)

## Where to Add New Code

**New Feature Screen:**
- Implementation: `ios/ToDay/ToDay/Features/{FeatureName}/{FeatureName}Screen.swift`
- ViewModel: `ios/ToDay/ToDay/Features/{FeatureName}/{FeatureName}ViewModel.swift`
- Register tab in: `ios/ToDay/ToDay/App/AppRootScreen.swift`

**New Data Record Type:**
- Value type: `ios/ToDay/ToDay/Shared/{Type}Record.swift`
- SwiftData entity: `ios/ToDay/ToDay/Data/{Type}RecordEntity.swift`
- Storage protocol: `ios/ToDay/ToDay/Data/{Type}RecordStoring.swift`
- Register entity in: `ios/ToDay/ToDay/App/AppContainer.makeModelContainer()`
- Wire store in: `AppContainer` static properties

**New Sensor Collector:**
- Implementation: `ios/ToDay/ToDay/Data/Sensors/{Sensor}Collector.swift` conforming to `SensorCollecting`
- Register in: `AppContainer.availableCollectors()`

**New Event Kind:**
- Add case to `EventKind` enum in `ios/ToDay/ToDay/Shared/SharedDataTypes.swift`
- Add color to `AppColor` in `ios/ToDay/ToDay/Features/Today/TodayTheme.swift`
- Handle in `PhoneInferenceEngine` if sensor-driven
- Handle in `EventCardView` for rendering

**New UI Component:**
- Shared reusable components: add to `ios/ToDay/ToDay/Features/Today/TodayTheme.swift` (following `ContentCard`, `EyebrowLabel` pattern)
- Feature-specific components: co-locate within the feature directory

**Utilities / Shared Helpers:**
- Pure value type utilities: `ios/ToDay/ToDay/Shared/SharedDataTypes.swift` extensions or a new file in `Shared/`
- No separate `Utils/` or `Helpers/` directory exists; keep helpers close to their primary consumer

## Special Directories

**`ios/ToDay/ToDay/Resources/`:**
- Purpose: Asset catalog (app icon, accent color)
- Generated: No
- Committed: Yes

**`ios/ToDay/ToDay/Preview Content/`:**
- Purpose: Xcode preview assets
- Generated: No
- Committed: Yes

**`ios/ToDay/build/`:**
- Purpose: Xcode build artifacts
- Generated: Yes
- Committed: No (in `.gitignore`)

**`web/`:**
- Purpose: Next.js web app (legacy browser extension dashboard era — currently paused)
- Generated: Partially (`.next/` is generated)
- Committed: Source files yes, `.next/` no

**`.planning/`:**
- Purpose: GSD planning documents
- Generated: No
- Committed: Yes

---

*Structure analysis: 2026-04-04*
