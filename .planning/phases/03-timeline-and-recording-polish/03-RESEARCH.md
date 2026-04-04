# Phase 3: Timeline and Recording Polish — Research

**Researched:** 2026-04-04
**Domain:** SwiftUI visual polish, CoreLocation/CoreMotion recording pipeline, iOS background execution
**Confidence:** HIGH (all findings derived from direct source code inspection)

---

## Summary

Phase 3 covers two fundamentally different problem domains: **UI polish** (making what already renders look Apple-quality) and **recording pipeline validation** (making passive sensor collection reliable on real devices). These domains share almost no implementation surface and should be planned as separate tracks.

The UI is structurally complete. `DayScrollView`, `EventCardView`, `QuickRecordSheet`, and `HistoryScreen` all exist and render. The gaps are precision issues: wrong font sizes, non-compliant weights, out-of-spec spacing literals, and typography deviations that the UI-SPEC design contract has now locked. The recording pipeline is architecturally complete — `LocationCollector`, `MotionCollector`, `PlaceManager`, and `PhoneInferenceEngine` all exist — but has never been exercised on a real device with Always Location granted. There is no test coverage for live background behavior.

Manual recording (MAN-01 through MAN-03) is the most complete subset of this phase. `QuickRecordSheet` is implemented and wired, mood records appear inline on the timeline, and the annotation flow (`AnnotationSheet`, `EventAnnotationSheet`) exists. The remaining work is polish: a typography correction to the sheet title (28pt → 23pt heading), and validation that mood chips appear correctly on real data.

**Primary recommendation:** Split Phase 3 into three sequential tracks — (A) typography/spacing compliance audit across all timeline views, (B) EventCardView proportional height implementation, (C) real-device recording pipeline validation on physical hardware with Always Location.

---

## Project Constraints (from CLAUDE.md)

- **Tech Stack:** SwiftUI + iOS 17+ + SwiftData. No third-party UI frameworks, zero external Swift Package Manager dependencies.
- **Privacy:** Local-first. Cloud API calls pass only place names and event descriptions — no raw GPS coordinates.
- **Design:** Must reach Apple-level quality. All decisions from `.impeccable.md` apply.
- **Platform:** iPhone only (no iPad/Mac). MVP has no Watch integration.
- **Build verification:** Every change requires `xcodegen generate` + build pass + 180+ tests pass.
- **New code uses `AppColor.*`, not `TodayTheme.*`** — `TodayTheme` is a compatibility shim scheduled for removal.

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TML-01 | Vertical timeline with time-of-day gradient background | Gradient already implemented via `gradientStops` in `DayVerticalTimelineContent`. Colors match UI-SPEC `AppColor.timeline*` tokens. No new work needed — verify token names match. |
| TML-02 | Each event shows type badge, duration, place name | `EventCardView` renders `kindBadgeTitle`, `scrollDurationText`, and `compactDetailLine`. Badge font is `10pt bold` — UI-SPEC requires `12pt semibold`. Duration is `13pt bold` — spec requires `12pt semibold monospaced`. Both need correction. |
| TML-03 | Tap event to see details | `onTapGesture` on `EventCardView` → `selectedEvent` → `.sheet(item: $selectedEvent)` → `EventDetailView` is fully wired in `TodayScreen`. Works. |
| TML-04 | Annotate blank periods | `quietGapRow` has `onTapGesture` wired to `onBlankTap`. `AnnotationSheet` and `EventAnnotationSheet` both exist. Works. |
| TML-05 | Apple-level visual quality per .impeccable.md | See Typography Gap table below. Multiple font size/weight deviations exist. This is the primary work item for the UI track. |
| TML-06 | Browse any past day's timeline via history screen | `HistoryScreen` is implemented with date strip (30 days), calendar expand sheet, and `DayScrollView` embed. Works. Minor polish needed (see History section). |
| REC-01 | Auto-records location visits in background | `LocationCollector` calls `startMonitoringVisits()` + `startMonitoringSignificantLocationChanges()`. Requires `authorizedAlways` — guarded correctly. Background behavior requires real-device validation. |
| REC-02 | Detects and records activity type | `MotionCollector` queries `CMMotionActivityManager` for stationary/walking/running/automotive/cycling. Mapped to `MotionActivity` enum. Exists and is wired. |
| REC-03 | Infers events from sensor data | `PhoneInferenceEngine` runs sleep/commute/exercise/stay inference. Priority ordering implemented (sleep → commute → exercise → stays → blanks). Merging implemented. Real-device validation needed. |
| REC-04 | Places auto-labeled via reverse geocoding | `PlaceManager.resolveUnnamedPlaces()` calls `CLGeocoder` on unknown places. `PlaceManager.reclassifyPlaces()` upgrades visited → frequent → home/work by visit count and time-of-day. Exists. |
| REC-05 | Places auto-classified as home/work/frequent | `PlaceCategory` enum: `.home`, `.work`, `.frequent`, `.visited`. `reclassifyPlaces()` applies heuristics. Exists. Validation on real accumulated data needed. |
| REC-06 | Recording survives app kill / significant location change re-launch | `startMonitoringSignificantLocationChanges()` re-launches app when location changes occur. `BackgroundTaskManager` handles `BGAppRefreshTask`. `locationManagerDidChangeAuthorization` restarts monitoring after re-authorization. Needs real-device kill-and-resume test. |
| MAN-01 | Record mood with one tap | `heart.circle.fill` button in header + "记录此刻" bottom bar CTA both call `viewModel.openQuickRecordComposer()`. `QuickRecordSheet` opens with mood grid. Implemented. |
| MAN-02 | Capture moments via text/voice/photo | `QuickRecordSheet` has `TextField` for note, `PhotosPicker` for photos (max 3). Voice recording exists via `VoiceRecordView` but is not currently exposed in `QuickRecordSheet`. Text + photo paths are complete. |
| MAN-03 | Manual records appear inline on timeline | `makeMoodEvents` + `makeTimelineItems` logic in `DayVerticalTimelineContent` correctly interleaves mood events with canvas events and splits quiet gaps around them. Implemented. |
</phase_requirements>

