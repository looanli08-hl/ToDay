# Phase 5: Echo Conversation - Research

**Researched:** 2026-04-04
**Domain:** SwiftUI conversational AI interface — wiring existing Echo chat infrastructure to live timeline data
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| AIC-01 | User can ask Echo questions about their life data ("我这周运动了几次？") | EchoChatViewModel.sendMessage + EchoPromptBuilder.buildMessages already handle multi-turn chat; need to wire `todayDataSummary` and expand to multi-day timeline context |
| AIC-02 | Echo responds with accurate answers based on stored timeline data | `loadRecentTimelineSummaries(days:7)` in EchoPromptBuilder already queries DayTimelineEntity; critical gap is that EchoChatViewModel passes `todayDataSummary: nil`, so today's live data is never injected |
| AIC-03 | Echo conversation history persists across sessions | EchoChatSessionEntity + EchoChatMessageEntity + SwiftData cascade deletion are fully implemented; `EchoChatViewModel.loadCurrentSession()` loads today's session — works correctly today |
</phase_requirements>

---

## Summary

Phase 5 is almost entirely about wiring together infrastructure that already exists. The Echo chat stack — `EchoChatViewModel`, `EchoChatSessionEntity`, `EchoChatMessageEntity`, `EchoPromptBuilder`, `EchoAIService` — is fully implemented and tested. The UI layer — `EchoMessageListView`, `EchoThreadView`, `EchoChatScreen`, `EchoChatBubbleView`, `EchoChatInputBar` — is also complete. Conversation persistence via `EchoChatSessionEntity`/`EchoChatMessageEntity` (SwiftData cascade) is proven in 37 existing tests.

The primary gap preventing AIC-01 and AIC-02 from working is a single disconnected parameter: `EchoChatViewModel.sendMessage()` hardcodes `todayDataSummary: nil` instead of passing the live `TodayViewModel.timelineDataSummary`. The secondary gap is that the free-chat entry button in `EchoMessageListView` creates an `EchoMessageEntity` but doesn't navigate to it (no `NavigationPath` state driven by creation). The third gap is that the freeChat thread type (`EchoThreadViewModel`) uses `buildThreadMessages`, which doesn't inject live timeline data — only the "classic" `buildMessages` path (used by `EchoChatViewModel`) includes the 7-day `loadRecentTimelineSummaries`.

**Primary recommendation:** Fix the three gaps: (1) inject `TodayViewModel.timelineDataSummary` into `EchoChatViewModel.sendMessage`, (2) wire free-chat navigation in `EchoMessageListView`, (3) add `loadRecentTimelineSummaries` context to `buildThreadMessages` for freeChat threads so they answer data questions correctly.

---

## Standard Stack

### Core (already installed — no new dependencies)
| Component | Version | Purpose | Status |
|-----------|---------|---------|--------|
| SwiftData | iOS 17+ | Persisting EchoChatSessionEntity + EchoChatMessageEntity | Fully wired |
| EchoAIService | in-repo | Routes `respond(messages:)` to DeepSeekAIProvider | Complete, tested |
| EchoPromptBuilder | in-repo | Assembles system prompt from 4-layer memory + timeline | Complete, missing live data wiring |
| EchoChatViewModel | in-repo | Manages session, send, persist, memory update | Complete, missing todayDataSummary injection |
| EchoThreadViewModel | in-repo | Per-message-thread conversation | Complete, missing timeline context |
| EchoMessageManager | in-repo | CRUD for EchoMessageEntity list + unread badges | Complete |

**Installation:** None. Zero new Swift Package Manager dependencies required for this phase.

---

## Architecture Patterns

