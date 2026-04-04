# Architecture Patterns: Hybrid AI Layer for iOS Auto Life-Tracking

**Domain:** iOS passive sensor recording + AI analysis and conversation
**Researched:** 2026-04-04
**Overall confidence:** HIGH (existing codebase read directly; Apple FoundationModels framework verified via official Apple docs + WWDC25 content)

---

## Executive Summary

The codebase already has a complete sensor-to-timeline pipeline and a nearly complete AI layer (Echo). The challenge is not building from scratch — it is wiring the existing pieces together correctly, fixing the hardcoded API key, and making the on-device provider actually function once iOS 26 ships.

The architecture divides naturally into five horizontal layers: Sensor, Inference, Memory, AI Provider, and Presentation. The AI layer sits between Memory and Presentation. It consumes structured text summaries, never raw sensor data. This is both the correct privacy boundary and the right abstraction level for a language model.

---

## Existing Component Map

Verified by reading source directly on 2026-04-04.

```
Sensor Layer (all on-device, no network)
    LocationCollector          — CoreLocation significant changes + visits
    MotionCollector            — CoreMotion activity recognition
    DeviceStateCollector       — screen lock/unlock events
    PedometerCollector         — step count + distance
    HealthKitCollector         — optional, available flag checked at runtime
    SensorDataStore            — SwiftData persistence (SensorReadingEntity)

Inference Layer (on-device, rule-based, no ML/network)
    PhoneInferenceEngine       — priority-ordered rules: sleep → commute → exercise → stay → blank
    PlaceManager               — clustering + home/work/frequent classification
    CLGeocoder                 — reverse geocoding (network, lazy, cached)
    PhoneTimelineDataProvider  — orchestrates the above → DayTimeline

Memory Layer (SwiftData, all on-device)
    DayTimelineEntity          — raw timeline persistence per date
    EchoMemoryManager          — 4-layer memory system
        UserProfileEntity       — Layer 1: long-term portrait (~200 chars, weekly update)
        DailySummaryEntity      — Layer 2: per-day AI summary (30-day rolling)
        [today data]            — Layer 3: derived on-the-fly from DayTimelineEntity
        ConversationMemoryEntity — Layer 4: compressed conversation history

AI Layer (hybrid: on-device preferred, cloud fallback)
    EchoAIService              — routes to provider by tier, fallback logic
        AppleLocalAIProvider   — free tier; iOS 26+ FoundationModels framework (PLACEHOLDER TODAY)
        DeepSeekAIProvider     — pro tier; DeepSeek cloud API (HARDCODED KEY — MUST FIX)
    EchoPromptBuilder          — assembles context: personality + L1 + L2 + L3 + L4 + user input
    EchoDailySummaryGenerator  — pulls timeline → prompt → AI → DailySummaryEntity
    EchoWeeklyProfileUpdater   — pulls L2 summaries → prompt → AI → UserProfileEntity
    EchoScheduler              — triggers: app-background (daily), app-launch (weekly), strong emotion

Presentation Layer
    TodayViewModel + TodayScreen    — current main view, shows DayTimeline
    EchoMessageManager              — inbox of AI-generated messages
    EchoThreadViewModel / EchoScreen — chat threads per message
    EchoChatViewModel               — freeform chat
    CareNudgeEngine                 — (older system, parallel to EchoScheduler)
```

---

## Component Boundaries

### Sensor Layer → Inference Layer

The sensor layer produces `[SensorReading]` — tagged, timestamped payloads of `.location`, `.motion`, `.deviceState`, `.pedometer`, `.healthKit` types. It persists to `SensorDataStore` via `SensorReadingEntity`.

`PhoneInferenceEngine` consumes `[SensorReading]` and produces `[InferredEvent]` using deterministic rules. No ML model is involved here. The boundary is clean: raw readings in, structured events out.

**What must NOT cross this boundary:** Any AI call. The inference engine must remain deterministic and synchronous. This is what makes the 180 tests possible.