---

## Typography Gap Analysis (TML-05 / TML-02)

This is the single highest-value change in Phase 3. The UI-SPEC consolidates to **4 sizes, 2 weights** only. Current code deviates in multiple places.

### Deviations Found

| Location | Element | Current | UI-SPEC Required | Fix |
|----------|---------|---------|-----------------|-----|
| `EventCardView` | `kindBadgeTitle` | `10pt bold monospaced` | `12pt semibold monospaced` | Change font call |
| `EventCardView` | `scrollDurationText` | `13pt bold monospaced` | `12pt semibold monospaced` | Change font call |
| `EventCardView` | `compactDetailLine` | `13pt regular tertiary` | `12pt regular tertiary` | Change font call |
| `EventCardView` | `moodMarker` name text | `14pt medium` | `15pt semibold` | Change font call |
| `DayScrollView` (standardEventRow) | start time | `11pt medium monospaced` | `12pt regular monospaced at 60% opacity` | Change font call |
| `DayScrollView` (standardEventRow) | end time | `10pt medium monospaced` | `12pt regular monospaced at 35% opacity` | Change font call |
| `QuickRecordSheet` | `sheetTitle` | `28pt regular serif italic` | `23pt regular serif italic` (heading tier) | Change size |
| `TodayScreen` (signatureSection) | description text | `14pt regular` | `15pt regular` (body tier) | Change size |
| `TodayScreen` (scrollCanvasSection) | description text | `14pt regular` | `15pt regular` (body tier) | Change size |
| `TodayScreen` (summarySection) | headline | `16pt semibold` | `15pt semibold` (body tier semibold) | Change size |
| `HistoryScreen` (selectedDayContent) | date header | `.title2.bold()` (system) | `23pt regular serif` (heading tier) | Change to explicit |
| `HistoryScreen` (insightSection) | "生活脉搏" title | `18pt bold` | `15pt semibold` (body tier) | Change |
| `HistoryScreen` (metricCard) | metric value | `26pt bold` | `23pt semibold rounded` (heading tier) | Change size and weight |

