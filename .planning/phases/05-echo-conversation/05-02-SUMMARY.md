---
phase: 05-echo-conversation
plan: 02
subsystem: ai
tags: [echoai, promptbuilder, swiftdata, swiftui, todaydata, tdd]

requires:
  - phase: 05-echo-conversation plan 01
    provides: RED tests for freeChat timeline injection and todayDataSummary nil wiring gap

provides:
  - buildThreadMessages(todayDataSummary:) parameter on EchoPromptBuilder (AIC-02)
  - 近期生活时间线 injected into freeChat thread system prompts via loadRecentTimelineSummaries
  - EchoPromptBuilder.timelineContainer injection for test isolation (avoids AppContainer singleton)
  - EchoThreadViewModel.todayDataSummary stored property and init parameter
  - EchoChatViewModel.todayDataSummary wired into sendMessage (was hardcoded nil)
  - AppContainer.makeEchoThreadViewModel(for:todayDataSummary:) updated signature
  - AppRootScreen threadViewModelFactory passes todayViewModel.timelineDataSummary
  - MockAIProvider.lastReceivedMessages capture for system prompt assertion
  - testBuildThreadMessagesForFreeChatIncludesTimeline GREEN
  - testSendMessagePassesTodayDataSummaryToPrompt GREEN

affects:
  - 05-03 (NavigationPath wiring — already completed in branch)
  - Echo AI quality — accurate answers to life data questions now possible

tech-stack:
  added: []
  patterns:
    - "timelineContainer injection: EchoPromptBuilder accepts optional ModelContainer to avoid AppContainer.modelContainer singleton in tests"
    - "todayDataSummary: String? = nil default — additive parameter that keeps all existing callers working without changes"
    - "MockAIProvider.lastReceivedMessages capture — enables asserting system prompt content without protocol spy"

key-files:
  created: []
  modified:
    - ios/ToDay/ToDay/Data/AI/EchoPromptBuilder.swift
    - ios/ToDay/ToDay/Features/Echo/EchoThreadViewModel.swift
    - ios/ToDay/ToDay/Features/Echo/EchoChatViewModel.swift
    - ios/ToDay/ToDay/App/AppContainer.swift
    - ios/ToDay/ToDay/App/AppRootScreen.swift
    - ios/ToDay/ToDayTests/EchoPromptBuilderTests.swift
    - ios/ToDay/ToDayTests/EchoChatViewModelTests.swift
    - ios/ToDay/ToDayTests/EchoAIServiceTests.swift

key-decisions:
  - "EchoPromptBuilder gained timelineContainer: ModelContainer? init param — nil defaults to AppContainer.modelContainer singleton; test passes container to avoid singleton coupling"
  - "freeChat timeline injection positioned between Recent Summaries (5) and Conversation Memory (6) as step 5.5"
  - "todayData section appended at end of buildThreadSystemPrompt (after Conversation Memory) matching buildSystemPrompt ordering"
  - "InferredEvent with kind: .activeWalk required in test — empty entries array produces empty eventSummary, skipping 近期生活时间线 section"
  - "Plan 05-01 task commit (f821f85) existed only in worktree-agent-ab5d2f0f, never merged to feature/phone-first-auto-recording — RED tests and stubs added in this plan as catch-up"

patterns-established:
  - "Container injection: testable SwiftData access via optional ModelContainer init param with AppContainer.modelContainer fallback"
  - "Data presence check: loadRecentTimelineSummaries requires non-mood entries to produce output; empty timelines are silently skipped"

requirements-completed:
  - AIC-01
  - AIC-02

duration: 12min
completed: 2026-04-05
---

# Phase 5 Plan 02: todayDataSummary and freeChat Timeline Wiring Summary

**EchoPromptBuilder injects 近期生活时间线 into freeChat thread system prompts; live todayDataSummary flows from TodayViewModel through AppContainer into EchoThreadViewModel and EchoChatViewModel**

