---
phase: 04-pattern-recognition-and-proactive-push
plan: "01"
subsystem: ai
tags: [swift, swiftdata, pattern-detection, tdd, xctest, streak-detection]

requires:
  - phase: 03-timeline-and-recording-polish
    provides: DayTimelineEntity with entriesData, DailySummaryEntity, EchoScheduler infrastructure

provides:
  - PatternDetectionEngine struct (pure Swift, no side effects)
  - DetectedPattern value type (kind, placeName, timeOfDay, streakLength, recentDates)
  - TimeOfDayBucket enum (morning/afternoon/evening) with from(hour:) factory
  - hasSufficientData(context:) — fetchCount guard for 21-day minimum
  - detectBestPattern(context:) — 30-day lookback with streak detection
  - PatternDetectionEngineTests — 7 tests covering all contracts

affects:
  - 04-02 (EchoScheduler integration — consumes PatternDetectionEngine.detectBestPattern)
  - 04-03 (TodayScreen pattern insight card — consumes DetectedPattern type)

tech-stack:
  added: []
  patterns:
    - "String-range predicate on DayTimelineEntity.dateKey (yyyy-MM-dd ISO lexicographic sort avoids SwiftData Date capture bug)"
    - "fetchCount(FetchDescriptor<DailySummaryEntity>()) for zero-cost count-only query"
    - "Blocklist filtering: Set<String> of fallback geocoder display names (未知地点, 离开了手机)"
    - "longestStreak: sort ISO dateKeys, walk consecutive pairs checking calendar day diff == 1"
    - "TDD RED+GREEN: test file committed first (compile error), then implementation added"

key-files:
  created:
    - ios/ToDay/ToDay/Data/AI/PatternDetectionEngine.swift
    - ios/ToDay/ToDayTests/PatternDetectionEngineTests.swift
  modified: []

key-decisions:
  - "minimumDataDays=21 (3 weeks) and minimumStreakDays=3 as named constants — tunable after real user data"
  - "Only EventKind.quietTime events detected in v1 — workout frequency patterns deferred to scope extension"
  - "String-range predicate over Date predicate for all DayTimelineEntity fetches — avoids iOS 17 SwiftData Date capture crash"
  - "detectBestPattern returns highest-streakLength pattern (single best pattern, not a list)"

patterns-established:
  - "PatternDetectionEngine: pure struct, no stored state, receives ModelContext per call — safe for multi-context use"
  - "BlockList as Set<String> — O(1) lookup, extensible without changing detection algorithm"
  - "DetectedPattern.recentDates carries dateKey strings (not Date objects) — consistent with project string-key convention"

requirements-completed:
  - AIP-01
  - AIP-02

duration: 8min
completed: 2026-04-05
---

# Phase 04 Plan 01: PatternDetectionEngine Summary

**Pure-Swift streak detector with TDD: PatternDetectionEngine detects consecutive-day location patterns from SwiftData with a 21-day sufficiency gate and displayName blocklist filtering**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-05T02:31:31Z
- **Completed:** 2026-04-05T02:33:43Z
- **Tasks:** 2 (RED + GREEN)
- **Files modified:** 2

## Accomplishments

- Wrote 7 failing XCTest cases (RED) covering streak detection, data sufficiency, and display name filtering before any implementation
- Implemented PatternDetectionEngine as a pure-Swift struct with zero side effects — reads SwiftData, returns typed DetectedPattern
- All 7 new tests pass; full suite grew from 194 to 201 tests with 0 failures

## Task Commits

Each task was committed atomically:

1. **Task 1: RED — Write failing tests** - `77c8759` (test)
2. **Task 2: GREEN — Implement PatternDetectionEngine** - `b6a2e90` (feat)

**Plan metadata:** (committed after SUMMARY creation)

_Note: TDD — RED commit is a compile error by design; GREEN commit makes all 7 tests pass_

## Files Created/Modified

- `ios/ToDay/ToDay/Data/AI/PatternDetectionEngine.swift` — PatternDetectionEngine struct, DetectedPattern, TimeOfDayBucket; 182 lines pure Swift
- `ios/ToDay/ToDayTests/PatternDetectionEngineTests.swift` — XCTest suite with 7 tests, in-memory SwiftData container, helper methods for DayTimelineEntity and DailySummaryEntity creation

## Decisions Made

- minimumDataDays=21 and minimumStreakDays=3 are named constants on the struct (not magic numbers), enabling future tuning after real user data is available
- Only EventKind.quietTime events are pattern-worthy in v1; workout frequency patterns explicitly deferred per RESEARCH.md recommendation
- String-range predicate chosen over Date predicate for all fetches — consistent with EchoPromptBuilder and BackgroundTaskManager existing patterns; avoids iOS 17 SwiftData #Predicate Date-capture crash

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- PatternDetectionEngine is complete and tested — ready for EchoScheduler integration (04-02)
- DetectedPattern and TimeOfDayBucket types are exported — 04-02 can consume them immediately
- hasSufficientData guard ensures pattern detection cannot produce false positives from insufficient data
- Known runtime blocker (documented in STATE.md): Pattern insights cannot fire for real users until 21+ DailySummaryEntity records accumulate (3+ weeks of use) — this is an operational concern, not an engineering blocker

---
*Phase: 04-pattern-recognition-and-proactive-push*
*Completed: 2026-04-05*