### What Is Correct (do not change)

- `TodayScreen` header: "今日画卷" at `33pt regular serif italic` — matches Hero tier.
- `TodayScreen` section titles ("今日脉络", "今日时间轴"): `23pt regular serif italic` — matches Heading tier.
- `EventCardView` event name: `15pt semibold` — matches Body tier semibold.
- `QuickRecordSheet` moodGrid: `.subheadline.weight(.medium)` — will map to ~15pt. Acceptable.
- `DayScrollView` `quietGapRow` label: `12pt regular italic` — already on Small tier.
- `HistoryScreen` `sectionLabel`: `12pt semibold tracking 1.5` — matches Small tier.

### Shadow Violation (TML-05)

`TodayScreen` bottom action bar uses:
```swift
.shadow(color: Color.primary.opacity(0.06), radius: 18, x: 0, y: 8)
```
UI-SPEC prohibits `Color.primary` as shadow color. Required: `Color(red: 0.4, green: 0.3, blue: 0.2).opacity(0.10)` with radius 16, y 4 (`.elevated` level). Use `.appShadow(.elevated)`.

### Corner Radius Deviation

`EventCardView` card uses `cornerRadius: 14`. UI-SPEC assigns `AppRadius.lg` (16pt) to event cards. Change to `AppRadius.lg`.

---

## Spacing Gap Analysis (TML-05)

Current code has mixed literal and token usage. Literals that must be replaced:

| Location | Current | Required | Token |
|----------|---------|---------|-------|
| `TodayScreen` ScrollView VStack spacing | `18` | `AppSpacing.md` (16pt) | `AppSpacing.md` |
| `TodayScreen` scrollCanvasSection VStack spacing | `14` | `AppSpacing.sm` (12pt) | `AppSpacing.sm` |
| `TodayScreen` `overviewSection` VStack spacing | `10` | `AppSpacing.xs` (8pt) | `AppSpacing.xs` |
| `TodayScreen` `bottomActionBar` internal spacing | `12` | `AppSpacing.sm` (12pt) | already correct by value, replace literal |
| `QuickRecordSheet` outermost VStack spacing | `24` | `AppSpacing.lg` (24pt) | already correct, replace literal |
| `HistoryScreen` `selectedDayContent` VStack spacing | `20` | `AppSpacing.md` (16pt) | `AppSpacing.md` |

Exceptions to preserve (per UI-SPEC explicit overrides):
- Timeline left column: `frame(width: 44)` — locked at 44pt
- Connector: `frame(width: 20)` — locked at 20pt
- Color accent bar in `EventCardView`: `frame(width: 4)` — locked at 4pt
- Bottom action bar corner radius: `20` literal — locked (not in AppRadius tokens)
- Bottom action bar `overlay(RoundedRectangle(cornerRadius: 20))` — correct per spec

---

## EventCard Row Height (TML-02 / TML-05)

Current implementation uses **fixed heights**: 76pt for all events, 92pt for sleep with stages. UI-SPEC requires heights **proportional to duration**. Minimum: 44pt (touch target).

This is a moderately complex change. The `eventRowHeight(for:)` function in `DayScrollView` must be replaced with a duration-proportional calculation. Key constraints:
- Minimum: 44pt (iOS HIG touch target)
- Maximum: Reasonable cap (e.g. 180pt for very long events like overnight sleep)
- Sleep with stages: Must still fit the `SleepStageRibbon` — minimum 92pt for stage-decorated sleep events
- `currentTimeOffset` calculation in `DayVerticalTimelineContent` uses `rowHeight(for:)` — must stay consistent

Recommended formula:
```swift
private func eventRowHeight(for event: InferredEvent) -> CGFloat {
    let durationMinutes = max(Int(event.duration / 60), 1)
    // Scale: 1 minute ≈ 0.5pt, clamped to [44, 180]
    let proportional = CGFloat(durationMinutes) * 0.5
    let base = max(44, min(180, proportional))
    // Sleep with stages needs extra room for the ribbon
    if event.kind == .sleep,
       let stages = event.associatedMetrics?.sleepStages,
       !stages.isEmpty {
        return max(base, 92)
    }
    return base
}
```