## Performance

- **Duration:** 12 min
- **Started:** 2026-04-05T03:10:00Z
- **Completed:** 2026-04-05T03:22:00Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- testBuildThreadMessagesForFreeChatIncludesTimeline: GREEN — freeChat system prompt now contains 【近期生活时间线】 when DayTimelineEntity records exist
- testSendMessagePassesTodayDataSummaryToPrompt: GREEN — EchoChatViewModel.sendMessage passes todayDataSummary to buildMessages instead of hardcoded nil
- Full data wiring chain complete: TodayViewModel.timelineDataSummary → AppRootScreen factory → AppContainer.makeEchoThreadViewModel → EchoThreadViewModel → buildThreadMessages → buildThreadSystemPrompt
- 214 tests pass (28 more than the 186 reported in 05-01, due to Plan 05-03 already being committed to the branch)

## Task Commits

1. **Task 1: EchoPromptBuilder timeline injection + test scaffolding** - `bb98c736` (feat)
2. **Task 2: Wire todayDataSummary through EchoThreadViewModel, AppContainer, AppRootScreen** - `3b6a0929` (feat)

## Files Created/Modified

- `ios/ToDay/ToDay/Data/AI/EchoPromptBuilder.swift` — Added todayDataSummary param to buildThreadMessages + buildThreadSystemPrompt; step 5.5 freeChat timeline injection; timelineContainer init param for test isolation
- `ios/ToDay/ToDay/Features/Echo/EchoThreadViewModel.swift` — Added todayDataSummary stored property + init param; passes it to buildThreadMessages
- `ios/ToDay/ToDay/Features/Echo/EchoChatViewModel.swift` — Added todayDataSummary: String? = nil property; sendMessage uses it instead of nil
- `ios/ToDay/ToDay/App/AppContainer.swift` — makeEchoThreadViewModel gains todayDataSummary: String? = nil parameter
- `ios/ToDay/ToDay/App/AppRootScreen.swift` — threadViewModelFactory passes todayViewModel.timelineDataSummary
- `ios/ToDay/ToDayTests/EchoPromptBuilderTests.swift` — DayTimelineEntity added to schema; builder initialized with timelineContainer; two new tests (freeChat timeline GREEN, non-freeChat exclusion GREEN)
- `ios/ToDay/ToDayTests/EchoChatViewModelTests.swift` — New testSendMessagePassesTodayDataSummaryToPrompt (GREEN)
- `ios/ToDay/ToDayTests/EchoAIServiceTests.swift` — MockAIProvider.lastReceivedMessages capture added

## Decisions Made

- EchoPromptBuilder gained `timelineContainer: ModelContainer?` init parameter (nil = use AppContainer.modelContainer singleton). This decouples unit tests from the singleton without requiring a protocol abstraction — minimal viable injection.
- Test for freeChat timeline requires a DayTimeline with non-mood InferredEvent entries. An empty entries array passes the `DayTimelineEntity` insert/save but `loadRecentTimelineSummaries` only appends summaries when `eventSummary` is non-empty. Fixed by seeding `.activeWalk` entry.
- Plan 05-01 changes (RED tests + stubs) only existed in `worktree-agent-ab5d2f0f` and were never merged to `feature/phone-first-auto-recording`. This plan caught up by adding both the test scaffolding and the GREEN implementation together.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added timelineContainer injection to EchoPromptBuilder**
- **Found during:** Task 1
- **Issue:** testBuildThreadMessagesForFreeChatIncludesTimeline seeds DayTimelineEntity into test container, but loadRecentTimelineSummaries uses AppContainer.modelContainer singleton — test data was invisible to builder
- **Fix:** Added `timelineContainer: ModelContainer? = nil` init param to EchoPromptBuilder; `loadRecentTimelineSummaries` uses `timelineContainer ?? AppContainer.modelContainer`; test passes container at builder creation
- **Files modified:** EchoPromptBuilder.swift, EchoPromptBuilderTests.swift
- **Verification:** testBuildThreadMessagesForFreeChatIncludesTimeline passes (GREEN)
- **Committed in:** bb98c736

