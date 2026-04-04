# Codebase Concerns

**Analysis Date:** 2026-04-04

---

## Critical: Hardcoded API Key in Source

**DeepSeek API key committed to source code:**
- Issue: A live DeepSeek API key (`sk-REDACTED`) is hardcoded as `defaultAPIKey` in `ios/ToDay/ToDay/Data/AI/DeepSeekAIProvider.swift` line 18. It will be bundled into every release binary and is trivially extractable with `strings` on the compiled app.
- Files: `ios/ToDay/ToDay/Data/AI/DeepSeekAIProvider.swift`
- Impact: Unlimited API cost exposure. The key is publicly accessible to anyone who downloads the app.
- Fix approach: Remove `defaultAPIKey` entirely. Require users to supply their own key via Settings. Consider a backend proxy if you want to absorb API costs without exposing credentials.

---

## Tech Debt

**Mock providers ship in production simulator builds:**
- Issue: `AppContainer.makeTimelineProvider()` returns `MockTimelineDataProvider()` unconditionally when running in the simulator (`#if targetEnvironment(simulator)`). The mock also fires when the env var `TODAY_USE_MOCK=1` is set. This means any iPhone running in a simulator (e.g. CI, TestFlight simulator builds) gets fake data forever, making real end-to-end testing on simulator impossible.
- Files: `ios/ToDay/ToDay/App/AppContainer.swift` (lines 82–96), `ios/ToDay/ToDay/Data/MockTimelineDataProvider.swift`
- Impact: Timeline never shows real sensor data in simulator; QA can only validate real behavior on physical device.
- Fix approach: Allow overriding via launch argument or test flag only. Remove the unconditional `#if targetEnvironment(simulator)` fallback or replace it with a clearly labeled debug flag.

**Echo/AI/Watch infrastructure enabled despite being MVP-excluded:**
- Issue: Per `CLAUDE.md`, the MVP explicitly excludes AI/Echo, screen-time auto-collection, and Apple Watch. However, the following are fully wired in production code: `EchoScheduler`, `EchoAIService`, `EchoDailySummaryGenerator`, `EchoWeeklyProfileUpdater`, `EchoMemoryManager`, `EchoPromptBuilder`, `PhoneConnectivityManager`, `WatchSyncHelper`, `ConnectivityManager`, `CareNudgeEngine`. All are instantiated at app startup in `AppContainer` and execute on every app launch and background cycle.
- Files: `ios/ToDay/ToDay/App/AppContainer.swift`, `ios/ToDay/ToDay/App/ToDayApp.swift`, `ios/ToDay/ToDay/Data/EchoEngine.swift`, `ios/ToDay/ToDay/Shared/ConnectivityManager.swift`, `ios/ToDay/ToDay/Data/WatchSyncHelper.swift`
- Impact: Increased startup time, battery drain from background scheduling, cognitive overhead when navigating code, risk of unintended DeepSeek API calls from any user who sets their tier to `.pro`.
- Fix approach: Gate the entire Echo/Watch stack behind a compile-time flag or disable at startup until the MVP core is stable.

**`AnnotationStore` uses UserDefaults for persistent data:**
- Issue: Event annotations are stored as JSON in `UserDefaults` (shared app group). There is no size limit enforcement. If a user accumulates hundreds of annotations over months, the defaults payload grows unboundedly.
- Files: `ios/ToDay/ToDay/Data/AnnotationStore.swift`
- Impact: Large defaults payloads can slow app launch and iCloud sync (if enabled later).
- Fix approach: Migrate annotations to SwiftData alongside other record types.

**`PlaceManager` uses UserDefaults for core location data:**
- Issue: All known places (home, work, frequent) are stored as a single JSON blob in `UserDefaults`. There is no size limit. The read/write pattern (decode entire array → mutate → re-encode) is O(N) per visit record and becomes slow with many places.
- Files: `ios/ToDay/ToDay/Data/Sensors/PlaceManager.swift`
- Impact: Performance degrades with large place lists. Concurrent writes (background vs. foreground) could corrupt data since UserDefaults is not thread-safe under all conditions.
- Fix approach: Move `KnownPlace` to SwiftData. The `SensorDataStore` already exists as the right pattern.