Source: derived from UI-SPEC requirement "event row heights are proportional to duration" + "Minimum visible row: 44pt touch target."

---

## Recording Pipeline Assessment (REC-01 to REC-06)

### What Is Built

The full pipeline exists:
- `LocationCollector`: `CLLocationManager` with `startMonitoringVisits()` + `startMonitoringSignificantLocationChanges()`. Background monitoring gated on `.authorizedAlways`.
- `MotionCollector`: `CMMotionActivityManager` queries historical activity for a date range.
- `PlaceManager`: Visit accumulation + geocoding via `CLGeocoder` + heuristic home/work classification.
- `PhoneInferenceEngine`: Priority-ordered inference (sleep → commute → exercise → stays → blanks). 180+ unit tests pass.
- `PhoneTimelineDataProvider`: Orchestrates all collectors, saves to `SensorDataStore`, runs inference.
- `BackgroundTaskManager`: `BGAppRefreshTask` for today's timeline, `BGProcessingTask` for 7-day backfill.

### What Has Not Been Validated

None of REC-01 through REC-06 has been exercised on a real device. The entire recording pipeline runs only via `MockTimelineDataProvider` on simulators. There is no integration test that fires `CLVisit` delegate callbacks and verifies data appears in the timeline.

### Key Risks per Requirement

**REC-01 (background location):** `locationManagerDidChangeAuthorization` restarts monitoring on `.authorizedAlways`. The Phase 2 fix (stop monitoring on `.authorizedWhenInUse`) is already in place. Risk: Always authorization may not survive app kill on older iOS versions without explicit re-request.

**REC-03 (event inference):** `PhoneInferenceEngine` infers from `SensorReading` payloads. Sleep inference relies on `deviceState` readings (screen lock/unlock). If `DeviceStateCollector` is not running, sleep events will not appear. Need to verify `DeviceStateCollector` is started in `AppContainer`/`ToDayApp`.

**REC-04 (reverse geocoding):** `PLaceManager.resolveUnnamedPlaces()` calls `CLGeocoder.reverseGeocodeLocation`. `CLGeocoder` has rate limits (approximately 50 requests/hour per Apple documentation). For users with many distinct visits in one day, this could hit the limit. Mitigation: the `isConfirmedByUser` flag + `matchRadius: 100m` clustering reduces unique geocoding calls.

**REC-06 (survive kill):** Significant location changes wake the app via `application(_:didFinishLaunchingWithOptions:)`. This requires the app to re-register location monitoring at launch. Verify that `LocationCollector.startMonitoring()` is called in the app startup path when `authorizationStatus == .authorizedAlways`.

### Real-Device Validation Protocol

REC requirements cannot be verified in a simulator. The plan must include a validation task requiring a physical device test:
1. Grant Always Location in Settings
2. Walk out of home, wait 5 minutes, return
3. Kill app from App Switcher
4. Walk to a different building
5. App should relaunch (verify via `BackgroundTaskManager.lastRecordedDate`)
6. Open app and verify timeline shows at least 2 location events

---

## Manual Recording Assessment (MAN-01, MAN-02, MAN-03)

### MAN-01 (Mood with one tap) — Functionally complete

Two entry points both work:
- Header `heart.circle.fill` button → `viewModel.openQuickRecordComposer()`
- Bottom bar "记录此刻" CTA → same

`QuickRecordSheet` renders `LazyVGrid` 3-column mood grid with `.easeInOut(0.15)` selection animation — matches UI-SPEC.

**Remaining work:** Typography correction only — sheet title uses `28pt` (should be `23pt`).

### MAN-02 (Text/voice/photo capture) — Text and photo complete; voice path incomplete

`QuickRecordSheet` has:
- `TextField` for note text — implemented
- `PhotosPicker` max 3 images — implemented
- Photo thumbnails at 88pt × 88pt, corner 18pt — matches UI-SPEC

