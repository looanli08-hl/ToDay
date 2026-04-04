# Domain Pitfalls: iOS Auto Life-Tracking + AI

**Domain:** iOS passive life-tracking app with AI insight layer  
**Project:** Unfold (brownfield — existing sensor pipeline, adding AI)  
**Researched:** 2026-04-04  
**Confidence:** HIGH for CoreLocation/BGTask/API security; MEDIUM for on-device ML limitations; MEDIUM for App Store review specifics

---

## Critical Pitfalls

Mistakes that cause rewrites, App Store rejection, or unrecoverable data loss.

---

### Pitfall 1: Hardcoded API Key in Source Code (ACTIVE — already present)

**What goes wrong:** A live DeepSeek API key is embedded in `DeepSeekAIProvider.swift` line 18 as `private static let defaultAPIKey = "sk-94d311f460e54b4cac9c216ed8d5af36"`. Once committed to any repo or distributed in the app binary, the key is trivially extractable via strings tools or decompilation. This leads to unauthorized charges and key revocation.

**Why it happens:** Convenience during early development. The key was added as a "built-in default so users don't need to configure it" — a pattern that sounds user-friendly but is fundamentally insecure at distribution.

**Consequences:**
- API key extracted from app binary within hours of public release
- Billing liability: attacker runs unlimited inference against the key
- Key revocation causes AI features to silently fail for all users
- App Store review may flag hardcoded secrets discovered via static analysis

**Prevention:**
- Remove `defaultAPIKey` constant entirely before any TestFlight or public distribution
- Require users to enter their own key OR route all requests through a backend proxy that holds the key server-side
- For MVP with own key: use a lightweight proxy (e.g., a single Cloudflare Worker or Vercel Edge Function) that authenticates users and forwards to DeepSeek, never exposing the raw key client-side
- Never commit API keys to git; use `.xcconfig` files excluded from version control if needed for local dev

**Warning signs:**
- `grep -r "sk-"` or `grep -r "defaultAPIKey"` finds a live key in source
- AI feature "just works" on a fresh install without any user configuration step

**Phase:** Address in Phase 1 (AI integration) before any external distribution.

---

### Pitfall 2: App Store Rejection for "Always Location" Without Demonstrated Necessity

**What goes wrong:** Apple's reviewers require that apps requesting `NSLocationAlwaysAndWhenInUseUsageDescription` demonstrate a clear, in-app user benefit that requires background location. Passive life-tracking is a valid use case, but the reviewer must be able to verify it without guessing. Apps that request Always authorization but whose core features appear to work with When In Use — or whose usage strings are vague — get rejected under guideline 5.1.1.

**Why it happens:** Developers focus on the technical implementation and write a brief usage string like "To track your location." Reviewers cannot see why the app needs background access specifically. Onboarding never surfaces what the app does with Always access.

**Consequences:**
- Rejection adds 1-2 week delays per cycle
- Forced downgrade to When In Use breaks the passive recording value proposition entirely
- Multiple rejections can trigger extended review or guideline scrutiny

**Prevention:**
- Usage string must be specific: e.g., "Unfold passively records your location throughout the day to build your life timeline, even when the app is closed."
- Onboarding must visibly demonstrate the core loop: "Here's how your day looks when you grant Always access" (show the timeline populated with sample data)
- In App Review Notes, explicitly state: "This is a passive life-logging app. Always Location is required to record location visits while the app is in the background. The core feature (today's life timeline) only works with Always authorization."
- Ensure `NSLocationAlwaysAndWhenInUseUsageDescription` and `NSLocationWhenInUseUsageDescription` are both present in Info.plist
- Gracefully degrade: if user grants only When In Use, show a clear explanation of what they will miss, not a crash

**Warning signs:**
- Usage description string is under 20 words
- Onboarding grants location permission before showing the user any value from the app
- No App Review Notes filled in for the submission

**Phase:** Address in Onboarding phase (Phase 2 or whenever first TestFlight external build is submitted).

---

### Pitfall 3: Significant Location Changes Stops After User Force-Quit

**What goes wrong:** `startMonitoringSignificantLocationChanges()` does NOT relaunch a force-quit app on iOS. This is a documented but commonly misunderstood distinction: significant location changes will relaunch an app that was *suspended*, but not one the user actively force-quit. Visit monitoring has the same behavior. The current `LocationCollector` starts monitoring on `authorizedAlways` status change — which only fires when the app is running, not on system relaunch.

