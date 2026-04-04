---
phase: 02-onboarding-and-first-visible-ai
plan: "03"
subsystem: ui
tags: [privacy, settings, app-review, SwiftUI, DataExplanationView]

# Dependency graph
requires:
  - phase: 01-security-and-ai-pipeline
    provides: AI pipeline via AIProxy/Claude that requires accurate privacy disclosure
provides:
  - DataExplanationView with accurate AI data processing disclosure (PRV-02)
  - APP-REVIEW-NOTES.md with copy-paste App Store submission template (PRV-03)
affects: [app-store-submission, privacy-compliance, future-ai-feature-phases]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Multi-section List in SettingsView for structured privacy disclosure"

key-files:
  created:
    - .planning/APP-REVIEW-NOTES.md
  modified:
    - ios/ToDay/ToDay/Features/Settings/SettingsView.swift

key-decisions:
  - "DataExplanationView restructured into three named sections (本地数据, AI 功能数据处理, 数据删除) rather than single blob"
  - "Disclosure explicitly names Anthropic and AIProxy as the AI provider chain — no vague 'third-party' language"
  - "APP-REVIEW-NOTES.md stored in .planning/ as a permanent reference artifact, not in the codebase"

patterns-established:
  - "Privacy disclosure: three-part structure — local data, AI processing, deletion — for any future disclosure updates"

requirements-completed: [PRV-02, PRV-03]

# Metrics
duration: 8min
completed: 2026-04-04
---

# Phase 02 Plan 03: Privacy Disclosure and App Review Notes Summary

**DataExplanationView updated to accurately disclose AI data processing via Anthropic/AIProxy; APP-REVIEW-NOTES.md created as permanent App Store submission reference**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-04-04T10:04:00Z
- **Completed:** 2026-04-04T10:12:20Z
- **Tasks:** 2 (Task 1 fully executed; Task 2 file created, awaiting human verification checkpoint)
- **Files modified:** 2

## Accomplishments

- Replaced the inaccurate "我们不上传、不收集、不分享任何个人数据" claim with a factual three-section disclosure
- AI section explicitly names Anthropic (Claude model) and AIProxy as the processing chain
- APP-REVIEW-NOTES.md created with copy-paste ready template for App Store Connect "Notes for Reviewers"
- Template covers Always Location justification and AI feature disclosure for reviewers

## Task Commits

Each task was committed atomically:

1. **Task 1: Update DataExplanationView with accurate AI data disclosure** - `217236b` (feat)
2. **Task 2: Create APP-REVIEW-NOTES.md** - `4bdf1f3` (docs — committed to main repo)

**Plan metadata:** (pending final commit)

## Files Created/Modified

- `ios/ToDay/ToDay/Features/Settings/SettingsView.swift` — DataExplanationView replaced with three-section accurate disclosure (本地数据, AI 功能数据处理, 数据删除)
- `.planning/APP-REVIEW-NOTES.md` — Copy-paste template for App Store Connect reviewer notes, covering Always Location and AI feature disclosure

## Decisions Made

- Three named sections chosen over a single text block for scannability and future extensibility
- Explicit AI provider naming (Anthropic + AIProxy) chosen over vague "third-party" — more honest, more likely to pass App Review
- APP-REVIEW-NOTES.md placed in `.planning/` (not the codebase) since it's a submission artifact, not shipped code

## Deviations from Plan

None - plan executed exactly as written.

The plan specified precise replacement text for DataExplanationView and exact content for APP-REVIEW-NOTES.md. Both were implemented verbatim. Build succeeded post-edit.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required. The APP-REVIEW-NOTES.md must be manually pasted into App Store Connect "Notes for Reviewers" on each submission (this is intentional per PRV-03 requirement design).

## Next Phase Readiness

- PRV-02 satisfied: DataExplanationView accurately discloses AI processing; privacy policy Link row already present in SettingsView
- PRV-03 satisfied: APP-REVIEW-NOTES.md exists with Always Location explanation and AI disclosure template
- Phase 02 plan 03 complete — the privacy compliance artifacts for App Store submission are in place
- Remaining Phase 02 work: plans 01 and 02 (onboarding flow rewrite and AI summary card wiring)

## Known Stubs

None — this plan makes no UI rendering changes that depend on data. DataExplanationView displays static text only.

---
*Phase: 02-onboarding-and-first-visible-ai*
*Completed: 2026-04-04*