`VoiceRecordView.swift` exists (uses `AVFoundation` + `Speech`) but is **not wired into `QuickRecordSheet`**. The UI-SPEC copywriting contract does not mention voice as a required UI element in `QuickRecordSheet` — MAN-02 says "text/voice/photo." Given REQUIREMENTS.md phrasing "via text/voice/photo (shutter)" and the spec's absence of a voice UI element in the QuickRecordSheet component inventory, voice can be deferred or added as a secondary action. This needs a decision from the planner.

**Recommendation:** Text + photo satisfy MAN-02 for MVP. Voice can be added in a later polish pass if scope allows.

### MAN-03 (Manual records inline on timeline) — Functionally complete

`makeTimelineItems` in `DayVerticalTimelineContent` correctly:
- Segregates mood events from canvas events
- Inserts mood rows inline in chronological order
- Splits quiet gaps when mood events fall inside them

`moodRow` renders as a capsule shape distinct from event cards — correct differentiation. Minimum height 38pt (close to 44pt minimum touch target — may need correction to `minHeight: 44`).

---

## History Screen Assessment (TML-06)

`HistoryScreen` is substantially complete. Gaps:

1. **Date header typography:** Uses `.title2.bold()` (UIKit system shorthand, ~22pt bold). UI-SPEC requires `23pt regular serif` (heading tier). Replace with explicit `.system(size: 23, weight: .regular, design: .serif)`.

2. **Metric card values:** Use `26pt bold`. UI-SPEC requires `23pt semibold rounded` for metric tiles. Also, metric cards should use `.appShadow(.subtle)` instead of inline `.shadow(color:radius:x:y:)` calls.

3. **Insight section title "生活脉搏":** Uses `18pt bold`. Should be `15pt semibold` (body tier). The whole `insightSection` function inlines `DashboardViewModel` — this is fine architecturally.

4. **`recordingStatusBar` font sizes:** `12pt semibold` for status text matches UI-SPEC. Status text uses `Color.green` (system) rather than `AppColor.*` — acceptable per spec (recording indicator is system semantic green, not a warm palette token).

5. **`EventAnnotationSheet`** exists (`EventAnnotationSheet.swift`) — used by `HistoryScreen` for annotation. This is a separate file from `AnnotationSheet.swift` used by `TodayScreen`. Both should exist; `HistoryScreen` uses the correct one.

---

## Architecture Patterns

The phase requires no new architectural patterns. Existing patterns are the correct ones:

```
Views own no business logic
ViewModels are @MainActor final class : ObservableObject
Data types are value types (struct)
```

### Adding New View Components

If an `AnnotationSheet` content change is needed:
- Edit existing `AnnotationSheet.swift` — do not create a third variant
- `AnnotationSheet` should receive `event: InferredEvent` and return `title: String`

### Duration-Proportional Row Heights

The `rowHeight(for:)` function in `DayVerticalTimelineContent` is used by `currentTimeOffset` computation. When changing `eventRowHeight(for:)` to be proportional, `rowHeight(for:)` must stay synchronized. The correct pattern:

```swift
// rowHeight already delegates to eventRowHeight — just update eventRowHeight
private func rowHeight(for item: TimelineItem) -> CGFloat {
    switch item.content {
    case let .event(event):
        return eventRowHeight(for: event) + 6  // +6 for vertical padding
    case let .quietGap(_, _, durationMinutes):
        return gapHeight(durationMinutes)
    case .mood:
        return 44
    }
}
```

The `+6` constant for event rows matches the `.padding(.vertical, 3)` on each side of `standardEventRow`. Do not change this relationship.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| Reverse geocoding | Custom geocoding network call | `CLGeocoder.reverseGeocodeLocation` (already used) |
| Activity type detection | Custom accelerometer ML | `CMMotionActivityManager.queryActivityStarting` (already used) |
| Background app relaunch on location change | Custom background polling | `CLLocationManager.startMonitoringSignificantLocationChanges()` (already used) |
| Photo import | Custom PHAsset fetching | `PhotosPicker` from PhotosUI (already used) |
| Sheet presentation | Custom overlay modal | SwiftUI `.sheet(item:)` with detents (already used) |

**Key insight:** The project has zero external dependencies by design. All recording and UI primitives are Apple frameworks. Never introduce SPM packages to solve problems Apple frameworks already solve.