**Why it happens:** Apple's documentation implies the service "relaunches" the app, which is true only for system-terminated apps. User force-quit is treated as an explicit "do not run" signal.

**Consequences:**
- User force-quits the app once, passive recording stops entirely until they manually reopen it
- Data gaps appear in the timeline, making the core product feel broken
- No user-visible error; the app appears healthy when opened but has gaps from the force-quit period

**Prevention:**
- Cannot prevent force-quit data loss entirely — this is a platform limitation
- Mitigate with honest UI: show "Recording paused" or gap indicators in the timeline for periods with no data
- In onboarding, explain: "Don't force-quit Unfold — just leave it running in the background. iOS manages it automatically."
- Consider a silent push notification strategy as a fallback wakeup (requires server infrastructure)
- Do NOT promise "always-on 24/7 recording" in marketing copy

**Warning signs:**
- QA tests never include a force-quit scenario
- Timeline shows clean data every day but gaps are not explained to users

**Phase:** Address in Onboarding copy and timeline UI (wherever gap visualization is built).

---

### Pitfall 4: BGTaskScheduler Tasks Are Unreliable and Non-Deterministic

**What goes wrong:** The current `BackgroundTaskManager` schedules a refresh every 1 hour (`earliestBeginDate: Date(timeIntervalSinceNow: 60 * 60)`). iOS makes no guarantee about when — or whether — these tasks actually run. Low-battery mode, the device's learned usage patterns, the user's daily habits, and whether Background App Refresh is enabled all affect scheduling. In practice, the system may delay or skip tasks entirely.

The 30-second time budget for `BGAppRefreshTask` is also too short for timeline generation plus geocoding if there are many unprocessed sensor readings.

**Why it happens:** Developers test on a plugged-in, freshly-rebooted simulator or device where tasks run quickly. In the real world, iOS aggressively throttles background tasks to extend battery life.

**Consequences:**
- Users who check the app at end of day find a stale or empty timeline
- Geocoding calls fail silently inside background tasks with no user feedback
- `BGAppRefreshTask` 30-second budget exceeded → task marked failed → iOS further deprioritizes future tasks

**Prevention:**
- Do not rely on BGTask as the *only* path for timeline generation; generate the timeline on foreground app open as a synchronous operation first, then use BGTask for supplementary refresh
- Keep BGAppRefreshTask work under 10 seconds to leave headroom; defer geocoding to BGProcessingTask
- Add a "Last updated" timestamp in the UI so users can see if data is stale and pull-to-refresh manually
- Register tasks during app launch before the end of the launch sequence (already done correctly)
- Set `requiresExternalPower: false` on processing tasks to avoid over-constraining when they run

**Warning signs:**
- Timeline data source is BGTask-only with no foreground refresh path
- BGTask handler has no task budget tracking or early-exit logic
- No user-visible indicator of when timeline was last refreshed

**Phase:** Address when building the AI daily summary (which depends on fresh timeline data).

---

## Moderate Pitfalls

---

### Pitfall 5: AI API Cost Runaway on Free User Base

**What goes wrong:** Each AI daily summary call sends a prompt containing an entire day's timeline (potentially hundreds of events as text). At scale — or even with aggressive local testing — per-request token counts can be far higher than estimated, especially if the prompt includes full event details, place names, geocoded addresses, and motion data. DeepSeek's pricing is low now but could change; the real risk is the lack of guardrails.

**Why it happens:** The cost of one call is trivial in development. The mental model doesn't shift to "every user, every day" until after launch.

**Consequences:**
- 1,000 daily active users × 1 summary/day × ~2,000 tokens = 2M tokens/day → measurable monthly cost
- Conversations via Echo add unbounded additional calls
- No circuit breaker means a bug causing looped API calls can drain budget overnight

**Prevention:**
- Set hard per-day per-user limits before launch (e.g., 1 daily summary + 10 Echo messages/day free)
- Implement token budgeting: truncate timeline context to the top N most significant events before sending to API
- Add a client-side rate limiter before API calls (check last-call timestamp, enforce minimum interval)
- Build a cost monitoring dashboard or alert (even a simple Slack webhook from the server proxy) before any public launch
- Consider on-device summarization for the simple daily summary (Apple Intelligence / local model) and reserve cloud API for complex Echo queries

**Warning signs:**
- API calls are made without any client-side rate limiting
- Prompt building sends the full raw sensor reading list rather than summarized events
- No per-user usage tracking exists

