# External Integrations

**Analysis Date:** 2026-04-04

## APIs & External Services

**AI - Pro Tier:**
- DeepSeek API — Chat completions for Echo AI companion
  - Endpoint: `https://api.deepseek.com/chat/completions`
  - Model: `deepseek-chat`
  - Auth: Bearer token — user-configurable via Settings, falls back to a hardcoded default key
  - UserDefaults key: `today.echo.deepseekAPIKey`
  - Client: `ios/ToDay/ToDay/Data/AI/DeepSeekAIProvider.swift` (raw URLSession, no SDK)
  - Timeout: 30 seconds, max_tokens: 1024

**AI - Free Tier:**
- Apple Foundation Models (iOS 26+) — On-device LLM via `FoundationModels` framework
  - Status: Placeholder implementation — `FoundationModels` SDK not yet available
  - Availability gated with `#available(iOS 26, *)`
  - Client: `ios/ToDay/ToDay/Data/AI/AppleLocalAIProvider.swift`

**Geocoding:**
- Apple CLGeocoder — Reverse geocoding for unnamed place labels
  - No API key required (Apple platform entitlement)
  - Rate-limited: one place resolved per invocation cycle
  - Client: `ios/ToDay/ToDay/Data/Sensors/PlaceManager.swift`

## Data Storage

**Databases:**
- SwiftData (SQLite) — All persistent data, local-only, no cloud sync
  - Container initialized in: `ios/ToDay/ToDay/App/AppContainer.swift`
  - Store location: Default SwiftData directory (app sandbox)
  - Shared between iPhone app and Watch app via `UserDefaults(suiteName:)` app group for lightweight snapshots; full SwiftData store is iPhone-only
  - App group identifier: `group.com.looanli.today`

**Key storage breakdown:**
- `MoodRecordEntity` — Manual mood + session records
- `DayTimelineEntity` — Persisted daily timelines (generated and cached)
- `ShutterRecordEntity` — Photo/text/voice life moments ("Shutter" feature)
- `SpendingRecordEntity` — Manual spending entries
- `ScreenTimeRecordEntity` — Manual screen time input
- `EchoItemEntity` — Echo reminder scheduling records
- `EchoMessageEntity` — AI-generated insight messages for Echo feed
- `EchoChatSessionEntity` / `EchoChatMessageEntity` — Chat history with Echo AI
- `UserProfileEntity` — AI-generated weekly user portrait
- `DailySummaryEntity` — AI-generated daily summaries (7-day rolling context)
- `ConversationMemoryEntity` — Compressed conversation history for Echo memory
- `SensorReadingEntity` — Raw sensor readings (30-day retention, auto-purged)

**Legacy Migration:**
- UserDefaults key `today.manualRecords` — old MoodRecord store; migrated to SwiftData on first launch
  - Migration logic: `ios/ToDay/ToDay/App/AppContainer.swift` `migrateLegacyMoodRecordsIfNeeded()`

**File Storage:**
- Local app sandbox only — no cloud file storage
- Photos referenced by PHAsset local identifiers (not copied)
- Voice recordings stored locally via AVFoundation

**Caching:**
- No explicit cache layer beyond SwiftData persistence
- Sensor readings purged after 30 days via `SensorDataStore.purge(olderThan:)`

## Authentication & Identity

**Auth Provider:**
- None — fully local-first, no user account or server auth
- DeepSeek API key stored in UserDefaults (not Keychain) — `today.echo.deepseekAPIKey`
- User tier stored in UserDefaults — `today.echo.userTier` (`free` / `pro`)

## Apple Platform Integrations

**HealthKit:**
- Read-only access to: heart rate, step count, active energy burned, sleep analysis, workouts
- Entitlement: `com.apple.developer.healthkit`
- Client: `ios/ToDay/ToDay/Data/Sensors/HealthKitCollector.swift`
- Authorization: `HealthAuthorizationGate` actor prevents duplicate auth prompts

**WeatherKit:**
- Hourly weather data for the current day and location
- Entitlement: `com.apple.developer.weatherkit`
- Client: `ios/ToDay/ToDay/Data/WeatherService.swift`
- Requires physical device (not available in Simulator)

**CoreLocation:**
- `startMonitoringSignificantLocationChanges()` — battery-efficient passive tracking
- `startMonitoringVisits()` — arrival/departure detection at places
- Authorization level requested: `.authorizedAlways` (required for background)
- Client: `ios/ToDay/ToDay/Data/Sensors/LocationCollector.swift`

**CoreMotion:**
- `CMMotionActivityManager` — stationary/walking/running/cycling/automotive classification
- `CMPedometer` — hourly step counts and distance
- Clients: `ios/ToDay/ToDay/Data/Sensors/MotionCollector.swift`, `PedometerCollector.swift`

**Photos:**
- PHPhotoLibrary — fetches photos taken on a given day with creation date + GPS metadata
- Client: `ios/ToDay/ToDay/Data/PhotoService.swift`

**Speech Framework:**
- On-device speech recognition for voice memos
- Client: `ios/ToDay/ToDay/Features/Shutter/VoiceRecordView.swift`

**WatchConnectivity:**
- Bidirectional sync between iPhone and Apple Watch companion
- Uses `WCSession.sendMessage` (realtime) with `transferUserInfo` fallback (queued delivery)
- Shared state via `UserDefaults(suiteName: "group.com.looanli.today")`
- Shared keys: `currentEventSnapshotKey`, `watchTimelineSnapshotKey`, `dailySummaryKey`
- iPhone side: `PhoneConnectivityManager` in `ios/ToDay/ToDay/Shared/ConnectivityManager.swift`
- Watch side: `WatchConnectivityManager` in same file (compiled conditionally with `#if os(watchOS)`)

**UserNotifications:**
- Local notifications only — no push/APNs
- Used for Echo AI reminder scheduling ("回响" — memory echo notifications)
- Category: `ECHO_REMINDER`
- Client: `ios/ToDay/ToDay/Data/EchoEngine.swift`

**BackgroundTasks:**
- `BGAppRefreshTask` (`com.looanli.today.refresh`) — lightweight, ~every 1 hour
- `BGProcessingTask` (`com.looanli.today.processing`) — heavier, runs overnight, backfills 7 days
- Client: `ios/ToDay/ToDay/Data/BackgroundTaskManager.swift`

## Monitoring & Observability

**Error Tracking:**
- None — no crash reporting or analytics SDK

**Logs:**
- `print()` statements with `[BGTask]`, `[EchoEngine]` prefixes — console only

## CI/CD & Deployment

**Hosting:**
- Static web presence: `https://looanli08-hl.github.io/ToDay/` (GitHub Pages)
  - Privacy policy, terms of service, and marketing landing pages

**CI Pipeline:**
- None detected

**App Distribution:**
- Manual Xcode build; no TestFlight or App Store automation pipeline detected

## Environment Configuration

**Required Apple Developer entitlements:**
- `com.apple.developer.healthkit`
- `com.apple.developer.weatherkit`
- App group: `group.com.looanli.today`

**User-configurable at runtime:**
- DeepSeek API key: UserDefaults `today.echo.deepseekAPIKey`
- User tier (free/pro): UserDefaults `today.echo.userTier`

**No external env vars or `.env` files in the iOS project.**

## Webhooks & Callbacks

**Incoming:**
- None — no server, no webhooks

**Outgoing:**
- DeepSeek API only (HTTPS POST to `https://api.deepseek.com/chat/completions`)

---

*Integration audit: 2026-04-04*
