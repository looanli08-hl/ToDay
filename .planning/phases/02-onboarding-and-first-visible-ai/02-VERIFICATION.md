---
phase: 02-onboarding-and-first-visible-ai
verified: 2026-04-04T15:16:20Z
status: passed
score: 8/8 requirements verified
---

# Phase 02: Onboarding and First Visible AI — Verification Report

**Phase Goal:** A new user can install the app, grant Always Location, see their day record, and read their AI insight — all within the first session
**Verified:** 2026-04-04T15:16:20Z
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 1 | User sees a value explanation screen before any system permission dialog fires | VERIFIED | `OnboardingView.swift` line 58-106: `.value` step renders `valueStepView` which advances to `.locationWhenInUse` only on button tap; no permission calls on this step |
| 2 | Location permission is requested as whenInUse first, then upgraded to Always in a second step | VERIFIED | `requestWhenInUse()` called from `.locationWhenInUse` step; `requestAlways()` only called from `.locationAlwaysUpgrade` step after `.authorizedWhenInUse` delegate callback |
| 3 | Motion permission dialog fires only after location step is resolved | VERIFIED | `.motion` step only reachable from `.locationAlwaysUpgrade` `.onChange` (`.authorizedAlways` path) or after the always-upgrade flow; never simultaneous with location |
| 4 | User who denies location sees a recovery screen with a Settings button | VERIFIED | `locationDeniedStepView` renders with `UIApplication.openSettingsURLString` primary button and "稍后设置" secondary skip button |
| 5 | `onComplete()` is only called from terminal steps (.locationDenied skip and .complete) | VERIFIED | Only two `onComplete()` call sites: `locationDeniedStepView` "稍后设置" button (line 225) and `completeStepView` "开始" button + `.task` auto-advance (lines 290, 295) |
| 6 | AI daily summary card appears on TodayScreen when DailySummaryEntity exists | VERIFIED | `TodayScreen.swift` line 38 inserts `aiDailySummarySection`; `TodayViewModel.swift` line 22 declares `@Published private(set) var aiDailySummary: DailySummaryEntity?`; `loadAIDailySummary()` called at line 118 in `load()` |
| 7 | Timeline gap periods render a labeled gap indicator row | VERIFIED | `DayScrollView.swift` line 117-120: `eventRow()` dispatches `.dataGap` events to `gapIndicatorRow()`; `SharedDataTypes.swift` line 209 has `case dataGap` |
| 8 | Privacy disclosure in Settings accurately states what data is sent to AI provider | VERIFIED | `DataExplanationView` has three sections: 本地数据, AI 功能数据处理, 数据删除; accurately names DeepSeek as the actual AI provider (which matches `DeepSeekAIProvider.swift`); old inaccurate claim "我们不上传、不收集、不分享任何个人数据" is absent |