### Existing Project Structure (Echo feature)
```
ios/ToDay/ToDay/
├── Data/AI/
│   ├── EchoAIProviding.swift       -- EchoChatMessage, EchoPersonality, EchoAIError protocol
│   ├── EchoAIService.swift         -- Routes to DeepSeekAIProvider
│   ├── EchoPromptBuilder.swift     -- 4-layer context assembly + loadRecentTimelineSummaries
│   ├── EchoMemoryManager.swift     -- CRUD for Layer1/2/4 (UserProfile, DailySummary, ConvMemory)
│   ├── EchoMemoryEntities.swift    -- UserProfileEntity, DailySummaryEntity, ConversationMemoryEntity
│   ├── EchoChatSession.swift       -- EchoChatSessionEntity + EchoChatMessageEntity (@Model)
│   ├── EchoMessageManager.swift    -- EchoMessageEntity CRUD + badge count
│   └── EchoScheduler.swift        -- onAppBackground, onPatternCheck (generates messages)
├── Data/
│   ├── EchoMessageEntity.swift     -- @Model for inbox message list
│   └── EchoMessageStoring.swift    -- SwiftDataEchoMessageStore
├── Features/Echo/
│   ├── EchoMessageListView.swift   -- Tab root: inbox list + free-chat button
│   ├── EchoMessageCard.swift       -- Card cell in list
│   ├── EchoThreadView.swift        -- Per-message thread detail (NavigationLink destination)
│   ├── EchoThreadViewModel.swift   -- Thread VM (uses buildThreadMessages)
│   ├── EchoChatScreen.swift        -- Legacy full-screen chat (currently orphaned — not in tab)
│   ├── EchoChatViewModel.swift     -- Full chat VM (uses buildMessages; today data gap)
│   ├── EchoChatBubbleView.swift    -- Message bubble (user + assistant)
│   └── EchoChatInputBar.swift      -- Text input + send button
```

### Pattern 1: Message-Thread Architecture (existing, Phase 4)
**What:** Echo pushes messages into `EchoMessageEntity` inbox. Each message has a `threadId` pointing to an `EchoChatSessionEntity`. Users tap the message card to enter `EchoThreadView`, which renders the thread and allows continued conversation.
**Applies to:** dailyInsight, patternInsight, shutterEcho, freeChat threads
**Key implication for Phase 5:** The "ask Echo a question" flow is already this pattern — user taps "随便聊聊" → `createFreeChatMessage()` creates a message + session → user should navigate to that thread. The only missing piece is NavigationPath-driven navigation after creation.

### Pattern 2: Context Assembly (EchoPromptBuilder)
**What:** `buildSystemPrompt` assembles 5 sections: personality → user profile (Layer 1) → recent summaries (Layer 2) → 7-day timeline from DayTimelineEntity (Layer 3.5) → conversation memory (Layer 4) → today data (Layer 5). `buildThreadMessages` uses a parallel method `buildThreadSystemPrompt` that includes source-specific context but currently OMITS `loadRecentTimelineSummaries`.
**Critical gap for AIC-02:** `EchoChatViewModel.sendMessage` calls `buildMessages(todayDataSummary: nil)` — the nil is hardcoded, not a bug in the builder.

```swift
// Current (broken for AIC-02):
let messages = promptBuilder.buildMessages(
    userInput: trimmed,
    personality: personality,
    todayDataSummary: nil,          // <-- hardcoded nil, today's events never reach AI
    conversationHistory: history
)

// Fixed (requires TodayViewModel reference in EchoChatViewModel):
let messages = promptBuilder.buildMessages(
    userInput: trimmed,
    personality: personality,
    todayDataSummary: todayViewModel?.timelineDataSummary,
    conversationHistory: history
)
```

### Pattern 3: Session Persistence (already complete)
**What:** `EchoChatViewModel.loadCurrentSession()` fetches or creates a per-day `EchoChatSessionEntity`. Each `sendMessage` call appends an `EchoChatMessageEntity` (cascade-deleted with session). Session loads from SwiftData on every `.onAppear`.
**Status:** Fully implemented and covered by `EchoChatSessionTests.swift` and `EchoChatViewModelTests.swift`.

### Pattern 4: Free Chat Navigation Gap
**What:** `EchoMessageListView.freeChatButton` calls `createFreeChatMessage()`, which inserts a new `EchoMessageEntity` into the store and triggers `refresh()`. The list reloads — but there is no `NavigationPath` state wired to auto-push to the new message. The `NavigationLink(value: message.id)` in the `ForEach` only fires when the user taps the card, not programmatically.
**Fix pattern:**
```swift
// In EchoMessageListView:
@State private var navigationPath = NavigationPath()

// Replace NavigationStack with:
NavigationStack(path: $navigationPath) { ... }

// In freeChatButton:
Button {
    if let entity = try? messageManager.createFreeChatMessage() {
        navigationPath.append(entity.id)
    }
} label: { ... }
```