### Inference Layer → Memory Layer

`PhoneTimelineDataProvider` calls the inference engine and hands off `DayTimeline` (containing `[InferredEvent]`). This is persisted as `DayTimelineEntity`.

The AI layer reads `DayTimelineEntity` to construct "Layer 3" context — today's data as structured text. The conversion happens in `EchoPromptBuilder.loadRecentTimelineSummaries()` and `EchoScheduler.loadTodayTimelineSummary()`.

**Boundary contract:** The AI layer never reads raw `SensorReadingEntity`. It only reads `DayTimelineEntity`. This is already enforced in the codebase.

### Memory Layer → AI Provider Layer

`EchoPromptBuilder` serializes the four memory layers into a text prompt. This is the critical privacy transform: structured personal data enters, a natural-language prompt leaves.

The only thing sent to the cloud API is this assembled text prompt. Raw sensor readings, precise GPS coordinates, and identifiers never leave the device.

### AI Provider Layer → Presentation Layer

`EchoAIService` returns a `String`. That string is stored in `DailySummaryEntity` (for summaries), `UserProfileEntity` (for profile), or returned directly to a `ViewModel` (for chat). The presentation layer is purely a consumer — it does not call AI providers directly.

---

## Data Flow: Hybrid AI Decision Logic

```
User opens app (or app enters background after 20:00)
         |
         v
EchoScheduler.onAppBackground()
         |
         v
loadTodayTimelineSummary()  <-- reads DayTimelineEntity, formats as text
         |
         v
EchoPromptBuilder.buildDailySummaryPrompt()
    [personality prefix]
    [user profile: ~200 chars]
    [7 recent summaries: ~700 chars]
    [today events: event-name + duration pairs, no GPS]
    [mood notes if any]
         |
         v
EchoAIService.summarize(prompt)
         |
    tier = .free AND iOS 26+ AND Apple Intelligence enabled?
         |--- YES --> AppleLocalAIProvider (FoundationModels, on-device, no network)
         |
    tier = .free AND device not eligible?
         |--- YES --> falls back to DeepSeekAIProvider (cloud, sends assembled prompt)
         |
    tier = .pro?
         |--- YES --> DeepSeekAIProvider (cloud, sends assembled prompt)
         |
         v
EchoDailySummaryGenerator parses response → stores DailySummaryEntity
         |
         v
EchoMessageManager.generateMessage() → creates EchoMessageEntity + chat thread
         |
         v
UI: inbox shows new message, user opens thread
```

---

## What Stays On Device vs. What Goes to Cloud

| Data type | On-device | Cloud |
|-----------|-----------|-------|
| Raw sensor readings (GPS coords, motion samples) | Always | Never |
| Inferred events (event kind + duration + place name) | Always | Never |
| Place names from PlaceManager (home/work labels) | Always | Never |
| Assembled text prompt (summary of events, no GPS) | Always | Optional |
| AI-generated summary text | Stored locally | Received from cloud (if using cloud provider) |
| User profile portrait | Stored locally | Derived in cloud from summaries only |
| Conversation history | Stored locally | Last N turns in chat context window |

**GPS coordinates are never serialized into prompts.** `EchoPromptBuilder.loadRecentTimelineSummaries()` formats events as `"事件类型: 地点名称 (时长)"` — place names that are already geocoded strings, not coordinates. This is already correct in the existing code.

**What the cloud provider sees** (DeepSeek call): personality prefix + ~200 char profile + ~700 chars of recent daily summaries + today's event list as labeled text + mood notes. This is a ~2,000 token context max. No UUIDs, no precise coordinates, no device identifiers.

---

## Privacy Architecture

### Existing Safeguards (verified in code)

1. `EchoPromptBuilder.loadRecentTimelineSummaries()` formats events as `"kind: name (duration)"` strings — no coordinates.
2. `DailySummaryEntity` stores AI output, not raw inputs — the summary itself is privacy-preserving by nature.
3. The `DeepSeekAIProvider` sends only the assembled prompt string over HTTPS to `api.deepseek.com`.
4. The `AppleLocalAIProvider` sends nothing over the network when functioning.