**`SensorDataStore` allocates a new `DateFormatter` per call:**
- Issue: `dateKey(from:)` (line 114) and `SensorReadingEntity.makeDateKey(from:)` (line 45) each allocate a fresh `DateFormatter` every invocation. `DateFormatter` is expensive to construct (locale loading, timezone resolution). The same pattern appears in at least 30 other files: `EchoScheduler`, `EchoMemoryManager`, `EchoPromptBuilder`, `HistoryScreen`, `DashboardViewModel`, `TodayInsightComposer`, `ShutterAlbumScreen`, etc.
- Files: `ios/ToDay/ToDay/Data/Sensors/SensorDataStore.swift` (×2), `ios/ToDay/ToDay/Data/DayTimelineEntity.swift`, `ios/ToDay/ToDay/Data/AI/EchoScheduler.swift` (×3), and ~20 more
- Impact: Hot paths like `SensorDataStore.save()` and `SensorDataStore.readings(for:)` are called on every sensor reading and every timeline load. The allocation overhead accumulates.
- Fix approach: Make all formatters `static let` constants or use `ISO8601DateFormatter` where only date strings are needed.

**`PedometerCollector` makes 24 serial network-like calls per day load:**
- Issue: `collectData(for:)` queries `CMPedometer` in 24 separate 1-hour segments using a `for` loop with `try? await`. Each segment is a system call. For a day that is already loaded, this generates 24 redundant calls every time `PhoneTimelineDataProvider.loadTimeline(for:)` is invoked (which happens on every foreground transition).
- Files: `ios/ToDay/ToDay/Data/Sensors/PedometerCollector.swift`, `ios/ToDay/ToDay/Data/Sensors/PhoneTimelineDataProvider.swift`
- Impact: Each foreground wake triggers up to 24 pedometer queries. Multiplied across frequent users, this drains battery and adds latency to timeline display.
- Fix approach: Cache pedometer results in `SensorDataStore` per-hour segment with deduplication (already done for location — same pattern needed here). Only query hours that are not yet stored.

**`BackgroundTaskManager` creates fresh `AppContainer.makeTimelineProvider()` on every background run:**
- Issue: `generateTodayTimeline()` and `backfillRecentTimelines()` both call `AppContainer.makeTimelineProvider()`, which in turn runs `#if targetEnvironment(simulator)` and returns a mock — so background tasks on simulator produce mock data written to the real SwiftData store. On device, a new `PhoneTimelineDataProvider` (with its own collector stack) is instantiated each time instead of reusing the shared singleton.
- Files: `ios/ToDay/ToDay/Data/BackgroundTaskManager.swift` (lines 109, 125)
- Impact: Background tasks on simulator corrupt the store with mock data. On device, the background provider and foreground provider are different objects with no shared state, so background results may duplicate or conflict with foreground readings.
- Fix approach: Expose a single `AppContainer.sharedTimelineProvider` and reuse it everywhere.

---

## Known Bugs

**Sleep inference can produce events with `endDate` 24 hours in the future:**
- Symptoms: When a night-sleep lock event (after 20:00) finds no subsequent unlock, the engine searches for a "morning unlock" that occurred earlier in the same calendar day (i.e., earlier in the readings array). If found, it adds 24 hours to create `endDate = wake + 86400s`. If this logic fires incorrectly (e.g., readings arrive out of order or from different days), the timeline entry will show a sleep block spanning 24+ hours.
- Files: `ios/ToDay/ToDay/Data/Sensors/PhoneInferenceEngine.swift` (lines 121–143)
- Trigger: Any day where device lock events are stored out of chronological order, or when the previous day's morning wake reading is included in the current day's readings.
- Workaround: None. The timeline will display a malformed event.

**Location monitoring silently falls back to `authorizedWhenInUse` instead of `Always`:**
- Symptoms: `LocationCollector.locationManagerDidChangeAuthorization` starts monitoring when status is either `.authorizedAlways` OR `.authorizedWhenInUse`. However, significant location changes and visit monitoring require `Always` authorization. With `whenInUse` only, `startMonitoringSignificantLocationChanges()` and `startMonitoringVisits()` are no-ops on most iOS versions, so the timeline never fills with location data.
- Files: `ios/ToDay/ToDay/Data/Sensors/LocationCollector.swift` (lines 90–94)
- Trigger: User grants "While Using" instead of "Always" during onboarding.
- Workaround: None visible to the user. The timeline appears empty without explanation.

