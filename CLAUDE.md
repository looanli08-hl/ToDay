# Unfold (working name)

iOS 自动生活记录 App — "把你的一天变成一张会让你想看的生活画卷"

## 当前方向

**被动记录，零输入，睡前打开一看就懂。不批判、不评价，只呈现"你今天是怎么度过的"。**

开发分支: `feature/phone-first-auto-recording`

## v1 范围

1. CoreLocation 自动记录地点 + 停留时长
2. 地点自动标签（CLGeocoder 反向地理编码）
3. 精美的"今日画卷"时间轴（设计是核心壁垒）
4. AI 每日总结（DeepSeek API，观察性语气）
5. AI 模式识别 + 主动推送
6. Echo 对话（用自然语言查询生活数据）

## 不做（v1 阶段）

- ❌ 心率 / Apple Watch
- ❌ 屏幕时间自动采集
- ❌ 分享卡片 / 社交
- ❌ 云端同步
- ❌ Web / Chrome Extension（已暂停）
- ❌ 付费/订阅系统

## Tech Stack

- SwiftUI + iOS 17+
- CoreLocation (significant location changes + visits)
- CoreMotion (activity recognition)
- SwiftData (local-first storage)
- XcodeGen (project.yml → .xcodeproj)

## 项目结构

```
ios/ToDay/ToDay/
├── App/          — ToDayApp, AppContainer, AppRootScreen
├── Data/
│   ├── Sensors/  — LocationCollector, MotionCollector, PlaceManager, PhoneInferenceEngine, PhoneTimelineDataProvider
│   └── ...       — BackgroundTaskManager, SensorDataStore
├── Features/
│   ├── Today/    — TodayScreen, TodayViewModel, ScrollCanvas (DayScrollView, EventCardView)
│   ├── History/  — HistoryScreen
│   ├── Onboarding/
│   └── Settings/
├── Shared/       — SharedDataTypes, InferredEvent, DayTimeline
└── Models/
```

## 构建命令

```bash
# Build (simulator, no signing)
cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Run tests
cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Regenerate Xcode project after adding/removing files
cd ios/ToDay && xcodegen generate
```

## 验证流程

每次改动后必须：
1. `xcodegen generate`
2. Build 通过
3. 180+ tests 通过

## 竞品定位

- 直接竞品：Life Cycle（地点饼图）、Arc Timeline（时间线）
- 差异化：它们给数据，我们给感受。设计是唯一壁垒。

## UI Design

Also read `Projects/ToDay/.impeccable.md` for complete design context (users, brand, references, anti-references, motion, typography).