### Anti-Patterns to Avoid
- **Passing TodayViewModel as a retained strong reference into EchoChatViewModel:** Creates a reference cycle. Prefer passing `timelineDataSummary` as a `String?` parameter at call time, or store it as a `@Published var` on the chat ViewModel that the parent view updates via `.onChange`.
- **Rebuilding EchoChatScreenon the Echo tab:** `EchoChatScreen` is currently orphaned (not in the tab navigation). Do not re-introduce it as the primary chat surface — the `EchoMessageListView` + `EchoThreadView` pattern is the correct current architecture.
- **Fetching DayTimelineEntity inside a View:** Timeline data must be assembled in the ViewModel or in `EchoPromptBuilder`, never directly from a View. `loadRecentTimelineSummaries` already does this correctly.
- **Widening conversation history window beyond 20 turns:** `EchoChatViewModel` already caps at 20. Token budgets for DeepSeek calls are real — do not raise this limit.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Chat message persistence | Custom JSON file store | `EchoChatSessionEntity` / `EchoChatMessageEntity` (SwiftData, already in `AppContainer.modelContainer`) | Already exists, 9 test cases cover it |
| Multi-turn context window | Manual array slicing | `displayMessages.suffix(20).dropLast()` pattern in EchoChatViewModel | Already implemented and tested |
| Streaming AI response | Manual URLSession chunking | DeepSeekAIProvider's existing `respond(messages:)` — returns complete response; streaming is not needed for v1 | Complexity not justified for MVP |
| Keyboard avoidance in chat | Custom keyboard observer | `.scrollDismissesKeyboard(.interactively)` + ScrollViewReader already in EchoChatScreen/EchoThreadView | Native iOS 16+ API, already used |
| Typing indicator | Third-party animation | `EchoThinkingView` already exists in the codebase | Already built |

**Key insight:** This is a wiring phase, not a build phase. 90% of the code exists. The work is injecting the right data into the right call sites.

---

## Common Pitfalls

### Pitfall 1: todayDataSummary is nil in EchoChatViewModel
**What goes wrong:** Echo answers questions about the user's day but has no live data — it can only reference the 7-day historical timeline loaded from `DayTimelineEntity` (which doesn't include today until a snapshot is saved). Users asking "今天我走了多少步？" get a hallucinated or "I don't know" answer.
**Why it happens:** `EchoChatViewModel.sendMessage` hardcodes `todayDataSummary: nil` at line 129. The `TodayViewModel.timelineDataSummary` property exists and is correct but is not threaded through to the chat ViewModel.
**How to avoid:** Either inject `TodayViewModel` as a weak reference into `EchoChatViewModel` at creation time, or pass `timelineDataSummary` as a property that is set from the parent View using `.onChange`. The factory method `AppContainer.makeEchoChatViewModel()` must be updated to accept this dependency.
**Warning signs:** In testing, ask Echo "今天你干了什么" and it responds vaguely — that confirms the gap is still present.

### Pitfall 2: Free-chat button creates message but doesn't navigate
**What goes wrong:** User taps "跟 Echo 随便聊聊" — the message is created in SwiftData, the list reloads showing a new card at the bottom, but the app does not navigate into the thread. User sees a new card they have to tap again.
**Why it happens:** `NavigationLink(value: message.id)` is declarative — it reacts to user tap, not to programmatic `navigationPath.append(...)`. The current `freeChatButton` discards the result of `createFreeChatMessage()`.
**How to avoid:** Lift `NavigationPath` to a `@State` in `EchoMessageListView` and drive the `NavigationStack` with it. Append the new message's `id` immediately after creation.
**Warning signs:** Tapping "随便聊聊" creates a duplicate message each time without entering the thread.