---

## Common Pitfalls

### Pitfall 1: Changing `eventRowHeight` Without Updating `currentTimeOffset`

**What goes wrong:** The current-time needle position is computed by summing `rowHeight(for:)` for all items above the current time. If `eventRowHeight` changes but the needle calculation uses a stale height assumption, the needle renders at the wrong position.

**How to avoid:** Always run through the needle logic after changing row heights. The mock data in `MockTimelineDataProvider` has fixed timestamps — write a quick mental trace with a known event at 9:00 AM and verify needle placement.

**Warning signs:** Needle appears at top of a card instead of proportionally within it.

### Pitfall 2: `CLGeocoder` Rate Limit in PlaceManager

**What goes wrong:** `resolveUnnamedPlaces()` is called on every `loadTimeline(for:)` call. If a user has 15 unresolved places, each opening of the timeline triggers 15 geocode calls. Apple limits geocoding to ~50 requests/hour.

**How to avoid:** The `KnownPlace.name` field being non-nil should gate whether geocoding runs. Verify `resolveUnnamedPlaces()` only geocodes places where `name == nil`. This is the current implementation — preserve it.

**Warning signs:** Place names show as nil after multiple app opens on a day with many visits.

### Pitfall 3: Using `TodayTheme.*` in New Code

**What goes wrong:** `TodayTheme` is a compatibility shim. CLAUDE.md states new code must use `AppColor.*` directly.

**How to avoid:** After editing a file, grep it for `TodayTheme.` — if any new lines were added with `TodayTheme`, replace with `AppColor.*`.

**Warning signs:** `TodayTheme.teal` appears in a new function or in a modified block.

### Pitfall 4: `AppSpacing.xxxs` (2pt) is Excluded from UI-SPEC

**What goes wrong:** `AppSpacing.xxxs = 2` exists in `TodayTheme.swift` but the UI-SPEC contract explicitly removes it. "2pt is not a multiple of 4."

**How to avoid:** The minimum spacing unit in Phase 3 views is `AppSpacing.xxs` (4pt). The only permitted sub-4pt literal is `1` for separator line widths.

### Pitfall 5: Build Breaks from File Changes Without `xcodegen generate`

**What goes wrong:** Adding or removing `.swift` files without regenerating the Xcode project causes build failures because the `.xcodeproj` file list is stale.

**How to avoid:** Any task that adds or removes files must include `cd ios/ToDay && xcodegen generate` as its first step. Tasks that only edit existing files do not need `xcodegen generate`.

---

## Code Examples

### Correct Font Call Pattern (UI-SPEC compliant)

```swift
// Source: 03-UI-SPEC.md Typography table

// Hero tier (screen title only)
.font(.system(size: 33, weight: .regular, design: .serif)).italic()

// Heading tier (card titles, section headings, sheet titles, EventDetailView event name)
.font(.system(size: 23, weight: .regular, design: .serif)).italic()

// Body tier — semibold variant (event names, primary body text)
.font(.system(size: 15, weight: .semibold))

// Body tier — regular variant (AI summary text, descriptive body)
.font(.system(size: 15))

// Small tier — monospaced (timestamps, badges, duration, captions)
.font(.system(size: 12, weight: .regular, design: .monospaced))

// Small tier — monospaced semibold (badge labels that need emphasis)
.font(.system(size: 12, weight: .semibold, design: .monospaced))
```

### Correct Shadow Application

```swift
// Source: 03-UI-SPEC.md Shadows + AppShadow in TodayTheme.swift

// For cards (EventCardView, ContentCard, metric tiles):
.appShadow(.subtle)  // warm brown 6%, radius 8, y 2

// For floating elements (bottom action bar, sheets):
.appShadow(.elevated)  // warm brown 10%, radius 16, y 4

// NEVER:
.shadow(color: Color.primary.opacity(0.06), ...)  // cold neutral shadow — forbidden
```

### Correct AppRadius Usage for Event Cards

```swift
// Source: 03-UI-SPEC.md Corner Radii table
// Event cards → AppRadius.lg (16pt)
.clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
.overlay(
    RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
        .stroke(...)
)
```