### Color System (established in TodayTheme.swift)
- Accent: Teal (#5B9A8B / #7CC1AF)
- Background: Warm cream (#F8F5F0) / Warm dark (#121213)
- Semantic: Sleep (indigo), Workout (amber), Walk (green), Commute (blue)
- Rule: No pure black, no pure gray — always tint toward warmth

### Design Principles
1. Reduction is the feature — strip to essence before adding
2. Apple-level quality bar — if it doesn't feel native iOS, it's not done
3. No generic AI aesthetics (no Inter, no purple gradients, no card-in-card)
4. Timeline is art, not data — design for the 11pm passive viewing moment

<!-- GSD:project-start source:PROJECT.md -->
## Project

**Unfold**

Unfold 是一个 iOS 自动生活记录 App，通过手机传感器（位置、运动、设备状态）被动记录用户的一天，零输入生成一张精美的"今日画卷"时间轴。结合 AI 洞察，不仅呈现用户的一天，还帮助他们理解自己的生活模式和习惯。

目标用户：所有想要回看自己一天但懒得手动记录的人。第一批种子用户不限定，通过 Build in Public 吸引早期使用者。

**Core Value:** **让用户睡前打开 App，一眼看到自己今天是怎么度过的，并从 AI 那里获得一句让他想继续用的洞察。**

### Constraints

- **Tech Stack**: SwiftUI + iOS 17+ + SwiftData, 不引入第三方 UI 框架
- **隐私**: 数据本地优先，云端 API 调用只传必要上下文，不传原始位置数据
- **设计**: 必须达到 Apple 级别品质，参考 .impeccable.md 设计规范
- **平台**: iPhone only（无 iPad/Mac），MVP 无 Watch
- **AI 后端**: 混合架构 — 设备端处理简单推理，复杂分析调用云端 API
- **Solo dev**: 一个人开发，scope 必须可控
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

## Languages
- Swift 5.0 — All iOS app logic, UI, and data layers (`ios/ToDay/ToDay/`)
- TypeScript — Abandoned web companion (`web/src/components/`) — not actively developed
- ArkTS / ArkUI — HarmonyOS companion port (`harmonyos/ToDay/`) — appears to be a parallel experiment, not the main codebase
## Runtime
- iOS 17.0+ deployment target (set in `ios/ToDay/project.yml`)
- Apple Foundation Models (`FoundationModels`) targeted for iOS 26+ — guarded behind `#available(iOS 26, *)` in `AppleLocalAIProvider.swift`
- No third-party Swift Package Manager dependencies — zero external packages
- XcodeGen 2.45.0+ to generate `.xcodeproj` from `ios/ToDay/project.yml`
## Frameworks
- SwiftUI — All screens and views
- UIKit — Used directly for sharing (`ScrollShareService.swift`), camera (`CameraPickerView.swift`), photo loading, and bridging
- SwiftData — Primary local store; all entities use `@Model` macros
- CoreLocation — GPS visits + significant location changes (`LocationCollector.swift`)
- CoreMotion — Activity recognition + step counting (`MotionCollector.swift`, `PedometerCollector.swift`)
- HealthKit — Heart rate, step count, active energy, sleep analysis, workouts (`HealthKitCollector.swift`)
- WeatherKit — Hourly weather overlay for timeline events (`WeatherService.swift`)
- WatchConnectivity — Bidirectional sync with Apple Watch app (`ConnectivityManager.swift`)
- Photos / PhotosUI — Photo library access for daily photo matching (`PhotoService.swift`)
- AVFoundation — Voice recording (`VoiceRecordView.swift`)
- Speech — On-device speech recognition for voice-to-text transcription (`VoiceRecordView.swift`)
- BackgroundTasks — BGAppRefreshTask + BGProcessingTask for passive timeline generation (`BackgroundTaskManager.swift`)
- Charts (Apple native) — Heart rate and event metrics visualization (`EventDetailView.swift`)
- UserNotifications — Local notification scheduling for Echo AI reminders (`EchoEngine.swift`)
- XCTest — Unit test framework (`ios/ToDay/ToDayTests/`)
- CryptoKit — SHA-256 for deterministic event ID derivation from content hash (`SharedDataTypes.swift`)
## Key Dependencies
## Configuration
- `ios/ToDay/project.yml` — XcodeGen spec; run `xcodegen generate` to regenerate `.xcodeproj`
- Bundle ID: `com.looanli.today`
- Version: 0.3.0 (marketing), build 3
- Development Team: `G89F57S8M3`
- `TODAY_USE_MOCK=1` — Forces MockTimelineDataProvider regardless of device type
- Simulator auto-detects and uses MockTimelineDataProvider (`#if targetEnvironment(simulator)`)
- `NSHealthShareUsageDescription` — HealthKit read access
- `NSLocationAlwaysAndWhenInUseUsageDescription` — Background location
- `NSPhotoLibraryUsageDescription` — Photo library read
- `NSCameraUsageDescription` — Camera capture
- `NSMicrophoneUsageDescription` — Voice recording
- `NSSpeechRecognitionUsageDescription` — On-device speech transcription
- `NSMotionUsageDescription` — CoreMotion activity
- `fetch` — App refresh background task
- `processing` — BGProcessingTask for backfill
## Platform Requirements
- Xcode (supports iOS 26 SDK for FoundationModels — currently placeholder)
- XcodeGen 2.45.0+
- macOS host
- iPhone only (`TARGETED_DEVICE_FAMILY: 1`)
- iOS 17.0+ minimum
- Apple Watch companion app (source not in this repo — Watch target uses WatchConnectivity)
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

## Naming Patterns
- Views: `PascalCase` with role suffix — `TodayScreen.swift`, `EventCardView.swift`, `QuickRecordSheet.swift`
- ViewModels: `PascalCase` with `ViewModel` suffix — `TodayViewModel.swift`, `DashboardViewModel.swift`
- Protocols: `PascalCase` with gerund suffix — `MoodRecordStoring`, `SensorCollecting`, `TimelineDataProviding`, `EchoAIProviding`
- Concrete stores: `SwiftData` prefix + type + `Store` suffix — `SwiftDataMoodRecordStore`, `SwiftDataEchoItemStore`
- Entities (SwiftData models): type + `Entity` suffix — `MoodRecordEntity`, `SensorReadingEntity`, `EchoMessageEntity`
- Collectors: type + `Collector` suffix — `LocationCollector`, `MotionCollector`, `PedometerCollector`
- Engines: domain + `Engine` suffix — `PhoneInferenceEngine`, `EchoEngine`, `CareNudgeEngine`
- Structs for value types (records, events, data) — `MoodRecord`, `InferredEvent`, `DayTimeline`, `SensorReading`
- Classes for reference types with identity or delegates — `TodayViewModel`, `LocationCollector`, `EchoMemoryManager`
- Enums for closed sets — `EventKind`, `SensorType`, `EchoAIError`, `AppTab`
- Protocols named as roles (`Storing`, `Providing`, `Collecting`, `Inferring`)
- camelCase verbs: `loadRecords()`, `saveRecords()`, `inferEvents()`, `rebuildTimeline()`
- Factory methods prefixed `make` — `makeModelContainer()`, `makeTodayViewModel()`, `makeEngine()`
- Getter methods prefixed `get` for non-computed access — `getEchoEngine()`, `getDeviceStateCollector()`
- Internal `private` methods use descriptive verbs — `mergedTimeline(base:)`, `cacheTimeline(_:)`, `refreshDerivedState(referenceDate:)`
- camelCase: `currentBaseTimeline`, `sensorDataStore`, `echoPromptBuilder`
- Boolean flags: verb + noun pattern — `hasLoadedOnce`, `isLoading`, `showQuickRecord`, `isConfirmedByUser`
- Constants with semantic names — `maxCachedTimelines`, `legacyMoodRecordStoreKey`
- Dot-namespaced strings in reverse-domain style — `"today.hasCompletedOnboarding"`, `"today.echo.lastDailySummaryDate"`, `"today.manualRecords"`
## Code Style
- No external formatter configured (no `.swiftformat`, `.editorconfig`). Code follows Xcode defaults.
- Trailing closures used consistently
- `guard` for early exits, not nested `if`
- `@ViewBuilder` for conditional view composition within Views
- `private` for implementation details within a type
- `private(set)` for published state that only the owning class should mutate — `@Published private(set) var timeline`
- `static` properties on enums for namespace-style organization (`AppColor`, `AppFont`, `AppSpacing`, `AppRadius`)
- `@MainActor` on ViewModels and on SwiftData access methods — `@MainActor final class TodayViewModel`
- `async throws` for all sensor/provider calls
- `Task { @MainActor in ... }` for dispatching delegate callbacks to main actor
- `Sendable` conformance on value types and protocols crossing actor boundaries
- `#if os(iOS)` / `#if targetEnvironment(simulator)` to gate platform-specific code
- `#if canImport(HealthKit)` to gate HealthKit extensions
## Design Token System
- `AppColor.*` — colors (background, surface, semantic event colors)
- `AppFont.*` — typography
- `AppSpacing.*` — spacing (4pt grid: `xxxs`=2, `xxs`=4, `xs`=8, `sm`=12, `md`=16, `lg`=24, `xl`=32, `xxl`=48)
- `AppRadius.*` — corner radii (`sm`=8, `md`=12, `lg`=16, `xl`=20)
- `AppShadow` — `ViewModifier` with `.subtle` and `.elevated` levels; use via `.appShadow(_:)` extension
- `AppColor.sleep` — sleep events
- `AppColor.workout` — workout events
- `AppColor.walk` — active walk events
- `AppColor.mood` — mood records
- `AppColor.shutter` — shutter/photo records
- `AppColor.screen` — screen time
- `AppColor.commute` — commute events
- `AppColor.echo` — Echo AI feature
## Architecture Patterns
- Views own no business logic
- ViewModels are `@MainActor final class` conforming to `ObservableObject`
- Data types are value types (`struct`)
## Import Organization
## Error Handling
- SwiftData store operations throw; callers use `try?` for non-critical disk writes (e.g., `try? store.save([reading])` in `LocationCollector`)
- Timeline loading catches errors and falls back to empty data rather than propagating to UI — comment: `// HealthKit unavailable — still show mood/shutter records`
- `fatalError` used only for unrecoverable startup failures: `fatalError("无法创建 MoodRecord SwiftData 容器：\(error.localizedDescription)")`
- `assertionFailure` used for migration failures that are non-fatal but should surface in debug builds
- UI-visible errors stored as `@Published var errorMessage: String?` on ViewModels
- `TimelineDataError` (enum, `LocalizedError`) in `ios/ToDay/ToDay/Data/TimelineDataProviding.swift`
- `EchoAIError` (enum, `LocalizedError`) in `ios/ToDay/ToDay/Data/AI/EchoAIProviding.swift`
## Logging
- No logging framework; no `print` or `os.log` calls found in production code
- Debug information surfaced via `assertionFailure` in migration paths
## Comments
- `// MARK: -` sections used consistently to divide types into logical groups
- Inline comments explain non-obvious logic: `// Priority 1: Sleep`, `// Disk cache failure is non-critical`
- Code intent documented when it would otherwise be ambiguous
## Module Design
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## Pattern Overview
- SwiftUI views bind to `@ObservableObject` ViewModels; no Redux or Composable Architecture
- Data access gated behind protocols (e.g., `TimelineDataProviding`, `MoodRecordStoring`, `SensorCollecting`) — concrete implementations swappable at `AppContainer` composition root
- All persistent state is SwiftData; zero cloud sync; fully local-first
- `AppContainer` (enum acting as service locator) wires the full dependency graph at startup; ViewModels receive injected dependencies rather than constructing them
## Layers
- Purpose: Entry point, scene lifecycle, dependency wiring
- Location: `ios/ToDay/ToDay/App/`
- Contains: `ToDayApp`, `AppContainer`, `AppRootScreen`, `AppConfiguration`
- Depends on: All other layers
- Used by: iOS runtime only
- Purpose: SwiftUI screens, sub-views, and their ViewModels
- Location: `ios/ToDay/ToDay/Features/`
- Contains: Screen views, sheet components, ViewModels; one sub-directory per feature
- Depends on: Shared types, Data layer protocols
- Used by: App layer (navigation), other features (shared ViewModel like `TodayViewModel`)
- Purpose: Sensor collection, persistence, AI services, managers
- Location: `ios/ToDay/ToDay/Data/`
- Contains: Protocol definitions + SwiftData implementations for all stores, sensor collectors, inference engine, Echo AI pipeline
- Depends on: Shared types, SwiftData, system frameworks (CoreLocation, CoreMotion, HealthKit)
- Used by: Features layer via injected protocols
- Purpose: Value types shared across the whole app — the domain model
- Location: `ios/ToDay/ToDay/Shared/`
- Contains: `SharedDataTypes.swift` (defines `InferredEvent`, `DayTimeline`, `EventKind`, `SensorReading` etc.), record value types (`MoodRecord`, `ShutterRecord`, `SpendingRecord`, `ScreenTimeRecord`), connectivity types
- Depends on: Nothing (pure Swift value types)
- Used by: All other layers
- Purpose: SwiftData `@Model` classes that persist Shared types to disk
- Location: `ios/ToDay/ToDay/Models/` + entity files inline in `Data/`
- Contains: `MoodRecordEntity`, `DayTimelineEntity`, `ShutterRecordEntity`, `SpendingRecordEntity`, `ScreenTimeRecordEntity`, `EchoItemEntity`, `EchoMessageEntity`, `SensorReadingEntity`, `UserProfileEntity`, `DailySummaryEntity`, `ConversationMemoryEntity`, `EchoChatSessionEntity`, `EchoChatMessageEntity`
- Depends on: Shared types (for `toMoodRecord()` / `update(from:)` mapping pattern)
- Used by: Data layer stores
## Data Flow
- Primary UI state lives in `TodayViewModel` (`@MainActor`, `@Published` properties)
- Each feature has its own ViewModel; `EchoViewModel`, `EchoChatViewModel`, `EchoThreadViewModel` are separate objects
- No global state store; ViewModels communicate through callbacks or shared `TodayViewModel` reference
- WatchConnectivity sync via `PhoneConnectivityManager` / `WatchSyncHelper` pushes daily summaries to Apple Watch
## Key Abstractions
- Purpose: Abstracts the source of timeline data (mock vs. real sensors vs. HealthKit)
- Examples: `ios/ToDay/ToDay/Data/TimelineDataProviding.swift`
- Pattern: `AppContainer.makeTimelineProvider()` returns `MockTimelineDataProvider()` on simulator and `PhoneTimelineDataProvider(...)` on device
- Purpose: Uniform interface across all sensor types
- Examples: `ios/ToDay/ToDay/Data/Sensors/SensorCollecting.swift`
- Implementations: `LocationCollector`, `MotionCollector`, `PedometerCollector`, `DeviceStateCollector`, `HealthKitCollector`
- Purpose: Decouple persistence implementation from feature code; enables in-memory fallbacks for tests
- Examples: `ios/ToDay/ToDay/Data/MoodRecordStoring.swift`, `ios/ToDay/ToDay/Data/EchoItemStoring.swift`
- Pattern: Protocol declared in `Data/`, SwiftData implementation (`SwiftDataXxxStore`) implemented inline in same file
- Purpose: Abstracts AI backend (local vs. cloud)
- Examples: `ios/ToDay/ToDay/Data/AI/EchoAIProviding.swift`
- Implementations: `AppleLocalAIProvider` (free), `DeepSeekAIProvider` (pro); `EchoAIService` routes between them
- Purpose: Universal timeline entry — whether from sensor inference, manual mood record, shutter capture, or spending log
- Location: `ios/ToDay/ToDay/Shared/SharedDataTypes.swift`
- Pattern: Identified by SHA256-derived stable UUID from (kind, startDate, endDate, displayName); supports fluent copying (`withInterval`, `withMetrics`, `applyingAnnotation`)
## Entry Points
- Location: `ios/ToDay/ToDay/App/ToDayApp.swift`
- Triggers: iOS launches the app
- Responsibilities: Creates root ViewModels via `AppContainer`, injects `modelContainer`, starts sensor monitoring and Echo scheduler on `.task`, schedules background tasks on scene phase change
- Location: `ios/ToDay/ToDay/App/AppRootScreen.swift`
- Triggers: Rendered by `ToDayApp`
- Responsibilities: Onboarding gate (`@AppStorage("today.hasCompletedOnboarding")`), 5-tab layout (History, Shutter, center + button, Echo, Settings), center record button intercept via `Binding<AppTab>`
- Location: `ios/ToDay/ToDay/Data/BackgroundTaskManager.swift`
- Triggers: `BGTaskScheduler` fires `com.looanli.today.refresh` or `com.looanli.today.processing`
- Responsibilities: Timeline generation for today (refresh) or backfill of past 7 days (processing); sensor data purge (keep 30 days)
## Error Handling
- `PhoneTimelineDataProvider` catches per-collector failures and continues with remaining collectors
- `TodayViewModel.load()` catches timeline provider errors with a fallback empty `DayTimeline`, allowing manual records to still appear
- SwiftData disk-cache failures are caught and printed; non-critical
- `EchoAIService` throws `EchoAIError.providerUnavailable` when no provider is available; UI shows a recoverable error state
## Cross-Cutting Concerns
<!-- GSD:architecture-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd:quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd:debug` for investigation and bug fixing
- `/gsd:execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd:profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
