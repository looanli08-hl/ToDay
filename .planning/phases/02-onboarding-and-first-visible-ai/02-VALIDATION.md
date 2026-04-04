---
phase: 2
slug: onboarding-and-first-visible-ai
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-04
---

# Phase 2 — Validation Strategy

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (built-in) |
| **Quick run command** | `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO` |
| **Full suite command** | Same as above |
| **Estimated runtime** | ~20 seconds |

## Sampling Rate

- **After every task commit:** Build + grep checks
- **After every wave merge:** Full suite (180+ tests)
- **Phase gate:** Full suite green before phase completion

## Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated? |
|--------|----------|-----------|------------|
| ONB-01 | Value explanation before system dialog | Manual | Verify via simulator walkthrough |
| ONB-02 | Motion permission guided | Build | Compile check |
| ONB-03 | Denial shows recovery path to Settings | Manual | Verify `.locationDenied` step renders Settings link |
| ONB-04 | Usage strings specific enough | Grep | `grep "passively records" project.yml` |
| AIS-03 | AI summary card on TodayScreen | Unit | `TodayViewModelTests` — verify `aiDailySummary` published |
| REC-07 | Data gaps as labeled indicators | Unit | `PhoneInferenceEngineTests` — `.dataGap` EventKind |
| PRV-02 | Privacy policy accessible from Settings | Grep | `grep "AI 功能" SettingsView.swift` |
| PRV-03 | App Review Notes exist | File | `ls .planning/APP-REVIEW-NOTES.md` |

## Acceptance Gates

| Gate | Condition | Command |
|------|-----------|---------|
| Build | Zero errors | `xcodebuild build -scheme ToDay ...` |
| Tests | 180+ tests, 0 failures | `xcodebuild test -scheme ToDay ...` |
| Usage Strings | Specific location description | `grep "passively records" ios/ToDay/project.yml` |
| Privacy | Discloses AI processing | `grep "AI" ios/ToDay/ToDay/Features/Settings/SettingsView.swift` |