### Proportional Event Row Height

```swift
// Source: 03-UI-SPEC.md DayVerticalTimelineContent upgrade contract
private func eventRowHeight(for event: InferredEvent) -> CGFloat {
    let durationMinutes = max(Int(event.duration / 60), 1)
    let proportional = CGFloat(durationMinutes) * 0.5
    let base = max(44, min(180, proportional))
    if event.kind == .sleep,
       let stages = event.associatedMetrics?.sleepStages,
       !stages.isEmpty {
        return max(base, 92)
    }
    return base
}
```

---

## Environment Availability

This phase has no new external dependencies. All frameworks are already in the project.

| Dependency | Required By | Available | Notes |
|------------|-------------|-----------|-------|
| CoreLocation | REC-01, REC-06 | System framework | Background monitoring requires physical device |
| CoreMotion | REC-02 | System framework | Simulator returns empty activity data |
| CLGeocoder | REC-04 | System framework | Rate-limited; not testable offline |
| PhotosUI | MAN-02 | System framework | Already linked |
| XcodeGen 2.45+ | Build | Must be installed on dev machine | Run `xcodegen generate` before each build |

**REC-01 through REC-06 cannot be validated in a simulator.** A physical iPhone with `Always Location` granted is required for real-device testing.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest |
| Config file | `ios/ToDay/project.yml` (test target: `ToDayTests`) |
| Quick run command | `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "(Test Suite|PASSED|FAILED|error:)"` |
| Full suite command | Same as above — all 180+ tests in `ToDayTests` |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | Notes |
|--------|----------|-----------|-------------------|-------|
| TML-01 | Gradient background renders with correct color stops | Build | Build pass | No unit test needed — visual |
| TML-02 | Event badge/duration/place name displayed correctly | Unit | `PhoneInferenceEngineTests` covers event structure | Font changes are visual-only |
| TML-03 | Tap event opens EventDetailView | Manual | — | SwiftUI sheet interaction not unit-testable |
| TML-04 | Tap blank period opens AnnotationSheet | Manual | — | Same |
| TML-05 | Visual quality per .impeccable.md | Manual | — | Requires device/preview inspection |
| TML-06 | History date navigation | Manual | — | `loadSelectedDay()` path tested via `PhoneTimelineDataProviderTests` |
| REC-01 | Background location visit recorded | Manual (device) | — | Requires physical device + Always Location |
| REC-02 | Activity type detected | Unit | `MotionCollectorTests.swift` | Already exists |
| REC-03 | Events inferred correctly | Unit | `PhoneInferenceEngineTests.swift` | 180+ tests, already passing |
| REC-04 | Place geocoded | Unit | `PlaceManagerTests.swift` | Already exists |
| REC-05 | Place classified home/work/frequent | Unit | `PlaceManagerTests.swift` | Already exists |
| REC-06 | Survives app kill | Manual (device) | — | Cannot automate background relaunch |
| MAN-01 | Mood recorded via one tap | Manual | — | QuickRecordSheet flow |
| MAN-02 | Text + photo moment saved | Manual | — | QuickRecordSheet flow |
| MAN-03 | Manual records inline on timeline | Unit | Add test to `DayScrollViewTests` or inline in plan | See Wave 0 gaps below |

### Sampling Rate

- **Per task commit:** `cd ios/ToDay && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5`
- **Per wave merge:** Full test suite — `xcodebuild test` with 180+ tests green
- **Phase gate:** Full suite green + manual device validation of REC-01, REC-06, MAN-01 before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] No test file covers `DayVerticalTimelineContent` logic (timeline item assembly, mood interleaving, gap splitting). New test `ToDayTests/DayScrollViewTests.swift` should cover: (a) mood event interleaves correctly between canvas events, (b) quiet gap splits when mood falls inside it, (c) `eventRowHeight` clamps to 44pt minimum.

*(All existing test infrastructure covers REC-02 through REC-05 — no test framework changes needed.)*

---

## Standard Stack

No new libraries. All work uses existing project dependencies.