**Score:** 8/8 truths verified

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `ios/ToDay/ToDay/Features/Onboarding/OnboardingView.swift` | Multi-step onboarding: value → location → motion → complete/denied | VERIFIED | 357-line rewrite; `OnboardingStep` enum (6 cases); `LocationPermissionCoordinator` class with stored `CLLocationManager`; `@StateObject` retained |
| `ios/ToDay/project.yml` | Specific 20+ word usage description strings | VERIFIED | `NSLocationAlwaysAndWhenInUseUsageDescription`: "Unfold passively records your location visits throughout the day to build your life timeline automatically, even when the app is closed. Always authorization is required for background recording." (30 words); `NSMotionUsageDescription` also updated to English/specific |
| `ios/ToDay/ToDay/Shared/SharedDataTypes.swift` | `EventKind.dataGap` case | VERIFIED | Line 209: `case dataGap    // periods where no sensor data was recorded` |
| `ios/ToDay/ToDay/Features/Today/TodayViewModel.swift` | `aiDailySummary` property loaded from `DailySummaryEntity` | VERIFIED | Line 22: `@Published private(set) var aiDailySummary: DailySummaryEntity?`; line 39: `private lazy var echoMemoryManager`; lines 123-126: `loadAIDailySummary()` queries `EchoMemoryManager.loadSummary(forDateKey:)` |
| `ios/ToDay/ToDay/Features/Today/TodayScreen.swift` | AI summary card rendered after timeline canvas | VERIFIED | Lines 294-321: `aiDailySummarySection` renders `ContentCard` with `aiSummary.summaryText`; line 325: `summarySection` guarded by `aiDailySummary == nil` |
| `ios/ToDay/ToDay/Features/Today/ScrollCanvas/DayScrollView.swift` | Gap indicator row for `.dataGap` events | VERIFIED | Lines 116-120: `eventRow()` dispatches to `gapIndicatorRow()` when `event.kind == .dataGap`; lines 157-190: `gapIndicatorRow()` renders "这段时间没有记录 · {duration}" labeled separator |
| `ios/ToDay/ToDay/Features/Settings/SettingsView.swift` | DataExplanationView with accurate AI data disclosure | VERIFIED | Lines 389-430: three-section `DataExplanationView`; "AI 功能数据处理" section accurately names DeepSeek |
| `.planning/APP-REVIEW-NOTES.md` | Copy-paste ready App Review Notes with Always Location explanation | VERIFIED | File exists; contains "Always authorization" explanation; reviewer test steps 1-4; AI feature disclosure for builds with AI enabled |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `OnboardingView` | `LocationPermissionCoordinator` (CLLocationManagerDelegate) | `@StateObject private var locationCoordinator` | WIRED | Line 50: `@StateObject private var locationCoordinator = LocationPermissionCoordinator()`; coordinator holds stored `CLLocationManager`; delegate retained for lifetime of view |
| `OnboardingView` step machine | `onComplete` closure | Only called from `.complete` auto-advance and `.locationDenied` skip button | WIRED | Confirmed by reading all `onComplete()` call sites — exactly two, both in terminal steps |
| `TodayViewModel.load()` | `EchoMemoryManager.loadSummary(forDateKey:)` | `loadAIDailySummary()` called inside `load()` | WIRED | Line 118: `loadAIDailySummary()` called after `hasLoadedOnce = true`; line 125: `aiDailySummary = echoMemoryManager.loadSummary(forDateKey: dateKey)` |
| `TodayScreen body` | `viewModel.aiDailySummary` | `aiDailySummarySection` rendered between `scrollCanvasSection` and `summarySection` | WIRED | Line 38: `aiDailySummarySection` inside the `timeline.entries.isEmpty` else block; line 296: `if let aiSummary = viewModel.aiDailySummary` gates rendering |
| `DayScrollView.eventRow(for:)` | `gapIndicatorRow` | `event.kind == .dataGap` branch in `eventRow` | WIRED | Lines 117-119: `if event.kind == .dataGap { return AnyView(gapIndicatorRow(...)) }` |
| `LocationCollector.locationManagerDidChangeAuthorization` | `startMonitoring()` | Only on `.authorizedAlways` case | WIRED | Lines 89-100: `switch manager.authorizationStatus` with `.authorizedAlways: startMonitoring()` and `.authorizedWhenInUse: break` — bug fixed |
| `SettingsView` "数据说明" row | `DataExplanationView` | `NavigationLink` | WIRED | Line 171: `DataExplanationView()` inside `NavigationLink` destination |
| `AppConfiguration.privacyPolicyURL` | `https://looanli08-hl.github.io/ToDay/privacy.html` | `Link` row in SettingsView | WIRED | Lines 144-150: `Link(destination: privacyPolicyURL)` renders "隐私政策" row; `AppConfiguration.privacyPolicyURL` returns the hosted URL |

---

## Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|--------------------|--------|
| `TodayScreen.aiDailySummarySection` | `viewModel.aiDailySummary` | `EchoMemoryManager.loadSummary(forDateKey:)` queries `DailySummaryEntity` via SwiftData `FetchDescriptor` | Yes — SwiftData query against persistent store; section is data-gated (renders only when entity exists) | FLOWING |
| `DayScrollView.gapIndicatorRow` | `event.kind == .dataGap` events from timeline | `DayTimeline.entries` filtered in `makeCanvasEvents`; `.dataGap` events not filtered (only `.mood` is excluded) | Yes — real events from timeline; if no `.dataGap` events exist the row simply doesn't appear (correct behavior) | FLOWING |

---

## Behavioral Spot-Checks

Step 7b: SKIPPED — iOS SwiftUI app with no CLI/API entry points runnable without simulator. Visual behavior requires human verification (see Human Verification Required section below).

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| ONB-01 | 02-01-PLAN.md | User guided through Location "Always" permission with value explanation before dialog | SATISFIED | `.value` step renders before any permission call; two-step location pattern implemented |
| ONB-02 | 02-01-PLAN.md | User guided through Motion permission with value explanation | SATISFIED | `.motion` step shows `figure.walk` icon, explanation text, then triggers `CMMotionActivityManager` query |
| ONB-03 | 02-01-PLAN.md | Permission denial handled gracefully with path to Settings | SATISFIED | `.locationDenied` step with `UIApplication.openSettingsURLString` button present |
| ONB-04 | 02-01-PLAN.md | App Store usage description strings specific enough to pass App Review | SATISFIED | `NSLocationAlwaysAndWhenInUseUsageDescription` is 30 words describing background recording specifically |
| AIS-03 | 02-02-PLAN.md | Summary displayed prominently on the today screen | SATISFIED | `aiDailySummarySection` renders a `ContentCard` with "Echo 今日洞察" eyebrow, serif title, and `summaryText` body text after the timeline canvas |
| REC-07 | 02-02-PLAN.md | Data gaps from force-quit/airplane mode displayed gracefully, not hidden | SATISFIED | `EventKind.dataGap` exists; `gapIndicatorRow` renders "这段时间没有记录 · {duration}" for gap events |
| PRV-02 | 02-03-PLAN.md | Privacy policy page exists and accessible from app settings | SATISFIED | `DataExplanationView` updated with accurate three-section disclosure; "隐私政策" Link row present at line 144 pointing to hosted URL |
| PRV-03 | 02-03-PLAN.md | App Review Notes explain Always Location usage clearly | SATISFIED | `.planning/APP-REVIEW-NOTES.md` exists with copy-paste reviewer template covering Always Location justification and AI feature disclosure |

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `SettingsView.swift` line 409 | — | `DataExplanationView` names "DeepSeek" as AI provider; plan acceptance criteria expected "Anthropic"/"AIProxy" | INFO | The disclosure is accurate to the actual `DeepSeekAIProvider.swift` in the codebase. The plan's acceptance criteria were wrong about which AI provider is used. PRV-02 requires accurate disclosure — "DeepSeek" is more accurate than "Anthropic/AIProxy" which are not in the codebase. Not a defect. |
| `OnboardingView.swift` completeStepView | Lines 289-296 | `.task` auto-advances to `onComplete()` after 1.5s AND "开始" button calls `onComplete()` — double invocation possible if user taps before auto-advance fires | WARNING | If user taps "开始" before the 1.5s sleep completes, `onComplete()` is called once from the button and once from the `.task`. The `AppRootScreen` gate uses `@AppStorage("today.hasCompletedOnboarding")` which is idempotent, so double-fire is harmless but non-ideal. Does not block goal achievement. |

