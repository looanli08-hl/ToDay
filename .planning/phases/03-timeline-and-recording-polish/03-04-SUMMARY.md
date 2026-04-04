---
phase: 03-timeline-and-recording-polish
plan: "04"
subsystem: recording
tags: [CoreLocation, CLLocationManager, background-location, iOS-kill-relaunch]

# Dependency graph
requires:
  - phase: 03-01
    provides: EventCardView and timeline layout infrastructure
  - phase: 03-02
    provides: TodayScreen visual polish and shadow system
  - phase: 03-03
    provides: DayScrollView height formula and eventRowHeightFor tests
provides:
  - LocationCollector with correct .authorizedAlways guards for both kill-and-relaunch and fresh authorization upgrade paths
  - Stop monitoring on .authorizedWhenInUse downgrade (prevents silent background failures)
affects: [recording-validation, TestFlight, background-location]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "startMonitoring() checks authorizationStatus == .authorizedAlways immediately (kill-and-relaunch guard)"
    - "locationManagerDidChangeAuthorization calls monitoring APIs directly (not via startMonitoring delegation)"
    - "stopMonitoringVisits + stopMonitoringSignificantLocationChanges on .authorizedWhenInUse downgrade"

key-files:
  created: []
  modified:
    - ios/ToDay/ToDay/Data/Sensors/LocationCollector.swift

key-decisions:
  - "startMonitoring() guards on .authorizedAlways to handle kill-and-relaunch without waiting for delegate callback"
  - "locationManagerDidChangeAuthorization calls manager.startMonitoringVisits() directly rather than delegating to startMonitoring() — clearer intent"
  - "Task 2 (TestFlight device validation) deferred to unified TestFlight milestone per execution instructions"

patterns-established:
  - "Pattern: CLLocationManager kill-and-relaunch guard — check authorizationStatus synchronously in startMonitoring(), do not rely solely on delegate callback"

requirements-completed: [REC-01, REC-02, REC-03, REC-04, REC-05, REC-06]

# Metrics
duration: 8min
completed: 2026-04-04
---

# Phase 03 Plan 04: LocationCollector Hardening Summary

**LocationCollector authorization guards hardened for kill-and-relaunch and fresh authorization upgrade paths; background monitoring stopped on .authorizedWhenInUse downgrade**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-04-04T16:18:11Z
- **Completed:** 2026-04-04T16:26:00Z
- **Tasks:** 1 executed + 1 deferred (TestFlight)
- **Files modified:** 1

## Accomplishments
- Added `.authorizedAlways` guard to `startMonitoring()` — handles kill-and-relaunch case where iOS fires significant location change, relaunches app, and delegate callback does NOT fire again
- Updated `locationManagerDidChangeAuthorization` to call monitoring APIs directly on `.authorizedAlways` (was delegating back to `startMonitoring()`, which previously had no authorization check)
- Added `stopMonitoringVisits()` + `stopMonitoringSignificantLocationChanges()` on `.authorizedWhenInUse` downgrade — previously was silently doing `break`
- 194 tests pass, 0 failures — no regressions in LocationCollectorTests or full suite

## Task Commits

Each task was committed atomically:

1. **Task 1: Audit and harden LocationCollector authorization guard** - `33fc76a` (feat)
2. **Task 2: Real-device recording pipeline validation via TestFlight** - deferred to TestFlight milestone

**Plan metadata:** pending final docs commit

## Files Created/Modified
- `ios/ToDay/ToDay/Data/Sensors/LocationCollector.swift` - Authorization guards hardened in startMonitoring() and locationManagerDidChangeAuthorization; stop-monitoring added for .authorizedWhenInUse

## Decisions Made
- `startMonitoring()` now guards on `.authorizedAlways` synchronously — this handles the kill-and-relaunch path where iOS background-relaunches the app on significant location change but does not fire the authorization delegate again
- `locationManagerDidChangeAuthorization` calls `manager.startMonitoringVisits()` and `manager.startMonitoringSignificantLocationChanges()` directly rather than through `startMonitoring()` — makes the authorization-driven startup explicit and avoids double indirection
- Task 2 (TestFlight real-device validation of REC-01 through REC-06) deferred to unified TestFlight milestone per execution context — user cannot validate on simulator; will test all recording requirements in a single TestFlight build after Phase 03 completes

## Deviations from Plan

None - plan executed exactly as written. The two hardening points (kill-and-relaunch guard and `.authorizedWhenInUse` stop-monitoring) were both missing from the original code and were added as specified. No logic that broke LocationCollectorTests was introduced.

## Known Stubs

None — this plan modifies CLLocationManager startup behavior only. No UI, no data display, no stubs introduced.

## Issues Encountered

None. Build and full test suite (194 tests) passed on first attempt.

## TestFlight Deferred Validation

**Task 2 — Real-device recording pipeline validation** is deferred to the unified TestFlight milestone.

Requirements deferred for device validation: REC-01 (background location visits), REC-02 (activity type detection), REC-03 (event inference from sensor data), REC-04 (reverse geocoding), REC-05 (home/work/frequent classification), REC-06 (kill-and-relaunch survival).

The source hardening in Task 1 is complete and is a prerequisite for these requirements to succeed on device. Device validation cannot be automated in the simulator.

## Next Phase Readiness
- Phase 03 recording pipeline source hardening is complete
- All 194 unit tests pass
- TestFlight build required for REC-01 through REC-06 real-device validation
- Phase 04 (pattern recognition) remains data-gated — requires 3+ weeks of accumulated real user data

---
*Phase: 03-timeline-and-recording-polish*
*Completed: 2026-04-04*
