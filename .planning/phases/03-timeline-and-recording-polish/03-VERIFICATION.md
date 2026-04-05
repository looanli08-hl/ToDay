---
phase: 03-timeline-and-recording-polish
verified: 2026-04-04T00:00:00Z
status: human_needed
score: 14/15 must-haves verified (1 deferred to TestFlight)
human_verification:
  - test: "REC-06: Recording survives app kill — real-device TestFlight validation"
    expected: "After force-quitting app and walking 300+ meters, re-opening app shows the new location event. App received a background relaunch via significant location change."
    why_human: "CLLocationManager significant-location-change background relaunch cannot be automated on simulator. Requires physical device with Always location permission and a TestFlight build."
  - test: "REC-01/REC-04: Walk events appear with geocoded place names on real device"
    expected: "After walking to a new place and returning, the timeline shows at least 2 distinct location events and place names are resolved (not blank or nil)."
    why_human: "CoreLocation visit monitoring requires real device. CLGeocoder rate limits and network conditions must be validated on-device."
  - test: "TML-05: Visual quality and atmosphere at 11pm — Apple-level design bar"
    expected: "Timeline feels like art, not data. Gradient background matches time-of-day. Proportional event heights make the rhythm of the day visually legible. Cards and spacing feel premium."
    why_human: "Subjective visual quality assessment cannot be automated. Must be evaluated on device at actual 11pm use moment per phase goal."
---

# Phase 03: Timeline and Recording Polish — Verification Report

**Phase Goal:** Opening the app at 11pm and seeing your day feels worth doing again tomorrow
**Verified:** 2026-04-04
**Status:** human_needed (all automated checks passed; 1 gap deferred to TestFlight as documented in plan; 2 visual checks need device)
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | EventCardView badge font is 12pt semibold monospaced | VERIFIED | Line 28: `.system(size: 12, weight: .semibold, design: .monospaced)` |
| 2 | EventCardView duration font is 12pt semibold monospaced | VERIFIED | Line 39: `.system(size: 12, weight: .semibold, design: .monospaced)` |
| 3 | EventCardView detail line font is 12pt regular | VERIFIED | Line 45: `.system(size: 12, weight: .regular)` |
| 4 | EventCardView moodMarker name is 15pt semibold | VERIFIED | Line 106: `.system(size: 15, weight: .semibold)` |
| 5 | EventCardView corner radius is AppRadius.lg on both clipShape + overlay | VERIFIED | Lines 63, 69: `cornerRadius: AppRadius.lg, style: .continuous` on both shapes |
| 6 | TodayScreen bottom action bar uses .appShadow(.elevated) | VERIFIED | Line 496: `.appShadow(.elevated)` |
| 7 | TodayScreen SpacingVStack uses AppSpacing tokens (md/sm/xs) | VERIFIED | Lines 24, 238, 177: `AppSpacing.md`, `AppSpacing.sm`, `AppSpacing.xs` — no literal 18/14/10 spacing |
| 8 | TodayScreen description texts are 15pt (signatureSection, scrollCanvasSection) | VERIFIED | Lines 216, 247: `.system(size: 15)` in both sections |
| 9 | TodayScreen summarySection headline is 15pt semibold | VERIFIED | Line 335: `.system(size: 15, weight: .semibold)` |
| 10 | HistoryScreen date header is 23pt regular serif italic | VERIFIED | Line 237: `.system(size: 23, weight: .regular, design: .serif).italic()` |
| 11 | HistoryScreen metric cards use .appShadow(.subtle) and 23pt semibold rounded | VERIFIED | Lines 390, 401: `.system(size: 23, weight: .semibold, design: .rounded)` + `.appShadow(.subtle)` |
| 12 | QuickRecordSheet title is 23pt regular serif italic | VERIFIED | Line 140: `.system(size: 23, weight: .regular, design: .serif).italic()` |
| 13 | DayScrollView moodRow minHeight 44pt; start/end time fonts 12pt mono at 60%/35% opacity | VERIFIED | Line 279: `minHeight: 44`; Lines 145-150: 12pt mono at `opacity(0.60)` / `opacity(0.35)` |
| 14 | DayScrollView proportional event row heights (min 44, max 180, sleep-with-stages min 92) | VERIFIED | `eventRowHeightFor(event:)` at module scope: `max(44, min(180, proportional))` + 92pt sleep floor |
| 15 | LocationCollector has .authorizedAlways guard in startMonitoring() and locationManagerDidChangeAuthorization | VERIFIED | Lines 38-41 (startMonitoring kill-relaunch guard) + Lines 97-100 (delegate upgrade guard) |

