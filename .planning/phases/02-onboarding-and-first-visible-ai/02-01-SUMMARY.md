---
phase: 02-onboarding-and-first-visible-ai
plan: 01
subsystem: ui
tags: [swift, swiftui, coreLocation, coreMotion, onboarding, permissions, iOS]

# Dependency graph
requires: []
provides:
  - Multi-step OnboardingView with LocationPermissionCoordinator
  - Two-step Always Location permission pattern (whenInUse → upgrade → always)
  - Denial recovery screen with openSettingsURLString
  - App Store Review-compliant usage description strings (30+ words, specific)
affects:
  - 02-02 (AI pipeline — onboarding is the entry gate for all tracking)
  - 02-03 (App Store Review — usage strings must match review requirements)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "@StateObject CLLocationManager coordinator retained across delegate callbacks"
    - "Two-step iOS Always Location pattern: requestWhenInUse → show UI → requestAlways"
    - "OnboardingStep enum as state machine driving multi-step SwiftUI flow"

key-files:
  created:
    - ios/ToDay/ToDayTests/OnboardingViewTests.swift
  modified:
    - ios/ToDay/ToDay/Features/Onboarding/OnboardingView.swift
    - ios/ToDay/project.yml

key-decisions:
  - "Two-step Always Location pattern required by iOS 17 — requestAlwaysAuthorization on first install shows no Always Allow option without prior whenInUse grant"
  - "onComplete() only callable from .locationDenied (skip) and .complete — never unconditionally"
  - "LocationPermissionCoordinator as @StateObject ensures CLLocationManager delegate lifetime matches view lifetime"

patterns-established:
  - "Permission coordinator pattern: @MainActor NSObject + ObservableObject + CLLocationManagerDelegate with stored CLLocationManager property"
  - "Step machine pattern: enum OnboardingStep { case value, locationWhenInUse, ... } + @State var step + switch in body"

requirements-completed: [ONB-01, ONB-02, ONB-03, ONB-04]

# Metrics
duration: 7min
completed: 2026-04-04
---

# Phase 02 Plan 01: Onboarding Multi-Step Permission Flow Summary

**Multi-step OnboardingView with LocationPermissionCoordinator using iOS 17 two-step Always Location pattern, denial recovery with Settings link, and App Store Review-compliant 30-word usage descriptions**

## Performance

- **Duration:** 7 min
- **Started:** 2026-04-04T10:09:45Z
- **Completed:** 2026-04-04T10:17:00Z
- **Tasks:** 2 (+ 1 TDD RED commit)
- **Files modified:** 3

## Accomplishments

- Replaced single-screen onboarding (with all its bugs) with a 6-step state machine: value → locationWhenInUse → locationAlwaysUpgrade → locationDenied/motion → complete
- Implemented iOS 17-compliant two-step Always Location pattern — requestWhenInUse fires first; requestAlways only called after .authorizedWhenInUse is received via delegate
- Fixed critical bug where CLLocationManager was a local variable (deallocated before delegate fires) — now a stored property on @MainActor LocationPermissionCoordinator retained via @StateObject
- Fixed critical bug where onComplete() was called unconditionally after permission request
- Updated all three usage description strings to pass App Store Review guideline 5.1.1 (specific, 30+ words for location)
- All 187 tests pass

## Task Commits

1. **TDD RED: OnboardingStep and LocationPermissionCoordinator tests** — `1952e43` (test)
2. **Task 1: Multi-step OnboardingView** — `b2d7943` (feat)
3. **Task 2: Usage description strings** — `ea4b911` (feat)

## Files Created/Modified

- `ios/ToDay/ToDay/Features/Onboarding/OnboardingView.swift` — Complete rewrite: OnboardingStep enum, LocationPermissionCoordinator class, 6-step body switch
- `ios/ToDay/project.yml` — NSLocationAlwaysAndWhenInUseUsageDescription (30 words), NSLocationWhenInUseUsageDescription, NSMotionUsageDescription updated to English, specific
- `ios/ToDay/ToDayTests/OnboardingViewTests.swift` — Created: OnboardingStepTests + LocationPermissionCoordinatorTests (TDD)

## Decisions Made

- iOS 17 requires the two-step pattern: requestWhenInUse first, then requestAlways — calling requestAlways directly on first install does not offer "Always Allow" in the system dialog
- LocationPermissionCoordinator must be @StateObject (not @State) so it's retained across body re-renders as a reference type
- Usage strings updated to English for App Store Review (Chinese strings too short, too vague)

## Deviations from Plan

None - plan executed exactly as written. All bugs described in the plan were fixed as part of the planned rewrite (not unplanned deviations).

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Onboarding gate is complete; users who deny location can still proceed with reduced functionality
- LocationPermissionCoordinator pattern can be referenced if background tracking needs to check authorization status elsewhere
- Usage strings are App Store Review-ready for initial submission

---
*Phase: 02-onboarding-and-first-visible-ai*
*Completed: 2026-04-04*