**`PlaceManager.reclassifyPlaces()` can demote home/work incorrectly:**
- Symptoms: Home is determined by highest total duration; work by highest visit count among non-home candidates. If a user spends a long weekend at a hotel, the hotel becomes "home." Neither heuristic accounts for time-of-day patterns (sleeping hours for home vs. working hours for work).
- Files: `ios/ToDay/ToDay/Data/Sensors/PlaceManager.swift` (lines 80–105)
- Trigger: Any extended stay at an unusual location.
- Workaround: User can manually rename places in Settings (though this UI is not yet confirmed to exist in MVP).

**`handleAppRefresh` and `handleProcessing` do not propagate task cancellation correctly:**
- Symptoms: The `workTask` is created inside `handleAppRefresh`. The `expirationHandler` cancels it. However, the second `Task { await workTask.value; task.setTaskCompleted(...) }` is not itself cancelled when the expiration fires. If the system kills the task before the completion handler runs, `task.setTaskCompleted(success:)` is never called, which causes iOS to deprioritize future background refreshes.
- Files: `ios/ToDay/ToDay/Data/BackgroundTaskManager.swift` (lines 69–103)
- Trigger: System aggressively terminates background task before it completes.

---

## Security Considerations

**DeepSeek API key in binary:**
- Risk: As noted above, the API key is embedded in the shipped binary. Any user can extract it.
- Files: `ios/ToDay/ToDay/Data/AI/DeepSeekAIProvider.swift` line 18
- Current mitigation: None.
- Recommendations: Remove the hardcoded key immediately. If a shared key is needed, route through a server-side proxy that enforces per-user rate limits.

**Location data stored without encryption:**
- Risk: `SensorReadingEntity` stores raw GPS coordinates (latitude, longitude) as `Data` in a SwiftData SQLite file in the app's documents directory. The file is not encrypted at rest unless the device has Data Protection enabled (the app does not explicitly set `NSFileProtectionComplete`).
- Files: `ios/ToDay/ToDay/Data/Sensors/SensorDataStore.swift`, `project.yml` (no `DATA_PROTECTION_CLASS` set)
- Current mitigation: "Always on device" privacy promise in UI copy.
- Recommendations: Add `com.apple.developer.default-data-protection` entitlement set to `NSFileProtectionComplete` or `NSFileProtectionCompleteUntilFirstUserAuthentication`.

**UserDefaults stores sensitive data (API tier, personality):**
- Risk: App settings including `today.echo.deepseekAPIKey`, `today.echo.userTier`, and `today.echo.personality` are stored in `UserDefaults.standard` and can be read by other apps in a jailbroken environment or via iCloud backup if not excluded.
- Files: `ios/ToDay/ToDay/Data/AI/EchoAIService.swift`, `ios/ToDay/ToDay/Data/AI/DeepSeekAIProvider.swift`
- Current mitigation: None.
- Recommendations: Move the user-supplied API key to Keychain. Other preference keys in UserDefaults are acceptable.

---

## Performance Bottlenecks

**`PhoneTimelineDataProvider.loadTimeline(for:)` called on every foreground transition:**
- Problem: `ToDayApp` triggers `viewModel.load(forceReload: true)` in `.onChange(of: scenePhase) { .active }` and also subscribes to `UIApplication.willEnterForegroundNotification` in `TodayScreen`. These two triggers fire on every foreground wake and together cause a full timeline rebuild including all collector queries.
- Files: `ios/ToDay/ToDay/App/ToDayApp.swift` (line 50), `ios/ToDay/ToDay/Features/Today/TodayScreen.swift` (line 49)
- Cause: Duplicate reload triggers without debounce.
- Improvement path: Remove the `NotificationCenter` observer from `TodayScreen` (it duplicates the scene phase handler). Add a minimum reload interval (e.g., 5 minutes) before forcing a full provider refresh.

**`rebuildTimeline` is called synchronously on every user action:**
- Problem: Every mood record, shutter save, spending entry, annotation, and screen-time update calls `rebuildTimeline(referenceDate:)`, which synchronously iterates all records, all shutter entries, all annotations, all spending records, all screen time records, and then calls `refreshDerivedState` which rebuilds weekly insights and history digests.
- Files: `ios/ToDay/ToDay/Features/Today/TodayViewModel.swift` (multiple call sites)
- Cause: No debounce or background queue for timeline assembly.
- Improvement path: Debounce rapid successive mutations by 200ms. Move heavy derivation (`buildWeeklyInsight`, `buildHistoryDigests`) off the critical path.

