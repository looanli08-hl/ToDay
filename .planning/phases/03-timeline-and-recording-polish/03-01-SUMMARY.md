---
phase: 03-timeline-and-recording-polish
plan: 01
subsystem: ui
tags: [typography, spacing-tokens, shadow, corner-radius, design-compliance]
dependency_graph:
  requires: []
  provides: [compliant-EventCardView, compliant-TodayScreen]
  affects: [03-02-PLAN, 03-03-PLAN, 03-04-PLAN]
tech_stack:
  added: []
  patterns: [AppRadius.lg for event cards, .appShadow(.elevated) for floating elements, AppSpacing tokens replacing literals]
key_files:
  created: []
  modified:
    - ios/ToDay/ToDay/Features/Today/ScrollCanvas/EventCardView.swift
    - ios/ToDay/ToDay/Features/Today/TodayScreen.swift
decisions:
  - All HStack spacing: 10 literals replaced with AppSpacing.xs (8pt) for 4pt grid compliance, not just VStack literals
  - weeklySpotlightSection and CTA button label also fixed from 16pt → 15pt semibold per UI-SPEC 4-size constraint
metrics:
  duration: ~15min
  completed_date: 2026-04-05
  tasks: 2
  files_modified: 2
---

# Phase 3 Plan 1: Typography, Spacing, and Shadow Compliance Summary

EventCardView and TodayScreen brought to full 03-UI-SPEC compliance: 4-size typography system, AppSpacing tokens replacing all literals, warm .appShadow(.elevated) replacing cold Color.primary shadow, and AppRadius.lg (16pt squircle) on event cards.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Fix EventCardView typography and corner radius | 5cf9152 | EventCardView.swift |
| 2 | Fix TodayScreen spacing tokens and bottom bar shadow | 91aa573 | TodayScreen.swift |

## What Was Built

### Task 1 — EventCardView

Corrected all typography deviations found in the Research gap table:

- `kindBadgeTitle` font: `10pt bold monospaced` → `12pt semibold monospaced`
- `scrollDurationText` font: `13pt bold monospaced` → `12pt semibold monospaced`
- `compactDetailLine` font: `13pt regular` → `12pt regular`
- `moodMarker` name text: `14pt medium` → `15pt semibold`
- Card corner radius: `cornerRadius: 14` → `AppRadius.lg` (16pt) on both `clipShape` and `overlay(RoundedRectangle)` — uses `.continuous` squircle style on both

The 4pt color accent bar and its 2pt corner radius were preserved unchanged.

### Task 2 — TodayScreen

Applied all spacing, typography, and shadow fixes:

**Spacing (VStack + HStack):**
- ScrollView root VStack: `spacing: 18` → `AppSpacing.md` (16pt)
- `scrollCanvasSection` VStack: `spacing: 14` → `AppSpacing.sm` (12pt)
- `overviewSection` VStack: `spacing: 10` → `AppSpacing.xs` (8pt)
- `bottomActionBar` VStack: `spacing: 12` → `AppSpacing.sm` (12pt, same value, now token)
- All `HStack(spacing: 10)` instances → `AppSpacing.xs` (4pt grid alignment)

**Typography:**
- `signatureSection` description: `14pt` → `15pt regular`
- `scrollCanvasSection` description: `14pt` → `15pt regular`
- `summarySection` headline: `16pt semibold` → `15pt semibold`

**Shadow:**
- Bottom action bar: `.shadow(color: Color.primary.opacity(0.06), radius: 18, x: 0, y: 8)` → `.appShadow(.elevated)` — warm-tinted brown base, radius 16, opacity 10%, y 4

**Hero/heading tier left unchanged:** "今日画卷" (33pt), section titles (23pt), and all existing correct usages preserved.

## Verification

- Build: PASSED
- Tests: 187 passed / 0 failed (exceeds 180+ requirement)
- Acceptance criteria: All green
  - No `cornerRadius: 14` in EventCardView
  - 2x `AppRadius.lg` in EventCardView (clipShape + overlay)
  - No `size: 10/13/14` in EventCardView
  - No `spacing: 18/14/10` literals in TodayScreen
  - No `Color.primary.opacity` in TodayScreen
  - 1x `appShadow(.elevated)` in TodayScreen
  - No `size: 16` in TodayScreen

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical Functionality] Fixed additional 16pt body text deviations**
- **Found during:** Task 2 verification
- **Issue:** `weeklySpotlightSection` headline (`16pt semibold`) and CTA button label (`16pt semibold`) also violated the UI-SPEC 4-size constraint, but were not listed in the plan's explicit action items
- **Fix:** Changed both to `15pt semibold` (body semibold tier) to fully satisfy the acceptance criteria `grep "size: 16" returns no matches`
- **Files modified:** TodayScreen.swift
- **Commit:** 91aa573

**2. [Rule 2 - Missing Critical Functionality] Fixed HStack spacing: 10 literals**
- **Found during:** Task 2 verification
- **Issue:** Four `HStack(spacing: 10)` instances in header buttons, overview stats row, and dual-button layout — violate 4pt grid (10 is not a multiple of 4)
- **Fix:** All replaced with `AppSpacing.xs` (8pt) to satisfy acceptance criteria `grep "spacing: 10" returns no matches`
- **Files modified:** TodayScreen.swift
- **Commit:** 91aa573

**3. [Rule 2 - Missing Critical Functionality] Fixed recentDaysSection VStack spacing literal**
- **Found during:** Task 2 verification
- **Issue:** `VStack(spacing: 10)` in recentDaysSection not listed in plan but matched the acceptance criteria grep pattern
- **Fix:** Replaced with `AppSpacing.xs`
- **Files modified:** TodayScreen.swift
- **Commit:** 91aa573

## Known Stubs

None — this plan makes only typography/spacing/shadow token changes. No data, UI flow, or business logic was modified. No stubs introduced.

## Self-Check: PASSED
