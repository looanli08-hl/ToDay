# Phase 2: Onboarding and First Visible AI - Research

**Researched:** 2026-04-04
**Domain:** iOS permission onboarding, AI summary surfacing, gap visualization, privacy compliance
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ONB-01 | User is guided through Location "Always" permission with clear value explanation before system dialog | OnboardingView already shows value rows before requesting — but requests permission on single button tap, no multi-step flow; needs pre-permission value screen |
| ONB-02 | User is guided through Motion permission with clear value explanation | Motion row exists in OnboardingView but no step-sequencing; both permissions fire simultaneously on "开始记录" tap |
| ONB-03 | Permission denial is handled gracefully with path to Settings | Current LocationCollector bug: silently accepts `whenInUse` and starts monitoring (no-op); no visible recovery path; errorCard in TodayScreen has a Settings button but it's triggered by `errorMessage` containing "授权" — depends on ViewModel surfacing the right message |
| ONB-04 | App Store usage description strings are specific enough to pass App Review | Current `NSLocationAlwaysAndWhenInUseUsageDescription` string is not visible in source — must be verified in project.yml; pitfall research confirms vague strings are rejection cause |
| AIS-03 | Summary is displayed prominently on the today screen | `summarySection` in TodayScreen already renders `viewModel.insightSummary` — but `insightSummary` is built by `TodayInsightComposer` from manual records only; no `DailySummaryEntity` is read; AI summary card needs to be wired to real `DailySummaryEntity` data from SwiftData |
| REC-07 | Data gaps from force-quit/airplane mode are displayed gracefully, not hidden | No gap indicator UI exists; timeline entries simply have time gaps between them with no visual explanation |
| PRV-02 | Privacy policy page exists and is accessible from app settings | `AppConfiguration.privacyPolicyURL` points to `https://looanli08-hl.github.io/ToDay/privacy.html`; the Link row in SettingsView renders only when `privacyPolicyURL != nil` — so the row IS present; the actual page content must be verified and updated to disclose AI data processing |
| PRV-03 | App Review Notes explain Always Location usage clearly | Not a code artifact — a submission note; must be written and documented for the human to paste into App Store Connect |

</phase_requirements>

---

## Summary

Phase 2 is primarily a UI wiring and compliance phase, not a new-architecture phase. All the structural pieces already exist in the codebase: `OnboardingView` has the value explanation rows, `TodayScreen` has the `summarySection` slot, `DailySummaryEntity` is the SwiftData model that holds AI output, `AppConfiguration.privacyPolicyURL` points to a hosted privacy page, and `SettingsView` has a Link row for privacy policy. The work is: (1) improve the onboarding UX so it sequences permission requests with value explanation before each dialog, (2) wire the TodayScreen AI summary card to read from `DailySummaryEntity` in SwiftData rather than from the algorithmic `TodayInsightComposer`, (3) add gap indicator UI to the timeline for periods with no sensor data, and (4) update the privacy policy page content and Info.plist usage strings to meet App Store standards.

The two critical blockers for App Store submission are the `NSLocationAlwaysAndWhenInUseUsageDescription` string content (must be specific, 20+ words) and an accurate privacy policy that discloses AI data processing. Both are required before any TestFlight external distribution.

The `LocationCollector` has a known bug where it silently accepts `whenInUse` authorization and starts monitoring (which silently fails for background collection). This must be fixed in this phase so the onboarding denial path surfaces correctly.

**Primary recommendation:** Sequence onboarding as a multi-step flow (value screen first, then permission request, then status feedback), wire the AI summary card to read the latest `DailySummaryEntity` for today's date, add gap event type to `EventKind`, and update the privacy policy page content before first external TestFlight build.

---

## Current State Audit

### OnboardingView.swift — What Exists

The current `OnboardingView` is a single-screen layout:
- App name + tagline header
- Two static permission explanation rows (location, motion) displayed simultaneously
- Privacy note "所有数据仅存储在本地，不会上传。"
- "开始记录" button that calls `requestPermissions()` then immediately calls `onComplete()`
- "稍后设置" skip button

**Problems for ONB-01 through ONB-03:**

1. **No pre-dialog value demonstration.** The requirement says user sees a value explanation screen before any system permission dialog. The current screen shows the rows, but the system dialog fires immediately when the user taps "开始记录" — there is no "pause here, watch the sample timeline" moment.

