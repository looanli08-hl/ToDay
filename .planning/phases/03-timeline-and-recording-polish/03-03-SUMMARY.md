---
phase: 03-timeline-and-recording-polish
plan: 03
subsystem: timeline-ui
tags: [tdd, proportional-height, event-row, timeline, swift-ui]
dependency_graph:
  requires: [03-01, 03-02]
  provides: [proportional-event-row-heights, day-scroll-view-tests]
  affects: [DayVerticalTimelineContent, currentTimeOffset, DayScrollViewTests]
tech_stack:
  added: []
  patterns: [module-level-internal-function-for-testability, tdd-red-green]
key_files:
  created:
    - ios/ToDay/ToDayTests/DayScrollViewTests.swift
  modified:
    - ios/ToDay/ToDay/Features/Today/ScrollCanvas/DayScrollView.swift
    - ios/ToDay/ToDay.xcodeproj/project.pbxproj
decisions:
  - "Extracted eventRowHeightFor(event:) as an internal module-level free function (not inside DayVerticalTimelineContent struct) to enable testability without changing the View architecture"
  - "private eventRowHeight(for:) inside struct delegates to the free function — zero behavior change, full testability"
  - "TDD RED+GREEN completed in single task commit since both steps (test file + implementation) were done atomically"
metrics:
  duration: 15min
  completed: "2026-04-04T16:15:00Z"
  tasks_completed: 2
  files_changed: 3
---

# Phase 03 Plan 03: Proportional Event Row Heights Summary

Duration-proportional timeline row heights with TDD coverage. `eventRowHeightFor(event:)` replaces fixed 76pt/92pt heights — events now visually communicate their felt duration.

## What Was Built

### eventRowHeightFor(event:) — Module-level Internal Function

Extracted from `DayVerticalTimelineContent` as an `internal` free function at module scope in `DayScrollView.swift`. This makes the height formula testable via `@testable import ToDay` without altering the View's architecture.

Formula:
```swift
func eventRowHeightFor(event: InferredEvent) -> CGFloat {
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

Constraints enforced:
- Minimum: 44pt (iOS HIG touch target floor)
- Maximum: 180pt (prevents absurdly tall rows for long events)
- Sleep-with-stages floor: 92pt (enough height to render sleep stage bar)

### Delegation Chain (preserved, unchanged)

```
currentTimeOffset → rowHeight(for: item) → eventRowHeight(for: event) + 6 → eventRowHeightFor(event:)
```

The `+6` padding constant in `rowHeight(for:)` is untouched. The `currentTimeOffset` calculation remains accurate because it traverses the same `rowHeight(for:)` path.

### DayScrollViewTests — 5 Tests

| Test | Input | Expected | Rationale |
|------|-------|----------|-----------|
| `testEventRowHeightMinClamp` | 1min event | 44pt | 0.5pt proportional → clamped to 44 minimum |
| `testEventRowHeightProportional` | 240min event | 120pt | 120pt is within [44, 180] range |
| `testEventRowHeightMaxClamp` | 480min event | 180pt | 240pt proportional → clamped to 180 maximum |
| `testEventRowHeightSleepWithStagesFloor` | sleep, 60min, 1 stage | 92pt | base=44, sleep-with-stages floor=92 |
| `testEventRowHeightSleepWithoutStagesNoFloor` | sleep, 60min, no stages | 44pt | No stage data → no 92pt override, base=44 |

## Tasks Completed

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | TDD: Write failing tests (RED), extract module function, pass tests (GREEN) | f68d6a3 | DayScrollViewTests.swift, DayScrollView.swift, project.pbxproj |
| 2 | Proportional eventRowHeight implemented (completed as part of Task 1 TDD cycle) | f68d6a3 | DayScrollView.swift |

## Deviations from Plan

### TDD Cycle Executed Atomically

**Found during:** Task 1 (TDD)
**Note:** The plan describes Task 1 (RED+GREEN) and Task 2 (implementation) as separate steps. Since the TDD cycle in Task 1 already required writing the formula to make tests green, both were committed together in one atomic commit. Task 2 had no additional work to do — the formula was already in place and all tests passed.

This is a natural consequence of the TDD cycle as described in the plan's action block: "Step 2: extract formula as internal function... Step 3 (GREEN): run tests." Both steps are part of Task 1.

**No architectural changes, no out-of-scope fixes.**

## Known Stubs

None. The proportional height formula is fully wired. All 5 DayScrollViewTests pass against the live implementation.

## Verification

- `grep "76\b" DayScrollView.swift` inside `eventRowHeight` body → 0 matches (old fixed height removed)
- `grep "min(180\|max(44" DayScrollView.swift` → 2 matches (formula present)
- 194 tests pass (189 pre-existing + 5 new DayScrollViewTests)
- Build passes, exit 0

## Self-Check: PASSED

- [x] `ios/ToDay/ToDayTests/DayScrollViewTests.swift` — FOUND
- [x] `ios/ToDay/ToDay/Features/Today/ScrollCanvas/DayScrollView.swift` — modified, FOUND
- [x] Commit f68d6a3 — FOUND
- [x] 194 tests pass — VERIFIED
- [x] No fixed 76pt in eventRowHeight body — VERIFIED
- [x] Proportional formula present — VERIFIED
- [x] rowHeight(for:) still adds +6 — VERIFIED (line 354)
- [x] currentTimeOffset uses rowHeight(for:) chain — VERIFIED (line 308)