### Pitfall 3: buildThreadMessages omits timeline context
**What goes wrong:** Users enter a freeChat thread (via EchoThreadView, which uses EchoThreadViewModel + buildThreadMessages) and ask data questions — but `buildThreadSystemPrompt` does not call `loadRecentTimelineSummaries`. So freeChat threads have less context than the "classic" EchoChatScreen.
**Why it happens:** `buildThreadSystemPrompt` was designed for source-specific threads (daily insight, shutter echo) where the sourceData carries the relevant context. freeChat threads have no sourceData and no timeline injection.
**How to avoid:** In `buildThreadSystemPrompt`, add `loadRecentTimelineSummaries` for `.freeChat` message types (or for all thread types unconditionally). This is a one-function addition to `EchoPromptBuilder`.
**Warning signs:** freeChat thread Echo knows your personality (from Layer 1) but can't answer "我这周去了哪些地方" accurately.

### Pitfall 4: EchoChatScreen vs EchoThreadView confusion
**What goes wrong:** Phase 5 plan accidentally re-activates `EchoChatScreen` (which has `EchoChatViewModel`) as the tab entry point, creating a second parallel chat flow that bypasses the `EchoMessageEntity` persistence model.
**Why it happens:** `EchoChatScreen` exists and was previously the main chat surface. It is fully functional but orphaned after Phase 4 introduced the message-thread model.
**How to avoid:** Keep `EchoMessageListView` as the Echo tab root. `EchoChatScreen` can be left dormant or deleted. The conversation entry point is always through `createFreeChatMessage()` → `EchoThreadViewModel`.
**Warning signs:** Two different "Echo" surfaces showing different conversation histories.