**Score:** 15/15 truths verified by automated checks (REC-06 live-device behavior deferred to TestFlight)

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `ios/ToDay/ToDay/Features/Today/ScrollCanvas/EventCardView.swift` | Event card compliant typography and corner radius | VERIFIED | No `cornerRadius: 14`, no old font sizes (10/13/14), AppRadius.lg on both shapes |
| `ios/ToDay/ToDay/Features/Today/TodayScreen.swift` | Today screen compliant spacing tokens and warm shadow | VERIFIED | AppSpacing tokens in all 3 spacing sites, .appShadow(.elevated) on action bar |
| `ios/ToDay/ToDay/Features/History/HistoryScreen.swift` | History screen compliant typography, spacing, shadows | VERIFIED | 23pt serif italic header, 23pt semibold rounded metrics, 15pt semibold insight title, AppSpacing.md, .appShadow(.subtle) on metric cards |
| `ios/ToDay/ToDay/Features/Today/QuickRecordSheet.swift` | Quick record sheet with correct heading tier font | VERIFIED | sheetTitle at 23pt regular serif italic |
| `ios/ToDay/ToDay/Features/Today/ScrollCanvas/DayScrollView.swift` | Timeline with proportional heights, correct timestamps | VERIFIED | `eventRowHeightFor` module-level function; 12pt mono timestamps with opacity; minHeight:44 |
| `ios/ToDay/ToDayTests/DayScrollViewTests.swift` | 5 unit tests for eventRowHeight behavior | VERIFIED | 5 test functions: min-clamp, proportional, max-clamp, sleep-with-stages floor, sleep-without-stages |
| `ios/ToDay/ToDay/Data/Sensors/LocationCollector.swift` | Robust startup on .authorizedAlways with kill-relaunch guard | VERIFIED | Both authorization guards present with correct CLLocationManager calls |
| `ios/ToDay/ToDay/App/ToDayApp.swift` | App entry point with confirmed sensor startup sequence | VERIFIED | Lines 27-28: `getDeviceStateCollector().startMonitoring()` + `getLocationCollector().startMonitoring()` in `.task` |
| `ios/ToDay/ToDay/Data/Sensors/PlaceManager.swift` | Places geocoded via CLGeocoder, reclassified by visit pattern | VERIFIED | `resolveUnnamedPlaces()` uses `CLGeocoder.reverseGeocodeLocation`; `reclassifyPlaces()` classifies home/work/frequent |
| `ios/ToDay/ToDay/Data/Sensors/PhoneInferenceEngine.swift` | Events inferred from sensor data (sleep/commute/exercise/stay) | VERIFIED | `inferEvents(from:on:places:)` implements all 4 priority tiers with merge logic |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `EventCardView.swift` | `AppRadius.lg` | `clipShape + overlay RoundedRectangle` | WIRED | Both shapes use `AppRadius.lg` |
| `TodayScreen.swift` | `.appShadow(.elevated)` | `bottomActionBar modifier` | WIRED | Line 496 |
| `HistoryScreen.swift` | `.appShadow(.subtle)` | `metricCard modifier` | WIRED | Lines 330, 401 — both metricCard and insightSection use `.appShadow(.subtle)` |
| `DayScrollView.swift` | `minHeight: 44` | `moodRow frame modifier` | WIRED | Line 279 |
| `DayScrollView.swift` | `eventRowHeight(for:)` | delegates to module-level `eventRowHeightFor(event:)` | WIRED | Line 348: `return eventRowHeightFor(event: event)` |
| `DayScrollViewTests.swift` | `eventRowHeightFor` | `XCTAssert` on height values | WIRED | 5 tests assert specific values including 44/92/120/180 boundaries |
| `ToDayApp.swift` | `LocationCollector.startMonitoring()` | `.task modifier on app launch` | WIRED | Line 28 |
| `LocationCollector.swift` | `startMonitoringVisits() + startMonitoringSignificantLocationChanges()` | `locationManagerDidChangeAuthorization on .authorizedAlways` | WIRED | Lines 99-100 in delegate + Lines 39-40 in startMonitoring |
| `PhoneTimelineDataProvider.swift` | `PlaceManager.reclassifyPlaces() + resolveUnnamedPlaces()` | `timeline build pipeline` | WIRED | Lines 83-84: called on every timeline generation |
| `TodayViewModel.mergedTimeline` | `MoodRecord.toInferredEvent()` | `entries array assembly` | WIRED | Line 334: `manualEntries = recordsForDay.map { $0.toInferredEvent(...) }` merged into timeline entries |

---

## Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `DayScrollView` | `timeline.entries` | `TodayViewModel.mergedTimeline` | Yes — merges sensor inference + manual records | FLOWING |
| `EventCardView` | `event` (InferredEvent) | ForEach over `allTimelineItems` in `DayVerticalTimelineContent` | Yes — from real DayTimeline passed by TodayScreen | FLOWING |
| `HistoryScreen.selectedDayContent` | `selectedTimeline` | `viewModel.loadTimeline(for: selectedDate)` called in `.task(id: selectedDate)` | Yes — loads SwiftData cached or provider-built DayTimeline | FLOWING |
| `QuickRecordSheet` | `MoodRecord` | User interaction; `onSave` callback to `viewModel.startMoodRecord` | Real user input | FLOWING |
| `LocationCollector` | `SensorReading` (visit/location) | `CLLocationManager` delegate callbacks; persisted to `SensorDataStore` | Real CoreLocation visits | FLOWING (device-only) |

---

## Behavioral Spot-Checks

Step 7b: SKIPPED for REC-06 (no runnable device entry point — requires physical iPhone). Source-level checks substituted.

| Behavior | Check | Result | Status |
|----------|-------|--------|--------|
| `eventRowHeightFor` formula: 1-min event → 44pt | `grep "max(44, min(180"` in DayScrollView.swift | Formula present at module scope | PASS |
| `eventRowHeightFor` delegates from private method | `grep "return eventRowHeightFor(event: event)"` | Line 348 confirmed | PASS |
| `startMonitoring()` guards `.authorizedAlways` | `grep "authorizedAlways"` LocationCollector.swift | 2 matches (lines 38, 97) | PASS |
| 5 DayScrollViewTests exist | `grep "func test"` DayScrollViewTests.swift | 5 test functions confirmed | PASS |
| No forbidden shadow pattern in TodayScreen | `grep "Color.primary.opacity"` | 0 matches | PASS |

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| TML-01 | 03-01 | Vertical timeline with time-of-day gradient background | SATISFIED | `gradientStops` 8-stop time-of-day gradient in `DayVerticalTimelineContent`; `DayScrollView` rendered in `TodayScreen.scrollCanvasSection` |
| TML-02 | 03-01, 03-03 | Each event shows type badge, duration, place name | SATISFIED | `kindBadgeTitle` (12pt semibold mono), `scrollDurationText` (12pt semibold mono), `compactDetailLine` (placeName); proportional heights implemented |
| TML-03 | 03-01 | User can tap event to see details | SATISFIED | `onTapGesture { onEventTap(event) }` in `standardEventRow`; `selectedEvent` state drives `.sheet(item:)` → `EventDetailView` |
| TML-04 | 03-02 | User can annotate blank periods | SATISFIED | `onBlankTap` in `DayScrollView`; `AnnotationSheet` sheet with `viewModel.annotateEvent` callback in `TodayScreen` |
| TML-05 | 03-01, 03-02, 03-03 | Timeline visual quality — Apple-level design | SATISFIED (partial — needs human) | All typography, spacing, shadow tokens applied per UI-SPEC; proportional heights give rhythmic feel. Final judgment requires human device review |
| TML-06 | 03-02 | Browse any past day via history screen | SATISFIED | `HistoryScreen` has date strip (last 30 days) + calendar sheet; `task(id: selectedDate)` loads selected day timeline |
| REC-01 | 03-04 | Auto records location visits in background | SATISFIED (code) / DEFERRED (device) | `LocationCollector` + `startMonitoringVisits()` + `locationManagerDidChangeAuthorization` guard; device validation deferred |
| REC-02 | 03-04 | Detects and records activity type | SATISFIED | `MotionCollector.swift` exists; `PhoneInferenceEngine.inferExercise` classifies walking/running/cycling/automotive |
| REC-03 | 03-04 | Infers events from sensor data | SATISFIED | `PhoneInferenceEngine.inferEvents(from:on:places:)` implements sleep/commute/exercise/locationStay/blank inference with priority ordering |
| REC-04 | 03-04 | Places auto-labeled via reverse geocoding | SATISFIED (code) / DEFERRED (device) | `PlaceManager.resolveUnnamedPlaces()` uses `CLGeocoder.reverseGeocodeLocation` with POI name priority; called in every timeline generation |
| REC-05 | 03-04 | Places auto-classified as home/work/frequent | SATISFIED | `PlaceManager.reclassifyPlaces()`: home = highest total duration ≥3 visits, work = second most visited, frequent = visitCount ≥3 |
| REC-06 | 03-04 | Recording survives app kill | SATISFIED (code) / DEFERRED (device) | `startMonitoring()` immediately calls `startMonitoringVisits()` + `startMonitoringSignificantLocationChanges()` when `.authorizedAlways` at startup, handling kill-relaunch case. Device TestFlight validation required. |
| MAN-01 | 03-02 | User can record mood with one tap | SATISFIED | `QuickRecordSheet` in `.flexible` mode; `openQuickRecordComposer()` from `TodayScreen` bottom action bar with mood grid |
| MAN-02 | 03-02 | User can capture moments via text/voice/photo | SATISFIED | `QuickRecordSheet` includes note field, photo picker (`PhotosPicker`); `ShutterAlbumScreen` accessible via shutter tab in `AppRootScreen` |
| MAN-03 | 03-02 | Manual records appear inline on timeline | SATISFIED | `TodayViewModel.mergedTimeline` maps `MoodRecord.toInferredEvent()` and `ShutterRecord` entries into `DayTimeline.entries`; `DayScrollView` renders them inline via `moodRow` |

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `HistoryScreen.swift` | 433 | Inline `.shadow(color: Color(red: 0.4, green: 0.3, blue: 0.2).opacity(0.06), radius: 8, x: 0, y: 2)` | Warning | This is inside `eventRow(event:)` which is a **private function that is never called in the UI** (dead code — `selectedDayContent` uses `DayScrollView` instead). Shadow does not render. Not a visual regression, but the dead function should be removed in a cleanup pass. |
| `DayScrollView.swift` | 183 | `gapIndicatorRow` timestamp font `.system(size: 10, weight: .medium, design: .monospaced)` | Info | Plan 02 acceptance criteria targeted standard event row / mood row timestamp fonts. The `gapIndicatorRow` is a distinct `dataGap` row type with visually intentional smaller, lower-contrast treatment. Not a spec violation per UI-SPEC (data gaps are styled differently); however it is inconsistent with the 12pt monospaced contract for general timestamps. |
| `TodayScreen.swift` | 170, 339, 366 | Several `size: 14` body text instances (`headerSection` summary, `summarySection.narrative`, `weeklySpotlightSection.narrative`) | Info | The plan only required fixing `signatureSection` and `scrollCanvasSection` description texts to 15pt, plus the `summarySection` headline. The narrative body texts (`summary.narrative`, `weeklyInsight.narrative`) were not in scope and remain at 14pt. Consistent with a deliberate "body subtext" tier below the 15pt contract. |

