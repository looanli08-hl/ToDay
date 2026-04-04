---
phase: 03-timeline-and-recording-polish
plan: 02
subsystem: ios/ui
tags: [typography, spacing, shadows, design-tokens, ui-spec-compliance]
dependency_graph:
  requires: []
  provides: [HistoryScreen-compliant-typography, QuickRecordSheet-heading-font, DayScrollView-timestamp-fonts]
  affects: [HistoryScreen, QuickRecordSheet, DayScrollView]
tech_stack:
  added: []
  patterns: [AppSpacing tokens, appShadow modifier, system serif font, monospaced timestamps]
key_files:
  created: []
  modified:
    - ios/ToDay/ToDay/Features/History/HistoryScreen.swift
    - ios/ToDay/ToDay/Features/Today/QuickRecordSheet.swift
    - ios/ToDay/ToDay/Features/Today/ScrollCanvas/DayScrollView.swift
decisions:
  - Extend timestamp font fix to quietGapRow and moodRow time labels (also size: 10 medium) to satisfy acceptance criteria and UI-SPEC consistency
metrics:
  duration: ~8min
  completed: 2026-04-04
  tasks_completed: 2
  files_modified: 3
---

# Phase 03 Plan 02: UI-SPEC Typography, Spacing, and Shadow Compliance Summary

**One-liner:** Applied 03-UI-SPEC token contracts — serif italic heading, semibold rounded metric values, AppSpacing.md spacing, and .appShadow(.subtle) across HistoryScreen, QuickRecordSheet title, and DayScrollView timestamps/moodRow.

## What Was Built

Three targeted UI-SPEC compliance passes across three files:

### Task 1 — HistoryScreen (commit `6847ff1`)

| Element | Before | After |
|---------|--------|-------|
| `selectedDayContent` date header | `.title2.bold()` | `.system(size: 23, weight: .regular, design: .serif).italic()` |
| `insightSection` "生活脉搏" title | `size: 18, weight: .bold` | `size: 15, weight: .semibold` |
| `metricCard` metric value | `size: 26, weight: .bold` | `size: 23, weight: .semibold, design: .rounded` |
| `selectedDayContent` VStack spacing | literal `20` | `AppSpacing.md` (16pt) |
| `metricCard` shadow | inline `.shadow(color:radius:x:y:)` | `.appShadow(.subtle)` |

### Task 2 — QuickRecordSheet + DayScrollView (commit `4bbff2a`)

| File | Element | Before | After |
|------|---------|--------|-------|
| QuickRecordSheet | sheet title | `size: 28, .regular, .serif` | `size: 23, .regular, .serif` italic |
| DayScrollView | eventRow start time | `size: 11, .medium, .monospaced` | `size: 12, .regular, .monospaced` 60% opacity |
| DayScrollView | eventRow end time | `size: 10, .medium, .monospaced` | `size: 12, .regular, .monospaced` 35% opacity |
| DayScrollView | quietGapRow time | `size: 10, .medium, .monospaced` | `size: 12, .regular, .monospaced` |
| DayScrollView | moodRow time | `size: 10, .medium, .monospaced` | `size: 12, .regular, .monospaced` |
| DayScrollView | moodRow minHeight | `38pt` | `44pt` (iOS HIG) |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing UI-SPEC compliance] Fixed quietGapRow and moodRow timestamp fonts**
- **Found during:** Task 2
- **Issue:** Plan action specified only `standardEventRow` timestamps, but `quietGapRow` and `moodRow` also had non-compliant `size: 10, weight: .medium` timestamp fonts. Acceptance criteria requires no `size: 10` matches in timestamp-related fonts.
- **Fix:** Extended font fix to `quietGapRow.startTime` and `moodRow.time` labels — changed from `size: 10, .medium` to `size: 12, .regular, .monospaced` for UI-SPEC consistency across all timeline time labels
- **Files modified:** `ios/ToDay/ToDay/Features/Today/ScrollCanvas/DayScrollView.swift`
- **Commit:** `4bbff2a`

## Commits

| Hash | Message |
|------|---------|
| `6847ff1` | feat(03-02): fix HistoryScreen typography, spacing, and shadows |
| `4bbff2a` | feat(03-02): fix QuickRecordSheet title and DayScrollView timestamps/moodRow |

## Verification Results

- Build: PASSED (xcodebuild, iOS Simulator)
- Tests: PASSED (** TEST SUCCEEDED **)
- All acceptance criteria met:
  - HistoryScreen: no `.title2.bold()`, no `size: 18`, no `size: 26`, no `spacing: 20`, `.appShadow(.subtle)` present
  - QuickRecordSheet: no `size: 28`, `size: 23` serif present for sheet title
  - DayScrollView: no `size: 11` or `size: 10` in timestamp fonts, `minHeight: 44` present

## Known Stubs

None — all changes are direct token substitutions with no stub patterns.

## Self-Check: PASSED