**Phase:** Address in AI integration phase, before any external user distribution.

---

### Pitfall 6: `CLLocationUpdate` / Modern Location API Instability on iOS 17

**What goes wrong:** The modern async `CLLocationUpdate.liveUpdates()` API introduced in iOS 17 has documented instability: on iOS 17 (not 18+), full accuracy denial causes the API to return no results rather than degraded accuracy. The `stationary` flag rarely fires and is described as "unpredictable." The `locationUnavailable` property fires spuriously alongside normal updates, causing flickering if used for UI state.

The existing `LocationCollector` uses `CLLocationManager` (the older API) — which is actually the *correct* choice — but this pitfall applies if the team tries to modernize to `CLLocationUpdate` during a refactor.

**Why it happens:** New APIs look cleaner and more Swift-idiomatic. Developers assume newer = better without checking the stability track record.

**Consequences:**
- Silent location data gaps on iOS 17 devices when users deny full accuracy
- Spurious "location unavailable" UI states that confuse users

**Prevention:**
- Keep using `CLLocationManager` with delegate pattern; it is more stable and feature-complete
- Do NOT migrate to `CLLocationUpdate` until iOS 18 is the minimum deployment target
- If `CLMonitor` is used for geofencing, note the hard 20-region cap and that references must be kept alive (recreating a monitor with the same name crashes)

**Warning signs:**
- Any PR that migrates `LocationCollector` to `CLLocationUpdate`
- Minimum deployment target lowered below iOS 18 while using modern location APIs

**Phase:** Ongoing — relevant whenever location code is touched.

---

### Pitfall 7: Approximate Location Permission Breaks Place Detection

**What goes wrong:** iOS 14+ allows users to grant "Approximate Location" (reduced accuracy, ~500m–1km radius) instead of precise. The `PlaceManager` clustering algorithm uses a 200m radius (`placeMatchRadius = 200` in `PhoneInferenceEngine`). With approximate location, all readings land within a ~500m circle — meaning the clustering logic may merge distinct places (e.g., a coffee shop and nearby library) or fail to detect arrival/departure at specific places.

**Why it happens:** Testing happens with full precision on developer devices. Approximate location is an edge case that only surfaces with real users who choose it.

**Consequences:**
- Home/work/frequent place detection breaks for users on approximate location
- Timeline shows vague events ("stayed somewhere near city center") instead of specific places
- Geocoded addresses are imprecise, making the timeline feel low-quality

**Prevention:**
- Detect `accuracyAuthorization == .reducedAccuracy` and show an in-app prompt explaining the tradeoff
- Do NOT silently degrade; tell users "Precise location is needed for accurate place detection"
- Adjust clustering radius dynamically based on reported accuracy: if `horizontalAccuracy > 300m`, widen the cluster radius
- In App Review Notes, explain why precise location is required for the core feature

**Warning signs:**
- `locationManager.accuracyAuthorization` is never checked in the codebase
- No UI path for the user who grants approximate location

**Phase:** Onboarding + LocationCollector (permission phase).

---

### Pitfall 8: SwiftData Main Thread Blocking on Timeline Queries

**What goes wrong:** SwiftData's `@Query` macro and `ModelContext` operations default to the main thread. Timeline generation involves fetching sensor readings, running the inference engine across hundreds of data points, and then persisting `DayTimelineEntity`. If done on the main thread, this causes visible UI freezes at the exact moment users open the app (11pm — the primary use moment).

The existing `BackgroundTaskManager.persistTimeline()` creates a new `ModelContext` per call — which is correct — but `collectData(for:)` in `LocationCollector` uses `MainActor.run` which blocks the main thread if the store fetch is slow.

**Why it happens:** SwiftData encourages main-thread usage via SwiftUI integration. The blocking only surfaces with large datasets (months of sensor readings).

**Consequences:**
- App freezes for 0.5–3 seconds when loading the timeline on older devices
- Particularly bad on the 11pm "check your day" moment — the core product experience
- OOM crashes if large binary data is stored in SwiftData models directly (not applicable here, but adjacent risk)

**Prevention:**
- Move `SensorDataStore.readings()` fetch off main thread using a background `ModelContext` with a separate actor
- Timeline inference (`PhoneInferenceEngine.inferEvents`) is already pure Swift — keep it off main thread
- Persist `DayTimelineEntity` from a background context (already correct in `BackgroundTaskManager`)
- Add sensor reading purge (already implemented for 30 days) — ensure it runs regularly to bound dataset size