### Critical Issue: Hardcoded API Key

`DeepSeekAIProvider` contains a hardcoded default key (`sk-94d311f460e54b4cac9c216ed8d5af36`). This key is committed to source and will end up in the shipped binary. This is the most urgent security issue in the AI layer.

**Fix required before shipping:** Remove `defaultAPIKey`. Gate `isAvailable` on `stored != nil && !stored.isEmpty`. Provide UI in Settings for the user to enter their own key, or implement a relay backend that proxies requests without exposing the key in the binary.

### Prompt Minimization Principle

The current `buildDailySummaryPrompt` sends: today-data + shutter texts + mood notes. This is appropriate. The weekly profile updater sends: current profile + 7 recent summaries. Also appropriate.

The only risk is `buildSystemPrompt` calling `loadRecentTimelineSummaries(days: 7)` in addition to the existing `recentSummaries` Layer 2 data. This doubles the historical context being sent. Consider making the timeline history opt-out at prompt assembly time to keep cloud payloads minimal.

### Anonymization for Cloud

If adding explicit anonymization before cloud calls:
- Strip any place name that exactly matches a known high-sensitivity label (home address geofence label) — replace with category only ("家" rather than user-set address string)
- Never include UIDevice identifiers in prompts
- These are not critical for MVP but worth noting for a privacy policy update

---

## On-Device ML Components

### Current State (as of 2026-04-04)

`AppleLocalAIProvider` is a complete placeholder. The iOS 26 FoundationModels API is stubbed but not implemented. The placeholder returns `"[本地 AI] 收到：..."`.

### FoundationModels Framework (iOS 26+)

Verified via Apple developer documentation (Sept 2025 release, WWDC25 Session 301).

**Key facts:**
- `SystemLanguageModel.default` — access the ~3B parameter on-device model
- `SystemLanguageModel.default.availability` — returns `.available`, `.unavailable(.deviceNotEligible)`, `.unavailable(.appleIntelligenceNotEnabled)`, or `.unavailable(.modelNotReady)`
- `LanguageModelSession(instructions:)` — creates a stateful session with a system prompt
- `session.respond(to:)` — async, returns complete response
- `session.streamResponse(to:)` — async sequence for streaming tokens
- `@Generable` macro — structured output with constrained decoding (equivalent to JSON schema)
- Requires Xcode 26, device with Apple Intelligence enabled
- iOS 26+ only; must be wrapped in `#available(iOS 26, *)`

**Correct implementation for `AppleLocalAIProvider`:**

```swift
@available(iOS 26, *)
private func _respond(messages: [EchoChatMessage]) async throws -> String {
    import FoundationModels

    let model = SystemLanguageModel.default
    guard case .available = model.availability else {
        throw EchoAIError.modelNotSupported
    }

    let systemMsg = messages.first(where: { $0.role == .system })?.content ?? ""
    let session = LanguageModelSession(instructions: systemMsg)

    // Build conversation turns (exclude system message)
    let turns = messages.filter { $0.role != .system }
    // For multi-turn, respond to the last user message
    // (LanguageModelSession maintains context internally)
    guard let lastUserMsg = turns.last(where: { $0.role == .user })?.content else {
        throw EchoAIError.invalidResponse
    }

    let response = try await session.respond(to: lastUserMsg)
    return response.content
}
```

**Note on session reuse:** `LanguageModelSession` retains context across calls. For Echo chat, create one session per `EchoChatSession` entity and reuse it for the conversation lifetime rather than creating a new session per message. For daily summary generation (single-shot), create a fresh session per call.

**Note on `@Generable`:** The structured output macro is ideal for extracting mood trend from summary responses — replaces the current brittle string-parsing in `parseSummaryResponse`. This is a future improvement, not blocking.