| Framework | Purpose | Notes |
|-----------|---------|-------|
| SwiftUI | All UI views | iOS 17+ features in use (`.sheet(item:)`, `.presentationDetents`, `.safeAreaInset`) |
| CoreLocation | Location visits + significant changes | Already wired |
| CoreMotion | Activity recognition | Already wired |
| SwiftData | Persistent storage | Already wired |
| XCTest | Unit tests | 180+ tests already passing |

**Installation:** None required.

---

## State of the Art

| Old Approach | Current Approach | Impact for Phase 3 |
|--------------|------------------|--------------------|
| `TodayTheme.*` tokens | `AppColor.*` tokens (new standard) | New code in Phase 3 must use `AppColor.*` — `TodayTheme` is a shim |
| Fixed event row heights | Proportional to duration (UI-SPEC requirement) | Core visual change needed in `eventRowHeight(for:)` |
| `14pt` body text in descriptions | `15pt` body tier (UI-SPEC consolidation) | Multiple description text strings need update |
| Mixed font weights (medium, bold) | Two weights only: regular (400) + semibold (600) | Remove `.bold()` from badge/duration text |

**Deprecated:**
- `AppSpacing.xxxs` (2pt): Removed from UI-SPEC. Do not use in Phase 3 code.
- `TodayTheme.*` token names: Do not add new usages. Replace on touch in files being edited.

---

## Open Questions

1. **Voice recording in QuickRecordSheet (MAN-02)**
   - What we know: `VoiceRecordView.swift` exists with full AVFoundation + Speech implementation. `QuickRecordSheet` does not expose it.
   - What's unclear: Does MAN-02 require voice in MVP, or is text + photo sufficient?
   - Recommendation: Text + photo satisfy the letter of MAN-02. If voice is required, add a microphone button to `QuickRecordSheet` that presents `VoiceRecordView` as a child sheet. This is a contained change but adds scope.

2. **`moodRow` minimum touch target**
   - What we know: `moodRow` sets `minHeight: 38`. UI-SPEC mandates 44pt minimum touch target.
   - What's unclear: Whether 38pt was intentional (compact mood row) or an oversight.
   - Recommendation: Change to `minHeight: 44` — a two-character fix, clearly correct per iOS HIG.

3. **DeviceStateCollector startup wiring for sleep inference**
   - What we know: Sleep inference in `PhoneInferenceEngine` depends on `.deviceState` sensor readings. `DeviceStateCollector` must be running to capture screen lock/unlock events.
   - What's unclear: Whether `DeviceStateCollector` is actually started in `ToDayApp.task` or `AppContainer`.
   - Recommendation: The plan for REC-03 should include a verification step confirming `DeviceStateCollector.startMonitoring()` is called at app launch.

---

## Sources

### Primary (HIGH confidence)

- Source code direct inspection — `DayScrollView.swift`, `EventCardView.swift`, `TodayScreen.swift`, `QuickRecordSheet.swift`, `HistoryScreen.swift`, `TodayTheme.swift`, `LocationCollector.swift`, `MotionCollector.swift`, `PlaceManager.swift`, `PhoneInferenceEngine.swift`, `PhoneTimelineDataProvider.swift`
- `03-UI-SPEC.md` — design contract (generated by gsd-ui-researcher from `.impeccable.md` + source)
- `REQUIREMENTS.md` — requirement definitions
- `CLAUDE.md` (project) — tech stack, conventions, build commands

### Secondary (MEDIUM confidence)

- Apple Developer Documentation (CLGeocoder rate limits ~50 req/hour) — from training data, consistent with behavior documented across iOS versions

---

## Metadata

**Confidence breakdown:**
- Typography gaps: HIGH — found by direct diff of source vs. UI-SPEC
- Architecture patterns: HIGH — existing codebase patterns
- Recording pipeline: HIGH (implementation) / MEDIUM (real-device behavior) — pipeline exists and is unit-tested; actual background behavior on physical hardware is unverified
- Pitfalls: HIGH — derived from actual code patterns found in source

**Research date:** 2026-04-04
**Valid until:** 2026-05-04 (30 days — stable SwiftUI/CoreLocation APIs)