**Warning signs:**
- Instruments shows main thread CPU spikes coinciding with timeline load
- `readings(for:)` called inside `MainActor.run` with large date ranges

**Phase:** Performance optimization (can be deferred post-MVP if dataset is small, but plan for it).

---

### Pitfall 9: Privacy Policy Mismatch Causes App Store Rejection

**What goes wrong:** Apps that collect location data must have a privacy policy that accurately describes what data is collected, how it's stored, whether it's shared with third parties, and how users can request deletion. The PROJECT.md notes "隐私政策更新 — 符合 CoreLocation Always 审核要求" is listed as Active (not yet done). Submitting without an accurate privacy policy is one of the top rejection reasons.

For Unfold: the app sends timeline context (events, place names, inferred activities) to DeepSeek's API. Even though raw GPS coordinates are not sent, the inferred data (e.g., "user was at home, then commuted, then at library") is still personal data under GDPR and Apple's privacy guidelines. This must be disclosed.

**Why it happens:** Privacy policy is treated as a checkbox rather than a substantive document. Developers underestimate what counts as "data shared with third parties" — an LLM API call is third-party data sharing.

**Consequences:**
- Rejection under guideline 5.1.1 ("Data Collection and Storage")
- App removed post-launch if policy doesn't match behavior
- GDPR fines (low risk for indie solo dev, but still a legal exposure)

**Prevention:**
- Write the privacy policy BEFORE submission, not after rejection
- Explicitly disclose: location data collected, stays on device; for AI features, anonymized activity summaries (not raw GPS) are sent to [provider] for processing
- Add a privacy policy URL to App Store Connect metadata
- Link to privacy policy from within the app (Settings screen)
- For EU users: if Echo stores conversation history locally, clarify the user's right to delete it

**Warning signs:**
- Privacy policy URL field empty in App Store Connect
- Privacy policy last updated before Echo/AI features were added
- No in-app link to privacy policy

**Phase:** Before first TestFlight external or App Store submission.

---

## Minor Pitfalls

---

### Pitfall 10: Visit API Date Edge Cases (`distantFuture` / `distantPast`)

**What goes wrong:** `CLVisit.arrivalDate` is `Date.distantPast` when the arrival was before monitoring started. `CLVisit.departureDate` is `Date.distantFuture` when the user hasn't left yet. The existing `LocationCollector` already handles `departureDate == distantFuture → nil`, but `arrivalDate == distantPast` is not guarded. A visit with arrival at year 0001 in the timeline will break sorting and date range queries.

**Prevention:** Guard `visit.arrivalDate != .distantPast` before recording. If arrival is `distantPast`, use the current time as a fallback.

**Phase:** LocationCollector — can be fixed in a single line when reviewing the sensor pipeline.

---

### Pitfall 11: Notification Permission Opt-In Rate Is ~44% on iOS

**What goes wrong:** The planned "AI proactive push insights" feature depends on notification permission. iOS average opt-in rate is ~44% — meaning over half of users will never see proactive AI insights as push notifications unless they explicitly opted in. If the entire AI proactivity feature is push-dependent, more than half the user base has a degraded experience.

**Prevention:**
- Design AI insights with an in-app inbox as the primary surface, push notifications as a secondary amplification
- Request notification permission only after demonstrating value (not on first launch)
- Pre-permission screen: explain specifically what kinds of notifications to expect ("Once a week, we'll share a pattern we noticed in your week")

**Phase:** AI proactive push feature (future milestone).

---

### Pitfall 12: WatchSyncHelper Residual Code Conflicts with Phone-First Logic

**What goes wrong:** `WatchSyncHelper.swift` exists in the Data layer. The project explicitly scopes out Apple Watch for MVP. If Watch-related code participates in any initialization paths or entitlement checks, it can cause issues: WatchConnectivity framework requires the `com.apple.developer.watch-connectivity` entitlement, which may trigger App Store review questions or cause crashes on test devices without pairing.

**Prevention:** Ensure `WatchSyncHelper` is completely inert (not initialized anywhere in the active app path). Verify no Watch-related entitlements are active in the current build target. Consider moving it to a disabled compile target.

**Phase:** Cleanup sprint / before any submission.

---

### Pitfall 13: On-Device ML (Core ML) Cannot Handle Complex Behavioral Pattern Recognition