### Pitfall 5: Cross-day question accuracy depends on DayTimelineEntity being populated
**What goes wrong:** User asks "我这周运动了几次？" on day 1 after install — `loadRecentTimelineSummaries` returns empty because no `DayTimelineEntity` records exist yet (they're written by `BackgroundTaskManager` and `TodayViewModel.cacheTimeline`).
**Why it happens:** Phase 1 (security + AI pipeline) is listed as incomplete (0/3 plans) in the roadmap. The daily summary pipeline may not be fully wired. Echo can only answer historical questions if daily snapshots have been written.
**How to avoid:** The fix for AIC-02 accuracy is: (a) ensure today's live data is in the prompt via `timelineDataSummary`, and (b) document clearly in success criteria that cross-day queries require real device data. On simulator with mock data, cross-day answers will be minimal by design.

---

## Code Examples

### Injecting todayDataSummary — Recommended Pattern

The safest injection pattern avoids a TodayViewModel-EchoChatViewModel coupling by passing a closure or binding at the call site:

```swift
// In EchoMessageListView (or EchoThreadView for freeChat):
// Provide the live summary from TodayViewModel at view level
@ObservedObject var todayViewModel: TodayViewModel

// Pass into thread factory:
AppContainer.makeEchoThreadViewModel(for: message, todayDataSummary: todayViewModel.timelineDataSummary)
```

Or — the minimal-diff approach — update `AppContainer.makeEchoThreadViewModel`:

```swift
@MainActor
static func makeEchoThreadViewModel(
    for message: EchoMessageEntity,
    todayDataSummary: String? = nil
) -> EchoThreadViewModel {
    EchoThreadViewModel(
        threadId: message.threadId,
        sourceData: message.sourceData,
        messageType: message.messageType,
        sourceDescription: message.sourceData?.sourceDescription ?? "",
        aiService: echoAIService,
        memoryManager: echoMemoryManager,
        promptBuilder: echoPromptBuilder,
        container: modelContainer,
        todayDataSummary: todayDataSummary   // NEW
    )
}
```

### NavigationPath-Driven Free Chat Entry

```swift
// Source: SwiftUI NavigationStack documentation (iOS 16+)
struct EchoMessageListView: View {
    @ObservedObject var messageManager: EchoMessageManager
    let threadViewModelFactory: (EchoMessageEntity) -> EchoThreadViewModel
    @State private var navigationPath = NavigationPath()   // ADD

    // NavigationStack drives programmatic push:
    NavigationStack(path: $navigationPath) {               // CHANGE
        // ...ForEach + NavigationLink stays the same...

        // freeChatButton:
        Button {
            if let entity = try? messageManager.createFreeChatMessage() {
                navigationPath.append(entity.id)           // ADD: auto-navigate
            }
        } label: { ... }
    }
    .navigationDestination(for: UUID.self) { messageId in  // stays the same
        // ...
    }
}
```

### Adding Timeline Context to buildThreadSystemPrompt

```swift
// In EchoPromptBuilder.buildThreadSystemPrompt (after step 5 Recent Summaries):

// 5.5. Historical timeline (for freeChat — needs same data access as general chat)
if messageType == .freeChat {
    let timelineHistory = loadRecentTimelineSummaries(days: 7)
    if !timelineHistory.isEmpty {
        parts.append("【近期生活时间线】\n\(timelineHistory)")
    }
}
```

### Verifying Context Injection (Test Pattern)

```swift
// Existing EchoPromptBuilderTests.swift pattern to add:
func testBuildThreadMessagesForFreeChatIncludesTimeline() throws {
    // Insert a DayTimelineEntity with known events
    // ...
    let messages = builder.buildThreadMessages(
        userInput: "我上周去哪了",
        personality: .gentle,
        sourceData: nil,
        sourceDescription: "",
        messageType: .freeChat
    )
    let systemMessage = messages.first { $0.role == .system }
    XCTAssertTrue(systemMessage?.content.contains("近期生活时间线") ?? false)
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| EchoChatScreen as tab root | EchoMessageListView + EchoThreadView (message inbox model) | Phase 4 | freeChat is now one message type among many; EchoChatScreen is orphaned |
| todayDataSummary injected via EchoScheduler | todayDataSummary nil in EchoChatViewModel.sendMessage | Phase 4 split | Phase 5 must fix this regression |
| No pattern insight context in threads | EchoSourceData carries sourceDescription + dateRange for thread context | Phase 4 | Pattern-triggered threads are contextual; freeChat still isn't |

**Orphaned / dormant:**
- `EchoChatScreen.swift`: Previously the main chat surface, now never presented. Can be deleted after Phase 5 or kept as dead code. Do not restore it to the navigation graph.

---

## Open Questions

1. **Phase 1 (Security + AI Pipeline) is incomplete — does Phase 5 depend on it?**
   - What we know: Roadmap marks Phase 1 as "Not started" (0/3 plans). This means `DeepSeekAIProvider` still has a hardcoded API key. Echo conversation will work in development but cannot ship.
   - What's unclear: Whether Phase 5 execution should block on Phase 1 completion, or proceed with the understanding that the hardcoded key is a pre-ship blocker documented elsewhere.
   - Recommendation: Proceed with Phase 5 engineering. Note in plan success criteria that SEC-01/SEC-02 (Phase 1) must be complete before TestFlight distribution. The conversation wiring is independent of the key security issue.

2. **EchoChatViewModel vs EchoThreadViewModel: which is the canonical chat VM for Phase 5?**
   - What we know: `EchoChatViewModel` has `loadCurrentSession()` (day-scoped session) + temporary mode + mirror portrait. `EchoThreadViewModel` has thread-scoped session (linked to a specific `EchoMessageEntity`). The current tab root is `EchoMessageListView`, which navigates to `EchoThreadView` (using `EchoThreadViewModel`).
   - What's unclear: Whether Phase 5 should wire `todayDataSummary` into `EchoThreadViewModel` (preferred, since that's the live navigation path) or resurrect `EchoChatViewModel` for the freeChat flow.
   - Recommendation: Fix `EchoThreadViewModel` and `buildThreadSystemPrompt` for freeChat. `EchoChatViewModel` can remain dormant.

3. **Cross-day query accuracy on simulator**
   - What we know: `MockTimelineDataProvider` generates a fixed set of mock events for today. `DayTimelineEntity` records for past days only exist if the app ran on a real device and saved them.
   - What's unclear: Whether the plan should include a task to seed mock DayTimelineEntity records for tests.
   - Recommendation: Add a test task that seeds DayTimelineEntity records and verifies `loadRecentTimelineSummaries` returns them correctly in a prompt. This validates AIC-02 without requiring real device data.

---

## Environment Availability

Step 2.6: SKIPPED — Phase 5 is entirely code changes within the existing Swift/SwiftData stack. No new external tools, services, CLIs, databases, or runtimes are required.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (Apple native) |
| Config file | `ios/ToDay/project.yml` (scheme: ToDay) |
| Quick run command | `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ToDayTests/EchoChatViewModelTests -only-testing:ToDayTests/EchoPromptBuilderTests CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO` |
| Full suite command | `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AIC-01 | User sends a question; Echo responds with text | unit | `...EchoChatViewModelTests/testSendMessageAddsToDisplay` | ✅ (EchoChatViewModelTests.swift) |
| AIC-01 | freeChat navigation: tapping "随便聊聊" enters thread | unit/integration | new: `EchoMessageListViewNavigationTests` | ❌ Wave 0 |
| AIC-02 | Today's timeline data appears in system prompt | unit | new: `EchoPromptBuilderTests/testBuildMessagesIncludesLiveTimelineData` | ❌ Wave 0 |
| AIC-02 | freeChat thread includes 7-day timeline context | unit | new: `EchoPromptBuilderTests/testBuildThreadMessagesForFreeChatIncludesTimeline` | ❌ Wave 0 |
| AIC-02 | Cross-day query uses DayTimelineEntity records | unit | new: `EchoPromptBuilderTests/testBuildSystemPromptLoadsDayTimelineEntities` | ❌ Wave 0 (needs DayTimelineEntity in schema) |
| AIC-03 | Messages survive session load/reload | unit | `EchoChatViewModelTests/testLoadCurrentSession*` (add) | ❌ Wave 0 |
| AIC-03 | Session persists across app relaunch simulation | unit | `EchoChatSessionTests` (existing + extend) | ✅ (EchoChatSessionTests.swift) |

### Sampling Rate
- **Per task commit:** Quick run command (EchoChatViewModelTests + EchoPromptBuilderTests)
- **Per wave merge:** Full suite (`180+ tests`)
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `ToDayTests/EchoPromptBuilderTests.swift` — extend existing file with: `testBuildMessagesIncludesLiveTimelineData`, `testBuildThreadMessagesForFreeChatIncludesTimeline`, `testBuildSystemPromptLoadsDayTimelineEntities` (needs DayTimelineEntity added to test schema in setUp)
- [ ] `ToDayTests/EchoChatViewModelTests.swift` — extend with: session-persistence round-trip test, and `testSendMessagePassesTodayDataSummaryToPrompt`
- [ ] `ToDayTests/EchoMessageListViewNavigationTests.swift` — new file: programmatic navigation test for freeChat creation (can be a ViewModel-level test asserting `EchoMessageManager` returns the new message)

---

## Sources

### Primary (HIGH confidence)
- Direct codebase inspection — `EchoChatViewModel.swift` line 129: `todayDataSummary: nil` confirmed
- Direct codebase inspection — `EchoPromptBuilder.swift`: `loadRecentTimelineSummaries` confirmed present in `buildSystemPrompt`, absent from `buildThreadSystemPrompt`
- Direct codebase inspection — `EchoMessageListView.swift`: NavigationPath not present; freeChat button discards created entity
- Direct codebase inspection — `AppRootScreen.swift`: Echo tab root is `EchoMessageListView`, not `EchoChatScreen`
- Direct codebase inspection — `AppContainer.swift`: `makeEchoChatViewModel()` exists but is never called from current navigation paths
- Direct codebase inspection — `TodayViewModel.swift` line 508: `timelineDataSummary` computed property confirmed, used in `ToDayApp.swift` for EchoScheduler but not EchoChatViewModel

### Secondary (MEDIUM confidence)
- SwiftUI NavigationStack path-based navigation pattern (iOS 16+, well-established in Apple documentation)

### Tertiary (LOW confidence)
- None

---

## Metadata

**Confidence breakdown:**
- What exists: HIGH — direct codebase inspection, no inference
- The three gaps: HIGH — confirmed by reading the exact lines where nil is passed and where NavigationPath is absent
- Fix patterns: HIGH — established SwiftUI/SwiftData patterns used elsewhere in the same codebase
- Test coverage gaps: HIGH — confirmed by searching test files for missing test names

**Research date:** 2026-04-04
**Valid until:** 2026-05-04 (stable SwiftData/SwiftUI stack)