2. **Both permissions fire together.** `requestPermissions()` calls `requestAlwaysAuthorization()` and then immediately triggers motion — no sequencing. The system will show location dialog, then motion dialog back-to-back.

3. **Denial is not handled.** After `requestPermissions()` completes, `onComplete()` is called unconditionally regardless of permission outcome. The `locationStatus` state is updated locally but nothing happens if it's `.denied` — the user lands on the main app with no recording running and no explanation.

4. **Usage description accuracy.** `requestPermissions()` creates a local `CLLocationManager()` that is immediately deallocated after the async sleep. This is a known iOS issue — the system dialog may not appear reliably if the manager is not retained.

5. **`whenInUse` silently accepted.** `locationStatus = (updatedLocStatus == .authorizedAlways || updatedLocStatus == .authorizedWhenInUse) ? .granted : ...` — treating `whenInUse` as "granted" is incorrect for background tracking. This must check for `.authorizedAlways` only.

### TodayScreen.swift — What Exists

The `summarySection` computed var already renders a `ContentCard` showing `headline`, `narrative`, and `badges` when `viewModel.insightSummary != nil`. This card appears after `scrollCanvasSection` in the VStack — below the timeline.

**Current data source for `insightSummary`:** `TodayInsightComposer.buildTodaySummary(...)` — an entirely algorithmic, rule-based generator that reads from manual `MoodRecord` objects. It never touches `DailySummaryEntity`. It produces strings like "今天的主线偏向[mood]" — not AI-generated text.

**For AIS-03:** The card slot exists and is correctly positioned. The change required is: `TodayViewModel` needs a second published property (e.g., `@Published private(set) var aiDailySummary: DailySummaryEntity?`) that is loaded from SwiftData on each `load()` call, and `TodayScreen` needs an additional or replacement card that reads this AI-generated content. The existing algorithmic `summarySection` can remain; the AI card should appear above it or replace it when AI content is available.

**Positioning guidance:** The current scroll order is: header → overview stats → [loading | error | timeline flow + scroll canvas] → summarySection → weeklySpotlightSection → recentDaysSection. The AI daily summary should appear prominently — immediately after the timeline canvas (before the algorithmic summary) so the user encounters it naturally while scrolling down.

### TodayViewModel.swift — AI Summary Gap

`TodayViewModel` has no property or method that reads from `DailySummaryEntity`. The `insightSummary` property is computed from `TodayInsightComposer` using only manual records. There is a `timelineDataSummary` property that formats today's events as text for Echo prompts, and `echoEngine: EchoEngine?` is injected (but may be nil at construction).

To surface the AI summary, `TodayViewModel` needs:
1. An injected reference to `EchoMemoryManager` (or a direct `ModelContainer` + SwiftData fetch)
2. A `loadAIDailySummary()` method called inside `load()`
3. A new `@Published private(set) var aiDailySummary: String?` (or a `DailySummaryEntity?`) property

The `EchoMemoryManager.loadSummary(forDateKey:)` method already exists — it fetches a `DailySummaryEntity` by `"yyyy-MM-dd"` key. `TodayViewModel` can call this directly after loading the timeline.

### SettingsView.swift — Privacy Policy

The privacy policy Link row renders via:
```swift
if let privacyPolicyURL = AppConfiguration.privacyPolicyURL {
    Link(destination: privacyPolicyURL) { ... }
}
```
`AppConfiguration.privacyPolicyURL` is set to `https://looanli08-hl.github.io/ToDay/privacy.html`.

The link row IS present in the build. The gap is: the privacy policy page at that URL must be updated to disclose AI data processing. The current `DataExplanationView` (accessible via "数据说明" NavigationLink) says "我们不上传、不收集、不分享任何个人数据。" — this will be inaccurate once Phase 1 AI pipeline ships, since anonymized activity summaries are sent to Claude via AIProxy.

### AppConfiguration.swift — Privacy Policy URL

`privacyPolicyURL = URL(string: "https://looanli08-hl.github.io/ToDay/privacy.html")` — page exists and is hosted on GitHub Pages. Content must be updated.

---

## Standard Stack

