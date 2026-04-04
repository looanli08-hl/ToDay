---
phase: 02-onboarding-and-first-visible-ai
plan: 02
subsystem: ui
tags: [swiftui, swiftdata, ai, timeline, location, corelocation]

# Dependency graph
requires: []
provides:
  - "EventKind.dataGap case in SharedDataTypes.swift"
  - "Gap indicator rows in DayScrollView for .dataGap events"
  - "aiDailySummary property on TodayViewModel, loaded from DailySummaryEntity via EchoMemoryManager"
  - "AI daily summary card on TodayScreen, rendered between timeline canvas and algorithmic summary"
  - "LocationCollector fix: background monitoring only on .authorizedAlways"
affects:
  - "02-onboarding-and-first-visible-ai"
  - "phase 4 pattern recognition (reads from DailySummaryEntity)"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "lazy EchoMemoryManager instantiation inside TodayViewModel using existing modelContainer"
    - "aiDailySummary == nil guard to suppress algorithmic summary when AI content is present"
    - "AnyView wrapper for conditional row types in DayScrollView eventRow"

key-files:
  created: []
  modified:
    - "ios/ToDay/ToDay/Shared/SharedDataTypes.swift"
    - "ios/ToDay/ToDay/Data/Sensors/LocationCollector.swift"
    - "ios/ToDay/ToDay/Features/Today/TodayViewModel.swift"
    - "ios/ToDay/ToDay/Features/Today/TodayScreen.swift"
    - "ios/ToDay/ToDay/Features/Today/ScrollCanvas/DayScrollView.swift"
    - "ios/ToDay/ToDay/Features/Today/ScrollCanvas/EventCardView.swift"
    - "ios/ToDay/ToDay/Features/Today/TodayFlowViews.swift"
    - "ios/ToDay/ToDay/Data/WatchSyncHelper.swift"

key-decisions:
  - "Suppressed algorithmic summarySection when AI content is available — avoids duplicate redundant summaries (per RESEARCH.md Pitfall 4)"
  - "Used AnyView to conditionally dispatch between standardEventRow and gapIndicatorRow inside the existing eventRow function"
  - "lazy var echoMemoryManager in TodayViewModel to avoid creating it before modelContainer is set in init"

patterns-established:
  - "AI content takes precedence over algorithmic content: aiDailySummary == nil guard before showing insightSummary"
  - "dataGap events render as lightweight separator rows, not full EventCardView cards"

requirements-completed:
  - AIS-03
  - REC-07

# Metrics
duration: 25min
completed: 2026-04-04
---

# Phase 02 Plan 02: AI Summary Card + Gap Indicators + Location Fix Summary

**AI daily summary card wired to TodayScreen via EchoMemoryManager, timeline gap indicators for .dataGap events, and LocationCollector background monitoring restricted to .authorizedAlways**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-04-04T10:08:00Z
- **Completed:** 2026-04-04T10:21:00Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- EventKind.dataGap added to SharedDataTypes.swift; all exhaustive switches updated (EventCardView, TodayFlowViews, WatchSyncHelper)
- LocationCollector bug fixed: background monitoring (significantLocationChanges + visits) now only starts on .authorizedAlways, not .authorizedWhenInUse
- TodayViewModel now loads DailySummaryEntity for today via a lazy EchoMemoryManager; published as aiDailySummary
- TodayScreen shows AI summary card (Echo 今日洞察) after the timeline canvas when DailySummaryEntity exists; algorithmic summarySection is suppressed to avoid redundancy
- DayScrollView renders lightweight gap indicator rows for .dataGap events instead of full EventCardView cards
- All 180+ tests pass, build succeeds

## Task Commits

Each task was committed atomically:

1. **Task 1: Add EventKind.dataGap and fix LocationCollector authorization bug** - `a31ad2c` (feat)
2. **Task 2: Wire AI summary to TodayViewModel and render card + gap indicators on TodayScreen** - `a2be3ae` (feat)

## Files Created/Modified

- `ios/ToDay/ToDay/Shared/SharedDataTypes.swift` — Added case dataGap to EventKind enum
- `ios/ToDay/ToDay/Data/Sensors/LocationCollector.swift` — Fixed locationManagerDidChangeAuthorization to only start monitoring on .authorizedAlways
- `ios/ToDay/ToDay/Features/Today/TodayViewModel.swift` — Added aiDailySummary @Published property, lazy echoMemoryManager, loadAIDailySummary()
- `ios/ToDay/ToDay/Features/Today/TodayScreen.swift` — Added aiDailySummarySection between canvas and summarySection; summarySection guarded by aiDailySummary == nil
- `ios/ToDay/ToDay/Features/Today/ScrollCanvas/DayScrollView.swift` — Split eventRow into standardEventRow + gapIndicatorRow; .dataGap events render as labeled separator rows
- `ios/ToDay/ToDay/Features/Today/ScrollCanvas/EventCardView.swift` — Added .dataGap cases to cardFill, cardStroke, kindBadgeTitle exhaustive switches
- `ios/ToDay/ToDay/Features/Today/TodayFlowViews.swift` — Added .dataGap cases to flowColor, flowBackground, flowIntensity, icon, timelineDetail
- `ios/ToDay/ToDay/Data/WatchSyncHelper.swift` — Added .dataGap case to iconName switch

## Decisions Made

- Suppressed algorithmic summarySection when AI content is available — avoids showing two summaries about the same day, which would feel redundant per RESEARCH.md Pitfall 4
- Used `lazy var echoMemoryManager` instead of injecting it through `init()` — keeps the init signature minimal and avoids creating the object before `modelContainer` is assigned
- Gap indicator rows use `AnyView` wrapper to dispatch conditionally in the existing `eventRow` function — minimal refactor with no structural changes to the timeline layout engine

## Deviations from Plan

None - plan executed exactly as written. All exhaustive switch updates were required by the compiler after adding the `.dataGap` case, handled as part of Task 1 scope.

## Issues Encountered

- Simulator was busy (occupied by parallel agent) on first test run. Re-running tests succeeded immediately on second attempt.

## Known Stubs

None — aiDailySummarySection only renders when DailySummaryEntity exists for today (provided by EchoScheduler from Phase 1). The card is data-gated, not stubbed.

## Next Phase Readiness

- AIS-03 complete: users will see AI daily summary cards once EchoScheduler has generated a DailySummaryEntity for today
- REC-07 complete: .dataGap events can be inserted into the timeline by the PhoneInferenceEngine when sensor data gaps are detected
- LocationCollector fix ensures background location data will actually be collected on Always-authorized devices going forward

## Self-Check: PASSED

- SUMMARY.md: FOUND
- SharedDataTypes.swift: FOUND
- LocationCollector.swift: FOUND
- TodayViewModel.swift: FOUND
- TodayScreen.swift: FOUND
- DayScrollView.swift: FOUND
- Commit a31ad2c: FOUND
- Commit a2be3ae: FOUND

---
*Phase: 02-onboarding-and-first-visible-ai*
*Completed: 2026-04-04*
