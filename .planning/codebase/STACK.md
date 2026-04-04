# Technology Stack

**Analysis Date:** 2026-04-04

## Languages

**Primary:**
- Swift 5.0 — All iOS app logic, UI, and data layers (`ios/ToDay/ToDay/`)
- TypeScript — Abandoned web companion (`web/src/components/`) — not actively developed

**Secondary:**
- ArkTS / ArkUI — HarmonyOS companion port (`harmonyos/ToDay/`) — appears to be a parallel experiment, not the main codebase

## Runtime

**Environment:**
- iOS 17.0+ deployment target (set in `ios/ToDay/project.yml`)
- Apple Foundation Models (`FoundationModels`) targeted for iOS 26+ — guarded behind `#available(iOS 26, *)` in `AppleLocalAIProvider.swift`

**Package Manager:**
- No third-party Swift Package Manager dependencies — zero external packages
- XcodeGen 2.45.0+ to generate `.xcodeproj` from `ios/ToDay/project.yml`

## Frameworks

**Core UI:**
- SwiftUI — All screens and views
- UIKit — Used directly for sharing (`ScrollShareService.swift`), camera (`CameraPickerView.swift`), photo loading, and bridging

**Data Persistence:**
- SwiftData — Primary local store; all entities use `@Model` macros
  - Config: `ios/ToDay/ToDay/App/AppContainer.swift` (`makeModelContainer()`)
  - 13 registered models: `MoodRecordEntity`, `DayTimelineEntity`, `ShutterRecordEntity`, `SpendingRecordEntity`, `ScreenTimeRecordEntity`, `EchoItemEntity`, `UserProfileEntity`, `DailySummaryEntity`, `ConversationMemoryEntity`, `EchoChatSessionEntity`, `EchoChatMessageEntity`, `EchoMessageEntity`, `SensorReadingEntity`

**Sensor Collection:**
- CoreLocation — GPS visits + significant location changes (`LocationCollector.swift`)
- CoreMotion — Activity recognition + step counting (`MotionCollector.swift`, `PedometerCollector.swift`)

**Health:**
- HealthKit — Heart rate, step count, active energy, sleep analysis, workouts (`HealthKitCollector.swift`)
  - Entitlement: `com.apple.developer.healthkit` in `ToDay.entitlements`

**Weather:**
- WeatherKit — Hourly weather overlay for timeline events (`WeatherService.swift`)
  - Entitlement: `com.apple.developer.weatherkit` in `ToDay.entitlements`

**Watch Connectivity:**
- WatchConnectivity — Bidirectional sync with Apple Watch app (`ConnectivityManager.swift`)
  - App group: `group.com.looanli.today`

**Media:**
- Photos / PhotosUI — Photo library access for daily photo matching (`PhotoService.swift`)
- AVFoundation — Voice recording (`VoiceRecordView.swift`)
- Speech — On-device speech recognition for voice-to-text transcription (`VoiceRecordView.swift`)

**Background:**
- BackgroundTasks — BGAppRefreshTask + BGProcessingTask for passive timeline generation (`BackgroundTaskManager.swift`)
  - Task IDs: `com.looanli.today.refresh`, `com.looanli.today.processing`

**Charting:**
- Charts (Apple native) — Heart rate and event metrics visualization (`EventDetailView.swift`)

**Notifications:**
- UserNotifications — Local notification scheduling for Echo AI reminders (`EchoEngine.swift`)

**Testing:**
- XCTest — Unit test framework (`ios/ToDay/ToDayTests/`)

**Cryptography:**
- CryptoKit — SHA-256 for deterministic event ID derivation from content hash (`SharedDataTypes.swift`)

## Key Dependencies

**No third-party packages.** The entire stack uses Apple system frameworks exclusively.

## Configuration

**Build:**
- `ios/ToDay/project.yml` — XcodeGen spec; run `xcodegen generate` to regenerate `.xcodeproj`
- Bundle ID: `com.looanli.today`
- Version: 0.3.0 (marketing), build 3
- Development Team: `G89F57S8M3`

**Environment Flags:**
- `TODAY_USE_MOCK=1` — Forces MockTimelineDataProvider regardless of device type
- Simulator auto-detects and uses MockTimelineDataProvider (`#if targetEnvironment(simulator)`)

**Permissions Required (Info.plist keys in `project.yml`):**
- `NSHealthShareUsageDescription` — HealthKit read access
- `NSLocationAlwaysAndWhenInUseUsageDescription` — Background location
- `NSPhotoLibraryUsageDescription` — Photo library read
- `NSCameraUsageDescription` — Camera capture
- `NSMicrophoneUsageDescription` — Voice recording
- `NSSpeechRecognitionUsageDescription` — On-device speech transcription
- `NSMotionUsageDescription` — CoreMotion activity

**Background Modes:**
- `fetch` — App refresh background task
- `processing` — BGProcessingTask for backfill

## Platform Requirements

**Development:**
- Xcode (supports iOS 26 SDK for FoundationModels — currently placeholder)
- XcodeGen 2.45.0+
- macOS host

**Production:**
- iPhone only (`TARGETED_DEVICE_FAMILY: 1`)
- iOS 17.0+ minimum
- Apple Watch companion app (source not in this repo — Watch target uses WatchConnectivity)

---

*Stack analysis: 2026-04-04*