**What goes wrong:** The project plans "设备端轻量推理 — Apple Intelligence / Core ML 处理简单分析." Core ML supports regression and classification tasks, but behavioral pattern recognition across multi-day timelines (e.g., "you go to the library every Tuesday afternoon") requires sequence modeling with memory — which is not directly expressible in Core ML without a custom model. Apple Intelligence (iOS 18+) provides some on-device LLM capability, but it is not accessible via a public API for arbitrary text generation as of 2025.

**Why it happens:** "On-device ML" is used as a generic term that implies more capability than Core ML actually provides for behavioral sequence analysis.

**Consequences:**
- On-device pattern recognition requires more engineering investment than expected
- Apple Intelligence capabilities are constrained by Apple's system prompts and cannot be used for arbitrary life-data analysis

**Prevention:**
- Scope on-device ML to tasks Core ML handles well: simple event classification (is this walk/run/commute?), anomaly detection on numeric features
- Use cloud API (DeepSeek, OpenAI, etc.) for cross-day pattern analysis and natural language summaries
- Do not promise "all AI is on-device" — be accurate in marketing about the hybrid architecture
- Monitor WWDC announcements for Apple Intelligence API expansion

**Phase:** AI architecture planning (before implementing on-device inference).

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| AI daily summary | Hardcoded API key in binary | Remove defaultAPIKey, implement proxy or user-key flow |
| AI daily summary | Token cost without guardrails | Truncate timeline context, add per-user daily limit |
| Onboarding | Always location rejection | Specific usage string, demonstrate value before requesting, App Review Notes |
| Onboarding | Approximate location breaks place detection | Detect and explain reduced accuracy to user |
| Location pipeline | Force-quit data gaps | Timeline gap UI, honest onboarding copy |
| Background tasks | BGTask unreliability | Foreground refresh as primary path, BGTask as supplement |
| App Store submission | Privacy policy mismatch | Write policy covering AI data sharing before first external build |
| Performance | SwiftData main-thread blocking | Background ModelContext for sensor reads |
| Future: proactive push | Notification opt-in ~44% | In-app inbox as primary surface |
| Future: Watch | WatchSyncHelper residual | Verify entitlement is inactive before submission |
| Future: on-device ML | Core ML scope limits | Use Core ML for classification only, cloud for sequence analysis |

---

## Sources

- [Core Location Modern API Tips (Dec 2024)](https://twocentstudios.com/2024/12/02/core-location-modern-api-tips/) — HIGH confidence (primary technical source)
- [iOS Location Tracking Caveats — Bumble Tech](https://medium.com/bumble-tech/ios-location-tracking-aac4e2323629) — MEDIUM confidence (real-world production experience)
- [Apple: startMonitoringSignificantLocationChanges()](https://developer.apple.com/documentation/corelocation/cllocationmanager/startmonitoringsignificantlocationchanges()) — HIGH confidence (official docs)
- [Apple: Handling Location Updates in the Background](https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background) — HIGH confidence (official docs)
- [High Performance SwiftData Apps — Jacob Bartlett](https://blog.jacobstechtavern.com/p/high-performance-swiftdata) — MEDIUM confidence (production benchmarks)
- [App Store Review Guidelines — Apple](https://developer.apple.com/app-store/review/guidelines/) — HIGH confidence (official)
- [App Store Review Guidelines 2025: AI App Rules — OpenForge](https://openforge.io/app-store-review-guidelines-2025-essential-ai-app-rules/) — MEDIUM confidence
- [Understanding Approximate Location in iOS 14 — Radar](https://radar.com/blog/understanding-approximate-location-in-ios-14) — MEDIUM confidence
- [Apple BGTaskScheduler Documentation](https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler) — HIGH confidence (official)
- [AI API Cost Best Practices 2025 — Skywork](https://skywork.ai/blog/ai-api-cost-throughput-pricing-token-math-budgets-2025/) — MEDIUM confidence
- [iOS Push Notification Opt-In Rates — Pushwoosh](https://www.pushwoosh.com/blog/push-notification-benchmarks/) — MEDIUM confidence
- [iOS App Secret Management Best Practices — HackerOne](https://www.hackerone.com/blog/ios-app-secret-management-best-practices-keeping-your-data-secure) — MEDIUM confidence
- [Core ML Limitations — Netguru](https://www.netguru.com/blog/coreml-vs-tensorflow-lite-mobile) — MEDIUM confidence