**`SensorDataStore.save()` does a full fetch per reading to deduplicate:**
- Problem: For each `SensorReading` in a batch, a separate `FetchDescriptor` is executed against SwiftData to check for an existing record with the same UUID. With 24 pedometer segments + location events + device events, a single timeline load can trigger 30–50 individual fetch operations in a transaction.
- Files: `ios/ToDay/ToDay/Data/Sensors/SensorDataStore.swift` (lines 63–76)
- Cause: Per-item deduplication instead of batch upsert.
- Improvement path: Fetch all existing UUIDs for the date range in a single query, compute the diff in memory, then batch insert only new readings.

---

## Fragile Areas

**`AppContainer` is a static enum with eager initialization:**
- Files: `ios/ToDay/ToDay/App/AppContainer.swift`
- Why fragile: All stores, collectors, and AI services are initialized as `static let` properties the moment any property of `AppContainer` is first accessed. The `fatalError` in `makeModelContainer()` means any schema mismatch during development instantly crashes the app on launch with no recovery path. Adding new `@Model` types without a migration plan will crash existing installs.
- Safe modification: Always provide a `VersionedSchema` and `SchemaMigrationPlan` before adding or removing `@Model` properties. Test migration paths on a device with existing data.
- Test coverage: Migration is tested via `migrateLegacyMoodRecordsIfNeeded` only for MoodRecords. No tests exist for schema migration failure scenarios.

**`PhoneInferenceEngine` has no tests for edge cases in real sensor data:**
- Files: `ios/ToDay/ToDayTests/PhoneInferenceEngineTests.swift`, `ios/ToDay/ToDay/Data/Sensors/PhoneInferenceEngine.swift`
- Why fragile: The engine uses hardcoded thresholds (`sleepMinGapHours = 2h`, `visitMinStay = 5m`, `placeMatchRadius = 200m`) that were tuned for ideal conditions. Real CMMotion data contains gaps, duplicate timestamps, and misclassifications. The `isOverlapping` check uses `DateInterval.intersects` which fires even for touching intervals (e.g., a 1-second overlap).
- Safe modification: Add property-based tests with fuzz inputs before changing any threshold. Add integration tests using recorded real sensor sessions.
- Test coverage: Existing tests use synthetic data only. No test covers cross-midnight sleep, back-to-back commutes, or zero-reading days.

**`EchoScheduler` has a circular dependency resolved at runtime:**
- Files: `ios/ToDay/ToDay/Data/AI/EchoScheduler.swift`, `ios/ToDay/ToDay/App/AppContainer.swift`
- Why fragile: `EchoScheduler` is initialized without a `EchoMessageManager` reference. `setMessageManager(_:)` is called later in `AppContainer.echoMessageManager` lazy initialization. If any code path invokes `EchoScheduler` methods before `echoMessageManager` is accessed, the scheduler silently does nothing (the `messageManager` optional is nil).
- Safe modification: Resolve the circular dependency architecturally (e.g., pass a closure or use a delegate pattern) instead of relying on call-order side effects.

**`ConnectivityManager` / `WatchSyncHelper` remain active with no Watch:**
- Files: `ios/ToDay/ToDay/Shared/ConnectivityManager.swift`, `ios/ToDay/ToDay/Data/WatchSyncHelper.swift`, `ios/ToDay/ToDay/App/AppContainer.swift`
- Why fragile: `PhoneConnectivityManager` activates a `WCSession` on every launch regardless of whether a Watch is paired. The `WatchSyncHelper.sync()` is called from `rebuildTimeline` on every timeline update, even when `connectivityManager` is nil. The `SharedAppGroup` identifier (`group.com.looanli.today`) is used in multiple stores — a misconfigured entitlement will silently cause annotation data loss.
- Safe modification: Guard all WatchConnectivity code behind an explicit `isWatchPaired` check before performing any operations.

---

## Test Coverage Gaps

**Integration test for `PhoneTimelineDataProvider` does not exist:**
- What's not tested: The full pipeline — collectors → `SensorDataStore.save()` → `PhoneInferenceEngine.inferEvents()` → timeline assembly — is never tested end-to-end. Only individual units are tested in isolation.
- Files: `ios/ToDay/ToDayTests/PhoneTimelineDataProviderTests.swift`
- Risk: A regression in data flow between layers (e.g., a date key mismatch) would go undetected until a user reports an empty timeline.
- Priority: High