### Core (no new packages required)
| Component | Current State | Change Required |
|-----------|--------------|-----------------|
| CoreLocation | `CLLocationManager` delegate pattern in `LocationCollector.swift` | Fix onboarding to retain manager; fix `whenInUse` acceptance bug |
| CoreMotion | `CMMotionActivityManager` in `OnboardingView.swift` + `MotionCollector.swift` | No change to motion collection; onboarding sequencing fix only |
| SwiftData | `DailySummaryEntity` in `EchoMemoryEntities.swift`; `EchoMemoryManager` loads by dateKey | Add `loadAIDailySummary()` call to `TodayViewModel.load()` |
| SwiftUI | All views | New gap indicator view component; AI summary card component |

**Phase 2 adds zero new Swift packages.** All required functionality is available through existing frameworks and existing codebase pieces.

---

## Architecture Patterns

### Recommended Project Structure Changes
```
ios/ToDay/ToDay/
├── Features/
│   ├── Onboarding/
│   │   └── OnboardingView.swift          — rewrite as multi-step flow
│   ├── Today/
│   │   ├── TodayScreen.swift             — add AI summary card, gap indicators
│   │   ├── TodayViewModel.swift          — add aiDailySummary property + load
│   │   └── Components/
│   │       ├── AIDailySummaryCard.swift  — new: AI summary display card
│   │       └── GapIndicatorView.swift    — new: timeline gap row
│   └── Settings/
│       └── SettingsView.swift            — update DataExplanationView content
```

### Pattern 1: Multi-Step Onboarding Flow

The App Store-safe onboarding pattern for Always Location apps is:
1. **Value screen:** Show a populated sample timeline (or animated preview) — no permission dialog yet
2. **Permission request screen:** Explain specifically what the permission enables, with a primary CTA button that triggers the system dialog
3. **Status confirmation screen:** Show checkmark/success or recovery path to Settings

The current single-screen layout can be evolved into a `TabView` with `tabViewStyle(.page)` driven by a `@State private var step: OnboardingStep` enum with cases `.value`, `.locationPermission`, `.motionPermission`, `.complete`. The `onComplete` closure is called only from the `.complete` step.

**Critical implementation detail:** The `CLLocationManager` instance must be stored as a property (not a local variable) to ensure iOS presents the system dialog and the delegate receives callbacks. The current code creates a local `let locationManager = CLLocationManager()` that is garbage collected immediately after the `requestAlwaysAuthorization()` call — the dialog may appear but the delegate callback never fires because the manager is deallocated.

```swift
// WRONG (current) — manager is deallocated before delegate fires
let locationManager = CLLocationManager()
locationManager.requestAlwaysAuthorization()

// CORRECT — retain in a coordinator or as @State
@State private var locationManager = CLLocationManager()
// (or use a CLLocationManagerDelegate coordinator held as @StateObject)
```

### Pattern 2: AI Daily Summary Card on TodayScreen

The AI daily summary should be sourced from `DailySummaryEntity` (Phase 1 output), not from `TodayInsightComposer`. The card already exists in spirit — `summarySection` renders the right layout. The change is:

1. `TodayViewModel` gains `@Published private(set) var aiDailySummary: DailySummaryEntity?`
2. Inside `load(forceReload:)`, after the timeline loads: call `EchoMemoryManager.loadSummary(forDateKey: todayKey)` and assign to `aiDailySummary`
3. `TodayScreen` renders a new `AIDailySummaryCard` component before `summarySection` when `viewModel.aiDailySummary != nil`

The `summarySection` (algorithmic) should continue to render when `aiDailySummary == nil`, so the screen is never empty.

**Card placement:** Immediately after `scrollCanvasSection(timeline)`, before `summarySection`. Users scroll down from the timeline and encounter the AI insight first.

```swift
// In TodayScreen body VStack:
if let timeline = viewModel.timeline {
    if timeline.entries.isEmpty {
        emptyStateCard
    } else {
        signatureSection(timeline)
        scrollCanvasSection(timeline)
        // NEW: AI summary card appears here
        if let aiSummary = viewModel.aiDailySummary {
            aiDailySummaryCard(aiSummary)
        }
    }
}
summarySection          // algorithmic fallback remains
weeklySpotlightSection
recentDaysSection
```

### Pattern 3: Gap Indicators in Timeline

**What a gap is:** A period where no `InferredEvent` covers the time span. This happens when:
- Phone was off / dead battery
- App was force-quit
- Airplane mode with no cached location events