No STUB patterns, no TODO/FIXME markers, no empty `return null` returns found in phase-modified files.

---

## Human Verification Required

### 1. Onboarding Two-Step Location Flow on Physical Device

**Test:** Install fresh build on device. Tap "探索 Unfold" on value screen. Tap "允许位置访问". When iOS dialog appears, grant "While Using". Verify app advances to "开启后台记录" screen (not to motion/complete). Tap "继续". When second iOS dialog appears, tap "Always Allow". Verify app advances to motion step.
**Expected:** App shows three distinct screens before motion step; second system dialog shows "Always Allow" option.
**Why human:** iOS 17 only shows "Always Allow" in the upgrade dialog if "When In Use" was already granted — this sequence cannot be verified by reading code alone.

### 2. AI Summary Card Display End-to-End

**Test:** Ensure a `DailySummaryEntity` exists for today (via Echo pipeline or direct SwiftData insert). Open TodayScreen. Verify "Echo 今日洞察" card appears below the timeline canvas. Verify algorithmic "今日总结" section does NOT appear simultaneously.
**Expected:** Single AI summary card visible; no duplicate summary card.
**Why human:** `aiDailySummarySection` only renders when `DailySummaryEntity` exists — requires Phase 1 Echo pipeline to have run, or a test fixture insert. Cannot verify rendering behavior without running the app.

### 3. Gap Indicator Row Visual

**Test:** On simulator with mock data, inject an event with `kind == .dataGap` into the timeline. Verify the gap row renders as a lightweight dashed separator with "这段时间没有记录 · {duration}" text, not as a full event card.
**Expected:** Muted gray dashed separator row, distinctly lighter than regular event cards.
**Why human:** Visual quality assessment ("lightweight, not a full card") requires seeing the rendered output.

### 4. DataExplanationView Sections in Settings

**Test:** Build and run. Go to Settings tab. Scroll to "隐私与支持" section. Tap "数据说明". Verify three sections: "本地数据", "AI 功能数据处理", "数据删除". Verify "隐私政策" external link row is present and opens the hosted privacy policy URL.
**Expected:** Three labeled sections visible; old "不上传、不收集、不分享任何个人数据" text absent; Link row opens browser to privacy policy.
**Why human:** NavigationLink rendering and Link row URL-open behavior require running the simulator.

---

## Notable Implementation Observations

**Plan-vs-implementation divergence (non-blocking):** The 02-03 PLAN acceptance criteria specified `grep "Anthropic"` and `grep "AIProxy"` would match in SettingsView. The actual implementation correctly uses "DeepSeek" (matching the real `DeepSeekAIProvider.swift` provider). The SUMMARY.md claim of "no deviations" is inaccurate — the text was changed from the plan's proposed content. However, the underlying requirement (PRV-02: accurate disclosure) is better served by the actual implementation, which names the real provider. This is a quality improvement, not a defect.

**LocationCollector fix verified:** `locationManagerDidChangeAuthorization` uses a `switch` statement with only `.authorizedAlways: startMonitoring()` — the `.authorizedWhenInUse` case explicitly breaks. The original bug (starting monitoring on `whenInUse`) is confirmed resolved.

**dataGap rendering path confirmed:** `.dataGap` events are not excluded from `makeCanvasEvents` (only `.mood` is filtered at line 379). They reach `makeTimelineItems` as regular events (not blank candidates since `isBlankCandidate` only checks `.quietTime || confidence <= .low`). They then flow to `eventRow()` which dispatches to `gapIndicatorRow()`. The full path is wired.

---

## Gaps Summary

No gaps. All 8 requirements verified. All artifacts exist, are substantive, and are wired. No blocker anti-patterns found. One non-blocking warning (double `onComplete()` invocation possibility in completeStepView) noted but harmless due to idempotent AppStorage gate.

Phase goal is achieved: the onboarding flow, AI insight display, gap indicators, location fix, and privacy disclosure are all implemented and wired in the codebase.

---

_Verified: 2026-04-04T15:16:20Z_
_Verifier: Claude (gsd-verifier)_