**`PlaceManager` classification heuristics have no adversarial tests:**
- What's not tested: Home/work misclassification scenarios (hotel stay, travel, first-week usage with sparse data). `resolveUnnamedPlaces` is untested for geocoder failures and rate limiting.
- Files: `ios/ToDay/ToDayTests/PlaceManagerTests.swift`, `ios/ToDay/ToDay/Data/Sensors/PlaceManager.swift`
- Risk: Silent misclassification corrupts place labels permanently since `isConfirmedByUser` stays false.
- Priority: High

**`BackgroundTaskManager` has zero tests:**
- What's not tested: Task registration, scheduling, expiration handling, backfill logic, and the `purge(olderThan:)` path.
- Files: `ios/ToDay/ToDay/Data/BackgroundTaskManager.swift`
- Risk: Background recording (the core MVP feature) has no safety net. A regression in `handleAppRefresh` would silently stop all passive recording.
- Priority: High

**`DeviceStateCollector` screen lock/unlock detection is untested with real notifications:**
- What's not tested: `protectedDataDidBecomeAvailableNotification` and `protectedDataWillBecomeUnavailableNotification` are not the same as screen lock/unlock in all scenarios (e.g., Face ID failure, low-power mode). The tests mock the notification directly but do not cover false positive scenarios.
- Files: `ios/ToDay/ToDayTests/DeviceStateCollectorTests.swift`, `ios/ToDay/ToDay/Data/Sensors/DeviceStateCollector.swift`
- Risk: Sleep inference (which depends entirely on device state events) produces incorrect results on devices where protected data notifications fire for non-sleep reasons.
- Priority: Medium

**`AppleLocalAIProvider` is a stub with no real implementation:**
- What's not tested: The entire iOS 26 FoundationModels path is a placeholder returning hardcoded strings. There are no tests because there is no real implementation.
- Files: `ios/ToDay/ToDay/Data/AI/AppleLocalAIProvider.swift`
- Risk: Free-tier users (non-pro) on iOS 26+ will receive dummy AI responses. The `TODO` comments explicitly call this out but there is no tracking mechanism.
- Priority: Medium (blocks Echo feature, not MVP)

---

## Scaling Limits

**`timelineCache` in `TodayViewModel` is unbounded by date range:**
- Current capacity: `maxCachedTimelines = 30` entries (in-memory)
- Limit: With 30 cached timelines, each containing potentially hundreds of sensor readings serialized as `[InferredEvent]`, memory use can reach several MB for power users.
- Scaling path: Already has eviction logic. No issue for MVP; revisit if memory warnings appear.

**`SensorDataStore.purge(olderThan: 30)` runs in background task only:**
- Current capacity: Unbounded during the first 30 days; purge runs only in `backfillRecentTimelines()`.
- Limit: If background tasks never execute (iOS can suppress them for weeks on low-battery devices), sensor readings accumulate indefinitely. A heavy user generating thousands of readings per day could cause SwiftData query slowdowns.
- Scaling path: Add a lightweight foreground purge check on app launch, capped to a fast predicate query.

---

## Dependencies at Risk

**`WeatherKit` entitlement required but feature not wired to MVP:**
- Risk: `project.yml` includes `com.apple.developer.weatherkit` in entitlements and `WeatherService.swift` exists. WeatherKit requires an active Apple Developer Program membership with the WeatherKit capability registered, or all fetches fail silently. The service is not currently called from any active code path (no reference in `AppContainer`), but the entitlement is still included.
- Impact: No current runtime impact, but the dangling entitlement adds confusion and an unnecessary App Review surface.
- Migration plan: Remove the WeatherKit entitlement from `project.yml` until the feature is actively used.

**`AppleLocalAIProvider` targets iOS 26 which does not exist yet (as of April 2026):**
- Risk: The provider is gated on `#available(iOS 26, *)`. iOS 26 has not shipped. All code paths inside the `@available` block are completely untested placeholder strings. When iOS 26 ships, the `FoundationModels` import and actual API will need to be wired before the provider does anything useful.
- Impact: Free-tier AI is entirely non-functional today.
- Migration plan: Track Apple's WWDC announcements and SDK betas. Wire the real API in a dedicated branch before iOS 26 GM.

---

*Concerns audit: 2026-04-04*
