---
phase: 05-echo-conversation
plan: 01
subsystem: testing
tags: [xctest, tdd, swiftdata, echoai, promptbuilder, echodata]

requires:
  - phase: 04-pattern-recognition-and-proactive-push
    provides: EchoMessageEntity, EchoMessageManager, EchoThreadViewModel, EchoPromptBuilder baseline

provides:
  - 2 RED failing tests precisely documenting Echo conversation wiring gaps
  - 1 GREEN test confirming freeChat entity creation base behavior
  - todayDataSummary stub property on EchoChatViewModel (additive, no wiring yet)
  - MockAIProvider.lastReceivedMessages capture for assertion-level test verification
  - EchoMessageListNavigationTests.swift as new test file (scaffold for Plan 03)

affects:
  - 05-02 (GREEN phase — must make both RED tests pass)
  - 05-03 (navigation wiring — extends EchoMessageListNavigationTests.swift)

tech-stack:
  added: []
  patterns:
    - "RED-first TDD: write failing tests before any implementation commits"
    - "MockAIProvider.lastReceivedMessages: capture full messages array to assert context injection"
    - "additive property stub: add @Published property with nil default to make test compile while assertion fails"

key-files:
  created:
    - ios/ToDay/ToDayTests/EchoMessageListNavigationTests.swift
  modified:
    - ios/ToDay/ToDayTests/EchoPromptBuilderTests.swift
    - ios/ToDay/ToDayTests/EchoChatViewModelTests.swift
    - ios/ToDay/ToDayTests/EchoAIServiceTests.swift
    - ios/ToDay/ToDay/Features/Echo/EchoChatViewModel.swift

key-decisions:
  - "todayDataSummary added as @Published var String? = nil stub — additive only, wired in Plan 02"
  - "DayTimelineEntity added to EchoPromptBuilderTests schema for forward compatibility"
  - "loadRecentTimelineSummaries uses AppContainer.modelContainer singleton — architectural coupling documented in test comment, addressed in Plan 02"
  - "MockAIProvider.lastReceivedMessages captures full messages array — enables system prompt content assertion without a spy"

patterns-established:
  - "RED test comment convention: state which plan makes it GREEN and why the current impl fails"

requirements-completed:
  - AIC-01
  - AIC-02
  - AIC-03

duration: 3min
completed: 2026-04-05
---

# Phase 5 Plan 01: RED-Phase Test Scaffolding for Echo Conversation Gaps Summary

**Failing XCTest cases for three Echo wiring gaps: freeChat timeline context, todayDataSummary nil injection, and freeChat entity creation — 184 pre-existing tests still pass**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-05T03:00:47Z
- **Completed:** 2026-04-05T03:04:00Z
- **Tasks:** 1
- **Files modified:** 5 (+ 1 new)

## Accomplishments

- Two RED failing tests written that precisely document the gaps Plans 02 and 03 must close
- testBuildThreadMessagesForFreeChatIncludesTimeline: FAILS — buildThreadSystemPrompt omits loadRecentTimelineSummaries for .freeChat (AIC-02)
- testSendMessagePassesTodayDataSummaryToPrompt: FAILS — EchoChatViewModel.sendMessage hardcodes todayDataSummary: nil (AIC-02)
- testCreateFreeChatMessageReturnsEntityWithThreadId: PASSES — createFreeChatMessage returns valid entity with distinct threadId (AIC-03 base)
- testBuildThreadMessagesForNonFreeChatExcludesTimeline: PASSES — validates Plan 02 fix will be scoped to freeChat only
- 186 tests total: 2 failures (the 2 RED tests), 184 passes (all pre-existing)

## Task Commits

1. **Task 1: RED-phase tests** - `f821f85` (test)

## Files Created/Modified

- `ios/ToDay/ToDayTests/EchoPromptBuilderTests.swift` — Added DayTimelineEntity to schema; appended testBuildThreadMessagesForFreeChatIncludesTimeline (RED) + testBuildThreadMessagesForNonFreeChatExcludesTimeline (GREEN)
- `ios/ToDay/ToDayTests/EchoChatViewModelTests.swift` — Appended testSendMessagePassesTodayDataSummaryToPrompt (RED)
- `ios/ToDay/ToDayTests/EchoAIServiceTests.swift` — Added lastReceivedMessages: [EchoChatMessage]? capture to MockAIProvider
- `ios/ToDay/ToDay/Features/Echo/EchoChatViewModel.swift` — Added @Published var todayDataSummary: String? = nil stub (additive)
- `ios/ToDay/ToDayTests/EchoMessageListNavigationTests.swift` — New file: EchoMessageListNavigationTests with testCreateFreeChatMessageReturnsEntityWithThreadId (GREEN)

## Decisions Made

- todayDataSummary added as a pure stub property (no wiring) so the test compiles and fails at assertion level rather than compile level
- MockAIProvider.lastReceivedMessages captures the messages array in respond() — allows asserting system prompt content without a protocol spy or subclass
- DayTimelineEntity added to EchoPromptBuilderTests schema now (even though loadRecentTimelineSummaries uses the AppContainer singleton) for forward compatibility when Plan 02 makes the context injectable
- Architectural coupling (AppContainer.modelContainer singleton in loadRecentTimelineSummaries) documented in test comment — Plan 02 must make context injectable for the test to be fully meaningful

## Deviations from Plan

None — plan executed exactly as written. The plan explicitly documented the additive property approach and the MockAIProvider capture strategy. Both were implemented as specified.

## Issues Encountered

None — all 4 target tests achieved their expected state (2 RED, 2 GREEN) on the first run.

## Known Stubs

- `EchoChatViewModel.todayDataSummary` — `@Published var todayDataSummary: String? = nil`. This is an intentional stub (always nil, never read by sendMessage). Plan 02 will wire it into the buildMessages call. The property was added solely to allow the RED test to compile and assert.

## Next Phase Readiness

- Plan 05-02: Make testBuildThreadMessagesForFreeChatIncludesTimeline and testSendMessagePassesTodayDataSummaryToPrompt GREEN
- Plan 05-03: Add navigation test to EchoMessageListNavigationTests.swift and implement NavigationPath wiring
- Both RED tests are precise acceptance criteria — no ambiguity in what Plans 02/03 must deliver

---
*Phase: 05-echo-conversation*
*Completed: 2026-04-05*