### Core ML (for Pattern Recognition — future)

For the "AI 模式识别" requirement (recognizing cross-day behavior patterns like "你连续3天下午都在图书馆"), pure LLM prompting over 7-day summaries is sufficient for MVP. Core ML becomes relevant only if you want on-device classification that runs in background without requiring Apple Intelligence.

A Core ML `MLClassifier` or sequence model could eventually replace the rule-based `PhoneInferenceEngine` for higher-confidence activity recognition. This is out of scope for the current milestone.

---

## Suggested Build Order

Dependencies flow from bottom up. Each step has a clear prerequisite.

### Step 1: Fix the API Key Security Issue (no dependencies)

Remove the hardcoded `defaultAPIKey` from `DeepSeekAIProvider`. Gate `isAvailable` purely on user-configured key. Add a Settings UI field for the DeepSeek API key. This is blocking for any release.

No other component depends on this — it is purely a security fix in one provider.

### Step 2: Wire EchoScheduler into App Lifecycle (depends on Step 1)

`EchoScheduler.onAppBackground()` and `onAppLaunch()` are fully implemented but not called from the app entry point. The scheduler needs to be invoked in `AppDelegate`/`SceneDelegate` lifecycle hooks (or equivalent SwiftUI `.onReceive` of `UIApplication.willResignActiveNotification`).

`EchoScheduler` is already instantiated in `AppContainer`. It just needs to be called.

**Also:** `EchoScheduler.setMessageManager()` is already called lazily via `AppContainer.echoMessageManager`. Verify the initialization order does not produce a nil `messageManager` at trigger time.

### Step 3: Connect TodayViewModel → EchoScheduler Data Feed (depends on Step 2)

`EchoScheduler.onAppBackground()` accepts `todayDataSummary`, `shutterTexts`, `moodNotes`. Currently it falls back to `loadTodayTimelineSummary()` when the summary string is empty.

`TodayViewModel` already holds the current `DayTimeline`. Add a method to format this as the summary string (or expose the existing `buildSummary` logic from `PhoneTimelineDataProvider`). Pass it through when triggering the scheduler on background.

### Step 4: Implement AppleLocalAIProvider (depends on Xcode 26 / iOS 26 availability)

Replace the placeholder `_respond` and `_generateText` methods with real FoundationModels API calls per the pattern above. This unblocks the free-tier path.

Until iOS 26 is stable, the free-tier user falls back to DeepSeek (existing fallback logic). The only users gated on this are those without an API key and without iOS 26.

### Step 5: Present AI Summary in Today Screen (depends on Steps 1–3)

`DailySummaryEntity` is being stored but never surfaced in `TodayScreen`. Add a summary card or inline insight element to `TodayScreen` that reads the most recent `DailySummaryEntity` for the displayed date.

This is the only step that requires UI work. Steps 1–4 are all data-pipeline wiring.

### Step 6: Pattern Recognition (depends on Step 5, 7+ days of data)

Once daily summaries accumulate, extend `EchoPromptBuilder` with a pattern-detection prompt that scans the last 14–30 days of `DailySummaryEntity` records. This is a new prompt type, not a new architectural component.

No new storage models needed. No Core ML required. Pure prompt engineering over the existing Layer 2 data.

### Step 7: Push Notifications for Proactive Insights (depends on Step 6)

`CareNudgeEngine` is present but appears to be an older parallel system. Evaluate whether it should be extended or replaced by `EchoScheduler`-driven notifications. Either way, this requires `UNUserNotificationCenter` integration and a notification trigger in `EchoScheduler.onStrongEmotion()` / pattern detection.

---

## Architecture Anti-Patterns to Avoid

### Anti-Pattern 1: Calling AI from Inference Layer

Introducing an LLM call inside `PhoneInferenceEngine` to improve activity classification would break the synchronous, testable nature of the engine and couple sensor collection to network availability.