**Implementation approach:** In `PhoneInferenceEngine.inferEvents(from:on:places:)`, there is already a "blank gap" detection step in the priority ordering. The current code likely creates quiet/blank events for uncovered periods. The task is to ensure that gaps created from "no sensor data at all" (as opposed to "sensor data shows stationary") are tagged with a distinct `EventKind`.

The existing `EventKind` enum should gain a `.dataGap` case (or check if a `.quiet` or `.blank` case exists). `EventCardView` / `DayScrollView` renders this as a labeled dashed separator rather than a filled event card.

**Visual design for gap indicator (per .impeccable.md principles):**
- Thin dashed horizontal rule
- Monospaced timestamp label showing the gap duration
- Muted gray-tinted text, not a full card
- Example: `- - - 3h 20m without data - - -`

### Pattern 4: LocationCollector Fix for whenInUse Denial

The known bug in `LocationCollector` (CONCERNS.md):
```swift
// CURRENT BUG: starts monitoring on whenInUse (which silently fails for background)
if updatedLocStatus == .authorizedAlways || updatedLocStatus == .authorizedWhenInUse {
    startMonitoring()
}
```

Fix: check `authorizedAlways` only for background-capable monitoring calls:
```swift
case .authorizedAlways:
    startMonitoringSignificantLocationChanges()
    startMonitoringVisits()
case .authorizedWhenInUse:
    // Background monitoring won't work — surface error to ViewModel
    // so TodayScreen can show recovery path
    break
```

`TodayViewModel` should expose a `@Published private(set) var locationAuthorizationStatus: CLAuthorizationStatus` that TodayScreen checks on load to show the `errorCard` with the "前往设置" button.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Permission status observation | Custom polling loop | `CLLocationManagerDelegate.locationManagerDidChangeAuthorization` | System delegate fires reliably on status change; polling wastes battery |
| Gap detection algorithm | Custom calendar math | Extend existing `PhoneInferenceEngine` blank-gap pass | Engine already iterates sorted events; gap detection is one extra pass |
| Privacy policy page | In-app UIWebView or WKWebView | Link to external URL via `Link(destination:)` (already in SettingsView) | App Store prefers external hosted policy; external URL is updatable without app update |
| AI summary loading | New store abstraction | Direct `EchoMemoryManager.loadSummary(forDateKey:)` call | Memory manager already has the exact method; no new abstraction needed |
| Multi-step onboarding state machine | Complex navigation | `@State var step: OnboardingStep` with `TabView(.page)` or simple `if/else` in body | SwiftUI paging tab view is the idiomatic approach for step-by-step flows |

---

## Common Pitfalls

### Pitfall 1: CLLocationManager Deallocated Before Dialog Appears
**What goes wrong:** Current `OnboardingView.requestPermissions()` creates a local `CLLocationManager` that is garbage collected before the delegate callback fires. The system dialog may appear but the status update is lost.
**Why it happens:** The manager is `let` scoped to the function, not retained by the view.
**How to avoid:** Store `CLLocationManager` as a `@State private var locationManager = CLLocationManager()` property on the view, or use a `@StateObject` coordinator that conforms to `CLLocationManagerDelegate`.
**Warning signs:** `locationStatus` always stays `.pending` after tapping "开始记录" even when user grants permission.

### Pitfall 2: Requesting Always Authorization Without Showing WhenInUse First
**What goes wrong:** iOS 13+ requires that apps first request `whenInUse`, wait for that grant, then upgrade to `always`. Calling `requestAlwaysAuthorization()` directly on a fresh install on iOS 17+ shows the system dialog with only "Allow While Using App" and "Don't Allow" — there is no "Always Allow" option until the second request after `whenInUse` is granted.
**Why it happens:** Developer calls `requestAlwaysAuthorization()` expecting "Always" to appear immediately.
**How to avoid:** Step 1: call `requestWhenInUseAuthorization()`. Step 2: in the `locationManagerDidChangeAuthorization` callback, when status becomes `.authorizedWhenInUse`, prompt user to upgrade to "Always" via a custom explanation screen, then call `requestAlwaysAuthorization()` — iOS will show a prompt to upgrade.
**Warning signs:** System dialog never shows "Always Allow" option; user can only grant "While Using."