**2. [Rule 1 - Bug] Fixed empty entries guard in timeline test**
- **Found during:** Task 1 verification
- **Issue:** Test seeded DayTimeline with `entries: []`; `loadRecentTimelineSummaries` filters/maps entries and skips empty eventSummary — no 【近期生活时间线】 section produced
- **Fix:** Changed test entry to `InferredEvent(kind: .activeWalk, ...)` with valid start/end times
- **Files modified:** EchoPromptBuilderTests.swift
- **Verification:** 16 EchoPromptBuilderTests pass
- **Committed in:** bb98c736

**3. [Rule 3 - Blocking] Added Plan 05-01 test scaffolding (catch-up)**
- **Found during:** Task 1 start
- **Issue:** Plan 05-01 task commit `f821f85` existed only in `worktree-agent-ab5d2f0f`, not in `feature/phone-first-auto-recording`. RED tests (testBuildThreadMessagesForFreeChatIncludesTimeline, testSendMessagePassesTodayDataSummaryToPrompt) and MockAIProvider.lastReceivedMessages were absent from the branch.
- **Fix:** Added RED test content + MockAIProvider capture + EchoChatViewModel.todayDataSummary stub as part of Plan 05-02 commits
- **Files modified:** EchoPromptBuilderTests.swift, EchoChatViewModelTests.swift, EchoAIServiceTests.swift, EchoChatViewModel.swift
- **Verification:** All 214 tests pass
- **Committed in:** bb98c736, 3b6a0929

---

**Total deviations:** 3 auto-fixed (1 blocking — container injection, 1 bug — empty entries, 1 blocking — catch-up)
**Impact on plan:** All auto-fixes required for the tests to actually pass. Container injection is a proper testability improvement that follows existing patterns. The catch-up adds code that was planned in 05-01 but never reached the main branch.

## Issues Encountered

The main unexpected issue was discovering Plan 05-01's task commit lived only in a separate worktree branch (`worktree-agent-ab5d2f0f`). The docs commit `ce31168` was present in `feature/phone-first-auto-recording` but the test code changes from `f821f85` were not. Also notable: Plan 05-03 (NavigationPath wiring) commits were already present in the branch at `16cd3333` and `66370dbb`, meaning 05-03 was executed before 05-02.

## Known Stubs

None — all previously-stubbed properties are now wired:
- EchoChatViewModel.todayDataSummary is set-able by parent and used in sendMessage
- EchoThreadViewModel.todayDataSummary is passed through to buildThreadMessages

## Next Phase Readiness

- Plan 05-03: NavigationPath wiring is already committed to the branch (`16cd3333`). STATE.md needs to advance to Plan 3 of 3 and then mark Phase 5 complete.
- AIC-01, AIC-02: Data wiring complete. Echo can now answer life data questions accurately.
- Remaining: 05-03 SUMMARY.md and state update needed.

## Self-Check: PASSED

- FOUND: ios/ToDay/ToDay/Data/AI/EchoPromptBuilder.swift
- FOUND: ios/ToDay/ToDay/Features/Echo/EchoThreadViewModel.swift
- FOUND: ios/ToDay/ToDay/Features/Echo/EchoChatViewModel.swift
- FOUND: ios/ToDay/ToDay/App/AppContainer.swift
- FOUND: ios/ToDay/ToDay/App/AppRootScreen.swift
- FOUND: 05-02-SUMMARY.md
- FOUND: commit bb98c736 (Task 1)
- FOUND: commit 3b6a0929 (Task 2)
- Test results: 214 tests, 0 failures

---
*Phase: 05-echo-conversation*
*Completed: 2026-04-05*