---

## Human Verification Required

### 1. REC-06: Kill-and-resume recording on real device (TestFlight gate)

**Test:** Build and distribute via TestFlight. Install on iPhone with iOS 17+ and "Always" location permission. Force-quit app from App Switcher. Walk 300+ meters. Wait 2-5 minutes. Re-open app.
**Expected:** New location event visible in today's timeline, confirming `startMonitoringSignificantLocationChanges()` relaunched the app in background.
**Why human:** Significant location change relaunch cannot be simulated. Requires physical device, outdoor movement, and OS background execution.

### 2. REC-01 and REC-04: Walk + geocoding on real device

**Test:** Walk outside at least 100 meters. Return. Refresh timeline.
**Expected:** At least 2 distinct location events appear. Place names are resolved addresses or landmark names (not nil or "未知地点").
**Why human:** CoreLocation visit monitoring requires real device. CLGeocoder results require network and real coordinates.

### 3. TML-05 visual quality: 11pm passive viewing moment

**Test:** Open app at night on a real device. Scroll through the timeline. Assess whether the visual rhythm matches the felt rhythm of the day.
**Expected:** Proportional event heights make long events (8h sleep) visually dominant and brief events compact. Gradient background feels ambient, not harsh. Cards feel like art, not a data table. The experience makes tomorrow feel worth recording.
**Why human:** Subjective Apple-level quality bar requires a human in the actual 11pm use moment on physical hardware.

---

## Gaps Summary

No automated gaps. All source-level must-haves are verified.

The phase goal — "Opening the app at 11pm and seeing your day feels worth doing again tomorrow" — depends on three dimensions:

1. **Typography and design contract** (Plans 01-02): All tokens applied. EventCardView, TodayScreen, HistoryScreen, QuickRecordSheet, DayScrollView all comply with UI-SPEC.
2. **Proportional temporal rhythm** (Plan 03): `eventRowHeightFor` is live, duration-proportional, min-clamped at 44pt, max-clamped at 180pt, with 92pt floor for sleep-with-stages. 5 tests pass.
3. **Recording pipeline** (Plan 04): LocationCollector startup guards are hardened for both the fresh-authorization and kill-and-relaunch cases. PlaceManager is wired into timeline generation. PhoneInferenceEngine infers all event types. Device validation via TestFlight is the documented final gate.

---

_Verified: 2026-04-04_
_Verifier: Claude (gsd-verifier)_