### Pitfall 3: onComplete() Called Unconditionally After Permission Request
**What goes wrong:** Current onboarding calls `onComplete()` immediately after `requestPermissions()` returns, regardless of what the user chose. A user who taps "Don't Allow" on both dialogs is taken straight into the main app with no recording possible and no explanation.
**How to avoid:** Gate `onComplete()` on at least location having been decided (either granted or denied). If denied, show a recovery screen inside the onboarding flow with a "前往设置" button before allowing the user to proceed.

### Pitfall 4: summarySection Shows Algorithmic Text When AI Summary Is Available
**What goes wrong:** If both `viewModel.insightSummary` (algorithmic) and `viewModel.aiDailySummary` (real AI) are populated, TodayScreen will show both, creating confusing redundancy.
**How to avoid:** When `aiDailySummary` is present, skip the algorithmic `summarySection` (or show it collapsed/secondary). The AI card is the primary; the algorithmic fallback shows only when no AI content exists yet.

### Pitfall 5: Privacy Policy Says "No Data Uploaded" After Phase 1 Ships
**What goes wrong:** `DataExplanationView` currently states "我们不上传、不收集、不分享任何个人数据。" — this will be false once Phase 1 wires Claude via AIProxy. The hosted privacy policy at `looanli08-hl.github.io/ToDay/privacy.html` must be updated before Phase 1 ships externally.
**How to avoid:** Update both (a) the hosted HTML page and (b) the `DataExplanationView` text in `SettingsView.swift` to accurately state that anonymized activity summaries (not raw GPS) are sent to an AI provider for Pro AI features.

### Pitfall 6: App Review Rejection for Vague Location Usage String
**What goes wrong:** A short or vague `NSLocationAlwaysAndWhenInUseUsageDescription` causes rejection under App Store guideline 5.1.1. Reviewers must be able to understand the specific benefit without guessing.
**How to avoid:** Usage string must be specific and exceed 20 words. Recommended text:
```
"Unfold passively records your location visits throughout the day to build your life timeline automatically, even when the app is closed. This is required for background recording."
```
Chinese equivalent for App Store Connect (Chinese):
```
"Unfold 在后台持续记录你到过的地方和停留时长，自动生成一天的生活轨迹。关闭 App 后仍需持续记录，因此需要始终允许访问位置。"
```

---

## Code Examples

### Multi-Step Onboarding Structure

```swift
// Source: existing OnboardingView.swift pattern + iOS CLLocationManager two-step permission flow
enum OnboardingStep {
    case value        // show sample timeline, no dialog
    case location     // explain location, trigger whenInUse then always
    case motion       // explain motion, trigger motion dialog
    case denied       // recovery path when location denied
    case complete     // success, recording starts
}

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var step: OnboardingStep = .value
    @StateObject private var locationCoordinator = LocationPermissionCoordinator()
    // ...
}
```

### Loading AI Daily Summary in TodayViewModel

```swift
// In TodayViewModel.load(forceReload:) — after timeline loads
@Published private(set) var aiDailySummary: DailySummaryEntity?

private func loadAIDailySummary() {
    let dateKey = Self.dateKeyFormatter.string(from: Date())
    let context = ModelContext(modelContainer)
    var descriptor = FetchDescriptor<DailySummaryEntity>(
        predicate: #Predicate { $0.dateKey == dateKey }
    )
    descriptor.fetchLimit = 1
    aiDailySummary = try? context.fetch(descriptor).first
}
```

### Gap Indicator EventKind

```swift
// Extend existing EventKind enum in SharedDataTypes.swift
// Add: case dataGap  — periods where no sensor data was recorded

// In DayScrollView, render gap events differently:
if event.kind == .dataGap {
    GapIndicatorView(duration: event.duration)
} else {
    EventCardView(event: event, ...)
}
```

### NSLocationAlwaysAndWhenInUseUsageDescription (project.yml)

```yaml
# In ios/ToDay/project.yml under targets.ToDay.info.properties:
NSLocationAlwaysAndWhenInUseUsageDescription: >
  Unfold passively records your location visits throughout the day to build
  your life timeline automatically, even when the app is closed. This is
  required for background recording.
NSLocationWhenInUseUsageDescription: >
  Unfold uses your location to record places you visit and build your daily
  life timeline.
```

---

## Environment Availability

This phase is code/config-only. No new external dependencies.