**Instead:** Keep `PhoneInferenceEngine` as deterministic rules. If LLM-enhanced classification is needed later, create a separate `AIAssistedInferenceEngine` that wraps the rule-based engine and applies LLM post-processing as an optional enrichment step.

### Anti-Pattern 2: Sending Raw GPS to Cloud

Never pass `CLLocationCoordinate2D` values into the prompt builder. The current code is clean here. The risk is a future developer adding location-aware features and reaching for coordinates directly.

**Instead:** Always resolve coordinates to place names via `PlaceManager` before any AI context assembly. If a coordinate is unknown, use a generic description ("未知地点") rather than the raw coordinate.

### Anti-Pattern 3: One Session Per Message

For chat features, creating a new `LanguageModelSession` (FoundationModels) per user turn discards the context window and produces incoherent responses.

**Instead:** Cache a `LanguageModelSession` instance keyed by `EchoChatSessionEntity.id`. Invalidate and recreate on app restart or when the session entity is deleted.

### Anti-Pattern 4: Running AI Summarization on Main Thread

`EchoScheduler.onAppBackground()` is marked `async` and should run on a background actor. Calling it from a `@MainActor` context without `Task { ... }` wrapping can block UI.

**Existing code is correct** — `EchoMessageManager.generateMessage` is `@MainActor` with an explicit `await MainActor.run` wrapper inside the scheduler. Keep this pattern.

### Anti-Pattern 5: Premature Core ML

It is tempting to build a custom Core ML model for activity recognition to "improve" on `PhoneInferenceEngine`. At the current user scale (zero to hundreds), the rule-based engine already produces correct output (180 passing tests). Core ML adds build complexity, model versioning, and a training data problem.

**Instead:** Stick with rule-based inference until users surface specific misclassification patterns. Use the LLM summaries as the AI layer, not Core ML.

---

## Scalability Notes

The architecture described here is appropriate for one-person development and a user base up to ~50K MAU without backend changes.

| Concern | Current approach | Limit | When to revisit |
|---------|-----------------|-------|-----------------|
| Cloud API cost | DeepSeek per-token | Scales with DAU | Add caching (don't re-summarize if timeline unchanged) |
| On-device storage | SwiftData, unbounded | ~30-day pruning built in | Already handled in `pruneOldSummaries` |
| Background runtime | BGProcessingTask + app-background trigger | iOS limits background time | If ML gets heavier, use `BGContinuedProcessingTask` (iOS 26) for user-initiated summaries |
| Memory layer size | 4 layers, text only | Prompt token budget ~4K | Add token counting before prompt assembly if summaries get verbose |
| API key exposure | Hardcoded (BUG) | Ship blocker | Fix in Step 1 |

---

## Sources

- Apple FoundationModels framework (official): https://developer.apple.com/documentation/FoundationModels
- AppCoda FoundationModels iOS 26 guide: https://www.appcoda.com/foundation-models/
- CreateWithSwift FoundationModels exploration: https://www.createwithswift.com/exploring-the-foundation-models-framework/
- Apple newsroom FoundationModels announcement (Sept 2025): https://www.apple.com/newsroom/2025/09/apples-foundation-models-framework-unlocks-new-intelligent-app-experiences/
- Apple ML Research — Foundation Models 2025 updates: https://machinelearning.apple.com/research/apple-foundation-models-2025-updates
- BGContinuedProcessingTask / iOS 26 background APIs: https://dev.to/arshtechpro/wwdc-2025-ios-26-background-apis-explained-bgcontinuedprocessingtask-changes-everything-9b5
- AnyLanguageModel Swift package (Hugging Face / mattt): https://github.com/mattt/AnyLanguageModel
- LLMSense — sensor traces to LLM reasoning: https://arxiv.org/html/2403.19857v1
- Apple Private Cloud Compute privacy architecture: https://security.apple.com/blog/private-cloud-compute/
- Existing codebase: `/Users/looanli/Projects/ToDay/ios/ToDay/ToDay/Data/AI/` (read directly)
