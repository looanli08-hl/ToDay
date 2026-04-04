---
phase: 1
slug: security-and-ai-pipeline
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-04
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (built-in) |
| **Config file** | `ios/ToDay/project.yml` (scheme: ToDayTests) |
| **Quick run command** | `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/EchoAIServiceTests` |
| **Full suite command** | `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO` |
| **Estimated runtime** | ~20 seconds |

---

## Sampling Rate

- **After every task commit:** Run `EchoAIServiceTests` + `EchoSchedulerTests` + `EchoPromptBuilderTests`
- **After every wave merge:** Full suite (180+ tests)
- **Phase gate:** Full suite green before phase completion

---

## Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated? |
|--------|----------|-----------|------------|
| SEC-01 | No hardcoded key in binary | Manual | `strings` check on compiled binary |
| SEC-02 | Cloud calls route through AIProxy | Unit | `AnthropicAIProviderTests.swift` |
| SEC-03 | Daily rate limit enforced | Unit | `EchoSchedulerTests` (existing) |
| AIS-01 | Summary generated on scheduler fire | Unit | `EchoDailySummaryGeneratorTests` (existing) |
| AIS-02 | Summary references place names, not GPS | Unit | `EchoPromptBuilderTests` |
| AIS-04 | Summary tone is observational | Unit | `EchoPromptBuilderTests` (update needed) |
| AIS-05 | Auto-generates on background | Manual | Device test — background after 20:00 |
| PRV-01 | No GPS coordinates in cloud payload | Unit | `EchoPromptBuilderTests` |

---

## Wave 0 Gaps

- [ ] `ios/ToDay/ToDayTests/AnthropicAIProviderTests.swift` — tests AnthropicAIProvider with mock, verifying model ID and error mapping
- [ ] Update `EchoPromptBuilderTests.swift` to assert observational tone instruction (AIS-04)

---

## Acceptance Gates

| Gate | Condition | Command |
|------|-----------|---------|
| Build | Zero errors, zero warnings | `xcodebuild build -scheme ToDay ...` |
| Tests | 180+ tests, 0 failures | `xcodebuild test -scheme ToDay ...` |
| Binary | No `sk-` patterns in compiled binary | `strings ToDay.app/ToDay \| grep sk-` returns empty |