| Dependency | Required By | Available | Notes |
|------------|------------|-----------|-------|
| CoreLocation | ONB-01, ONB-02, ONB-03 | Built-in iOS framework | Already imported |
| SwiftData | AIS-03 (DailySummaryEntity fetch) | Built-in iOS 17+ | Already in project |
| GitHub Pages (privacy policy host) | PRV-02 | Must verify URL is live | `https://looanli08-hl.github.io/ToDay/privacy.html` — content must be updated |

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest |
| Config file | None — uses Xcode scheme |
| Quick run command | `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO` |
| Full suite command | Same as quick run (180+ tests in single suite) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ONB-01 | Onboarding shows value before permission dialog | unit | `xcodebuild test -only-testing:ToDayTests/OnboardingTests` | ❌ Wave 0 |
| ONB-02 | Motion permission is sequenced with explanation | unit | `xcodebuild test -only-testing:ToDayTests/OnboardingTests` | ❌ Wave 0 |
| ONB-03 | Denial shows recovery path, does not call onComplete immediately | unit | `xcodebuild test -only-testing:ToDayTests/OnboardingTests` | ❌ Wave 0 |
| ONB-04 | Usage strings are present and specific in Info.plist | unit (Info.plist check) | `xcodebuild test -only-testing:ToDayTests/InfoPlistTests` | ❌ Wave 0 |
| AIS-03 | AI summary card renders when DailySummaryEntity exists for today | unit | `xcodebuild test -only-testing:ToDayTests/TodayViewModelTests` | ❌ Wave 0 — add to existing TodayViewModelTests |
| REC-07 | Gap events appear in timeline when sensor data is absent | unit | `xcodebuild test -only-testing:ToDayTests/PhoneInferenceEngineTests` | Partial — existing tests cover inference; gap case needs adding |
| PRV-02 | Privacy policy link row is present in SettingsView | unit (snapshot or existence check) | manual-only (UI test or visual inspection) | manual-only |
| PRV-03 | App Review Notes document — not a code artifact | manual-only | N/A | manual-only |

### Wave 0 Gaps
- [ ] `ios/ToDay/ToDayTests/OnboardingTests.swift` — covers ONB-01, ONB-02, ONB-03 (test step sequencing, denial handling, `onComplete` not called on denial)
- [ ] `ios/ToDay/ToDayTests/InfoPlistTests.swift` — covers ONB-04 (read bundle and assert `NSLocationAlwaysAndWhenInUseUsageDescription` length >= 20 words)
- [ ] Extend `ios/ToDay/ToDayTests/TodayViewModelTests.swift` — covers AIS-03 (inject mock `DailySummaryEntity`, assert `aiDailySummary` is populated after `load()`)
- [ ] Extend `ios/ToDay/ToDayTests/PhoneInferenceEngineTests.swift` — covers REC-07 (input readings with 3+ hour gap, assert `.dataGap` event in output)

---

## Privacy Policy: Required Content

The hosted page at `https://looanli08-hl.github.io/ToDay/privacy.html` and the in-app `DataExplanationView` must be updated to include these disclosures before Phase 1 ships externally:

1. **Location data stays on device:** "All raw location data is stored locally on your device and is never transmitted to any server."
2. **AI processing disclosure:** "For AI daily summary features (Pro tier), Unfold sends anonymized activity summaries — consisting of inferred place names and activity types, not raw GPS coordinates — to Anthropic Claude via AIProxy for processing. These summaries do not include your exact location or personally identifying information."
3. **Data deletion:** "You can delete all recorded data at any time from Settings."
4. **Third-party processors:** "AI Provider: Anthropic (via AIProxy). AIProxy acts as a key proxy; your activity summary text is forwarded to Anthropic for AI analysis."

The `DataExplanationView` must be updated in parallel — it currently says "我们不上传、不收集、不分享任何个人数据" which will be inaccurate.

---

## App Store Review Notes Template

This is a non-code deliverable — a text block to paste into App Store Connect "Notes for Reviewers" on every submission:

```
Unfold is a passive life-logging app. The app uses Location Always 
authorization to automatically record place visits and activity throughout 
the day while running in the background, even when the app is not open. 

This is the core feature of the app — without Always authorization, 
background location recording cannot occur and the daily life timeline 
cannot be built.

To test: Grant "Always" location permission during onboarding. Background 
the app. Move to a new location. Return to the app to see the recorded visit 
appear in the Today timeline.

Test account: Not required — the app is fully local with no login.
```

---

## Open Questions

1. **Two-step Always Location flow — iOS version behavior**
   - What we know: iOS 13+ requires `whenInUse` before `always` upgrade; the upgrade prompt appears automatically after `requestAlwaysAuthorization()` is called once `whenInUse` is granted
   - What's unclear: Does iOS 17 specifically show a popup prompting upgrade to "Always," or must the user go to Settings? Apple's behavior has shifted across versions.
   - Recommendation: Test on physical device with iOS 17. The fallback is always "take user to Settings" via `UIApplication.openSettingsURLString` with an explanation banner.

2. **Gap indicator: distinguish "no data" from "recording was off"**
   - What we know: A gap could mean airplane mode, dead battery, or force-quit — all look the same from the sensor data perspective (no readings for the time range)
   - What's unclear: Should the gap label say "录制暂停" generically, or attempt to infer reason (e.g., if device state shows no events, likely off)?
   - Recommendation: Label generically as "数据空白" or "这段时间没有记录" — don't attempt to infer reason without evidence; honest ambiguity is better than wrong inference.

3. **AI summary card positioning relative to existing summarySection**
   - What we know: `summarySection` renders algorithmic `TodayInsightSummary` from `TodayInsightComposer`; an AI card from `DailySummaryEntity` would be more accurate and compelling
   - What's unclear: Should the planner replace `summarySection` with the AI card, or keep both?
   - Recommendation: Keep algorithmic section as fallback when no AI content exists; show AI card as the primary when `aiDailySummary` is not nil. Suppress the algorithmic card when AI content is present to avoid redundancy.

4. **`DataExplanationView` accuracy after Phase 1**
   - What we know: Currently says "no data uploaded" — will be false post-Phase 1
   - What's unclear: Whether Phase 1 ships before Phase 2, meaning Phase 1's AI pipeline must be active before Phase 2's privacy update
   - Recommendation: Update `DataExplanationView` in Phase 2 to reflect actual behavior (conditionally worded: "AI features send anonymized summaries to our AI provider"). This is the correct time to do it since PRV-02 is a Phase 2 requirement.

---

## Sources

### Primary (HIGH confidence)
- Direct codebase read: `OnboardingView.swift`, `TodayScreen.swift`, `TodayViewModel.swift`, `SettingsView.swift`, `AppRootScreen.swift`, `AppConfiguration.swift`, `EchoScheduler.swift`, `EchoMemoryEntities.swift`, `EchoMemoryManager.swift`, `TodayInsightComposer.swift`
- `.planning/codebase/CONCERNS.md` — LocationCollector `whenInUse` bug documented
- `.planning/codebase/ARCHITECTURE.md` — data flow diagram for Echo AI pipeline
- `.planning/research/PITFALLS.md` — Pitfall 2 (App Store Always Location rejection), Pitfall 9 (Privacy policy mismatch)
- Apple App Store Review Guidelines 5.1.1 — referenced in PITFALLS.md

### Secondary (MEDIUM confidence)
- `.planning/research/SUMMARY.md` — Phase 2 must-implement list, architecture step 5
- `.planning/REQUIREMENTS.md` — ONB-01 through ONB-04, AIS-03, REC-07, PRV-02, PRV-03 definitions
- `.planning/ROADMAP.md` — Phase 2 success criteria

---

## Metadata

**Confidence breakdown:**
- Current code state (OnboardingView, TodayScreen, ViewModel): HIGH — read directly from source files
- Onboarding fix approach (two-step Always Location): HIGH — well-documented iOS pattern
- AI summary wiring: HIGH — both `EchoMemoryManager.loadSummary` and `summarySection` slot exist; change is mechanical
- Gap indicator: MEDIUM — `EventKind` enum extension is standard; DayScrollView rendering details not fully read
- Privacy policy requirements: HIGH — documented in PITFALLS.md with App Store guideline citations
- iOS 17 two-step Always Location exact behavior: MEDIUM — general pattern known; device testing required for exact dialog flow

**Research date:** 2026-04-04
**Valid until:** 2026-05-04 (App Store guidelines stable; CoreLocation behavior stable on iOS 17+)
