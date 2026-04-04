# Phase 1: Security and AI Pipeline - Research

**Researched:** 2026-04-04
**Domain:** iOS AI pipeline security — API key removal, AIProxy integration, EchoScheduler wiring, Claude provider migration
**Confidence:** HIGH

---

## Summary

Phase 1 is a wiring and security phase, not a feature-building phase. The AI pipeline (EchoScheduler, EchoDailySummaryGenerator, EchoPromptBuilder, EchoMemoryManager) is fully implemented and already connected to the app lifecycle in `ToDayApp.swift`. The `EchoScheduler.onAppBackground()` is called from `.onChange(of: scenePhase)` and `onAppLaunch()` is called from `.task`. The scheduler is wired. The problem is the provider it calls: `DeepSeekAIProvider` has a hardcoded `defaultAPIKey` (`sk-94d311f460e54b4cac9c216ed8d5af36`) that will be embedded in every binary.

The work is: (1) delete `DeepSeekAIProvider.defaultAPIKey`, (2) add `AIProxySwift` as a Swift Package, (3) implement `AnthropicAIProvider` using AIProxy's `anthropicService`, (4) wire it as the `proProvider` in `EchoAIService`, (5) add client-side rate limiting (one summary per day already exists via `shouldGenerateDailySummary()` + `lastDailySummaryKey` in `EchoScheduler` — verify it enforces correctly), and (6) ensure the prompt builder never sends raw GPS coordinates (already correct in existing code). The `DailySummaryEntity` is persisted and the `EchoMessageManager` creates inbox messages — that pipeline is complete.

**Primary recommendation:** Replace `DeepSeekAIProvider` with a new `AnthropicAIProvider` that calls Anthropic's Messages API through `AIProxySwift`. Wire `AnthropicAIProvider` as `proProvider` in `EchoAIService`. The existing `EchoScheduler` rate limiting (one summary/day via UserDefaults key) is functional but should be verified against the success criteria. No EchoScheduler lifecycle wiring is needed — it is already done.

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SEC-01 | App binary does not contain any hardcoded API keys or secrets | Remove `defaultAPIKey` from `DeepSeekAIProvider`; AIProxy's split-key model ensures no full key in binary |
| SEC-02 | Cloud API calls route through AIProxy or equivalent key protection layer | AIProxySwift package routes all Anthropic calls through AIProxy backend with DeviceCheck |
| SEC-03 | AI API calls have per-user daily rate limits to prevent cost runaway | AIProxy dashboard rate limits + existing `shouldGenerateDailySummary()` client-side guard (1 per day) |
| AIS-01 | App generates a short AI summary of the user's day using cloud API | `EchoDailySummaryGenerator` calls `EchoAIService.summarize(prompt:)` — wire `AnthropicAIProvider` as proProvider |
| AIS-02 | Summary references specific places and activities from the user's actual data | `EchoPromptBuilder.buildDailySummaryPrompt` already formats events as `"kind: place (duration)"` — place names, not GPS |
| AIS-04 | Summary tone is observational, never prescriptive | Enforced in the system prompt prefix — needs explicit instruction added to `buildDailySummaryPrompt` |
| AIS-05 | Summary generation runs automatically when user opens app in evening or on app background | `ToDayApp.onChange(scenePhase: .background)` already calls `echoScheduler.onAppBackground()` |
| PRV-01 | No raw GPS coordinates are sent to cloud AI — only place names and event descriptions | `EchoPromptBuilder.loadRecentTimelineSummaries()` formats as text strings, not coordinates — already correct |
</phase_requirements>

---

## Project Constraints (from CLAUDE.md)

- **Build command:** `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`
- **Test command:** `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`
- **Validation flow:** Every change requires `xcodegen generate` → build passes → 180+ tests pass
- **No third-party UI frameworks** — this phase adds no UI, so no conflict
- **Privacy constraint:** Cloud API calls pass only necessary context, never raw location data
- **AI backend:** Hybrid architecture — device for simple inference, cloud API for complex analysis
- **Solo dev:** Scope must stay tight
- **Project file management:** `project.yml` generates `.xcodeproj` via XcodeGen; all new Swift Package dependencies added through Xcode UI or `project.yml` packages section

---

## Standard Stack

### Core (for this phase)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| AIProxySwift | main branch | Routes Anthropic API calls through secure proxy; key never in binary | Split-key encryption + DeviceCheck; free tier for development; used by hundreds of iOS AI apps |
| Anthropic Messages API | `2023-06-01` (via AIProxy) | Cloud LLM for daily summary generation | Claude Haiku 4.5 at $1/$5 per MTok is the cheapest capable model; Anthropic is the right privacy story |
| Claude Haiku 4.5 | `claude-haiku-4-5-20251001` | Primary model for daily summaries (1-2 sentences, 100-150 chars Chinese) | Fastest + cheapest current Anthropic model; 200k context; retired Haiku 3 deprecated April 2026 |
| UserDefaults (existing) | iOS 17+ | `lastDailySummaryKey` guards against multiple calls per day | Already implemented in `EchoScheduler.shouldGenerateDailySummary()` |

**Note on model selection:** Claude Haiku 3.5 (`claude-3-5-haiku-20241022`) is still available but Claude Haiku 4.5 (`claude-haiku-4-5-20251001`) is the current generation and the AIProxy README's own example already uses `claude-haiku-4-5-20251001`. Use Haiku 4.5. Claude 3 Haiku is deprecated and retires April 19, 2026 — do not use it.

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Foundation URLSession | iOS 17+ | Fallback for direct HTTP if AIProxy unavailable | Not needed — AIProxy handles HTTP |
| XCTest (existing) | iOS 17+ | MockAIProvider already exists for unit tests | All AI provider tests use MockAIProvider |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| AIProxySwift | SwiftAnthropic (github.com/jamesrochabrun/SwiftAnthropic) | SwiftAnthropic requires embedding the full API key; AIProxy solves key security without a backend |
| AIProxySwift | Own Cloudflare Worker | Worker gives full control + 100k free req/day but requires you to build/maintain the backend; AIProxy is faster for MVP |
| Claude Haiku 4.5 | Claude Sonnet 4.6 | Sonnet is 3x more expensive ($3/$15); daily summary is 100-150 Chinese chars, well within Haiku's capability |

**Installation (via Xcode):**
```
File > Add Package Dependencies
URL: github.com/lzell/aiproxyswift
Rule: main branch (or latest release)
```

**Installation (via project.yml — preferred for XcodeGen):**
```yaml
packages:
  AIProxy:
    url: https://github.com/lzell/AIProxySwift
    branch: main

targets:
  ToDay:
    dependencies:
      - package: AIProxy
```

After adding to `project.yml`, run `xcodegen generate`.

---

## Architecture Patterns

### Existing Component Map (AI Layer)

The AI layer is in `ios/ToDay/ToDay/Data/AI/`. All files read directly from source.

```
Data/AI/
├── EchoAIProviding.swift          — Protocol + EchoChatMessage + EchoPersonality + EchoUserTier + EchoAIError
├── EchoAIService.swift            — Routes to freeProvider (AppleLocalAIProvider) or proProvider (DeepSeekAIProvider)
├── DeepSeekAIProvider.swift       — HARDCODED KEY on line 18 — MUST DELETE defaultAPIKey
├── AppleLocalAIProvider.swift     — iOS 26+ placeholder, returns stub strings
├── EchoPromptBuilder.swift        — Assembles 4-layer context prompt (no GPS, place names only)
├── EchoDailySummaryGenerator.swift — Calls promptBuilder → aiService → saves DailySummaryEntity
├── EchoScheduler.swift            — Triggers on app background/launch; already wired in ToDayApp.swift
├── EchoMemoryManager.swift        — CRUD for all 4 memory layers (UserProfileEntity, DailySummaryEntity, etc.)
├── EchoWeeklyProfileUpdater.swift — Weekly profile synthesis
└── EchoMessageManager.swift       — Creates EchoMessageEntity inbox items from summaries
```

### What is Already Wired (do not re-wire)

Read `ToDayApp.swift` directly — the scheduler IS already called:

```swift
// In ToDayApp.body — already exists:
.task {
    await echoScheduler.onAppLaunch()   // weekly profile check
}
.onChange(of: scenePhase) { _, newPhase in
    case .background:
        Task {
            await echoScheduler.onAppBackground(   // daily summary trigger
                todayDataSummary: viewModel.timelineDataSummary,
                shutterTexts: viewModel.todayShutterTexts,
                moodNotes: viewModel.todayMoodNotes
            )
        }
}
```

Also confirmed: `AppContainer.echoMessageManager` lazy property calls `echoScheduler.setMessageManager(manager)` — the circular dependency is resolved at initialization.

### Pattern 1: AnthropicAIProvider (new file to create)

Follows the exact same structure as `DeepSeekAIProvider` but uses AIProxySwift:

```swift
// Source: github.com/lzell/AIProxySwift README — Anthropic section
import Foundation
import AIProxy

final class AnthropicAIProvider: EchoAIProviding, @unchecked Sendable {

    // Partial key from AIProxy dashboard — safe to include in binary
    private static let partialKey = "REPLACE_WITH_AIPROXY_PARTIAL_KEY"
    private static let serviceURL = "REPLACE_WITH_AIPROXY_SERVICE_URL"

    private let service: AnthropicService

    init() {
        self.service = AIProxy.anthropicService(
            partialKey: Self.partialKey,
            serviceURL: Self.serviceURL
        )
    }

    var isAvailable: Bool { true }  // AIProxy handles availability

    func summarize(prompt: String) async throws -> String {
        let requestBody = AnthropicMessageRequestBody(
            maxTokens: 512,
            messages: [AnthropicMessageParam(content: prompt, role: .user)],
            model: "claude-haiku-4-5-20251001",
            system: "你是一个生活数据分析助手。根据提供的数据，生成简洁的中文摘要，描述用户今天的生活，不评价，不建议。"
        )
        let response = try await service.messageRequest(body: requestBody, secondsToWait: 30)
        guard let textBlock = response.content.first,
              case let .textBlock(block) = textBlock else {
            throw EchoAIError.invalidResponse
        }
        return block.text
    }

    func respond(messages: [EchoChatMessage]) async throws -> String {
        // Map EchoChatMessage → AnthropicMessageParam
        let anthropicMessages = messages
            .filter { $0.role != .system }
            .map { AnthropicMessageParam(content: $0.content, role: $0.role == .user ? .user : .assistant) }
        let systemMsg = messages.first(where: { $0.role == .system })?.content ?? ""

        let requestBody = AnthropicMessageRequestBody(
            maxTokens: 1024,
            messages: anthropicMessages,
            model: "claude-haiku-4-5-20251001",
            system: systemMsg
        )
        let response = try await service.messageRequest(body: requestBody, secondsToWait: 30)
        guard let textBlock = response.content.first,
              case let .textBlock(block) = textBlock else {
            throw EchoAIError.invalidResponse
        }
        return block.text
    }

    func generateProfile(prompt: String) async throws -> String {
        return try await summarize(prompt: prompt)
    }
}
```

**Note:** `AnthropicMessageRequestBody`, `AnthropicMessageParam`, and `AnthropicService` are types from AIProxySwift. The exact type names may differ slightly — verify against the actual package source after installation.

### Pattern 2: EchoAIService Wiring Change

One line change in `EchoAIService.init()`:

```swift
// Current (in AppContainer.swift):
private static let echoAIService = EchoAIService()
// EchoAIService default init uses:
//   freeProvider: AppleLocalAIProvider()
//   proProvider: DeepSeekAIProvider()   <-- REPLACE

// After change (AppContainer.swift line ~23):
private static let echoAIService = EchoAIService(
    freeProvider: AppleLocalAIProvider(),
    proProvider: AnthropicAIProvider()   // new
)
```

Or equivalently, change `EchoAIService.init` default argument.

### Pattern 3: AIProxy Configuration in ToDayApp

AIProxy requires `AIProxy.configure()` called at app launch. Add to `ToDayApp.init()`:

```swift
// Source: AIProxySwift README — SwiftUI app initialization
import AIProxy

@main
struct ToDayApp: App {
    init() {
        AIProxy.configure(
            logLevel: .warning,       // .debug during development
            resolveDNSOverTLS: true,
            useStableID: true         // iCloud KV for per-user rate limiting across devices
        )
        backgroundTaskManager.registerTasks()
    }
    // ...
}
```

`useStableID: true` requires adding iCloud Key-Value storage capability to `project.yml` entitlements:

```yaml
entitlements:
  properties:
    com.apple.developer.icloud-services:
      - CloudKit             # only if you want; for KV store only:
    com.apple.developer.ubiquity-kvstore-identifier: $(TeamIdentifierPrefix)$(CFBundleIdentifier)
```

Simpler path: add iCloud capability via Xcode Signing & Capabilities → iCloud → check "Key-Value storage".

### Pattern 4: Simulator DeviceCheck Bypass

AIProxy cannot call Apple DeviceCheck in the simulator. Set env variable in Xcode scheme for development:

```
Product > Scheme > Edit Scheme > Run > Arguments > Environment Variables:
AIPROXY_DEVICE_CHECK_BYPASS = <value from AIProxy dashboard>
```

This env var must NOT be included in any TestFlight or App Store distribution. The AIProxy SDK reads it automatically — no code changes needed. The value is obtained from the AIProxy developer dashboard.

### Pattern 5: Prompt Tone Guard (AIS-04)

The existing `buildDailySummaryPrompt` in `EchoPromptBuilder.swift` does not explicitly prohibit prescriptive language. Add this instruction to the prompt:

```swift
// In buildDailySummaryPrompt(), update the opening instruction:
parts.append("""
请根据以下数据，生成一段简洁的中文日记摘要（100-150字）。\
摘要应描述用户今天做了什么，用观察性语气（"你今天..."），\
不评判、不建议、不使用"应该"/"要"/"需要"等词语。\
包含关键活动、情绪和值得记住的细节。
""")
```

This satisfies AIS-04 without changing any other code.

### Pattern 6: Rate Limiting — Client-Side (already exists)

`EchoScheduler.shouldGenerateDailySummary()` checks `UserDefaults.standard.string(forKey: "today.echo.lastDailySummaryDate")` against today's date string. If it matches, it returns `false` and the summary is skipped. This is enforced before any network call. The server-side rate limit in AIProxy dashboard is a second layer of protection.

**Verification needed:** The `shouldGenerateDailySummary()` check does NOT check `isAfterDailySummaryHour()` — these are two separate methods. `onAppBackground()` calls both with `&&`. This is correct: one summary per day, only after 20:00.

### Anti-Patterns to Avoid

- **Do not add GPT-4o or Gemini as providers.** GPT-4o costs 5x more; Gemini requires Firebase. The existing `EchoAIProviding` protocol is provider-agnostic — just add `AnthropicAIProvider`.
- **Do not implement a custom key storage in Keychain.** The whole point of AIProxy is that the key never touches the device. Don't create a hybrid where part of the key is in Keychain.
- **Do not change EchoScheduler's lifecycle hooks.** They are already wired correctly in `ToDayApp.swift`. Touching them risks double-triggering.
- **Do not change EchoAIService routing logic.** The tier-based routing (free → local → cloud fallback) is correct. Only swap the concrete provider injected as `proProvider`.
- **Do not call `AIProxy.configure()` inside a view.** It must run at app init before any AI call.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| API key security | Custom key obfuscation, Keychain splitting, server-side proxy | AIProxySwift | Split-key encryption + DeviceCheck + rate limits built in; building a proxy takes days and introduces new infrastructure |
| Per-user rate limiting | Custom device fingerprinting, JWT tokens | AIProxy dashboard + `useStableID: true` | AIProxy provides per-user limits across devices via iCloud stable ID; custom solutions require a backend |
| Anthropic HTTP client | Custom URLSession wrapper with retry logic, streaming, error mapping | AIProxySwift's `anthropicService` | AIProxy wraps the full Anthropic Messages API including error handling, retry, streaming — don't re-implement |
| Daily summary guard | Complex scheduling logic | Existing `EchoScheduler.shouldGenerateDailySummary()` | Already implemented and tested; just verify it works correctly |

---

## Common Pitfalls

### Pitfall 1: Forgetting AIPROXY_DEVICE_CHECK_BYPASS for Simulator

**What goes wrong:** All AI calls fail in the simulator with a cryptic error about DeviceCheck tokens.
**Why it happens:** Apple's DeviceCheck API cannot be called from the iOS simulator.
**How to avoid:** Set `AIPROXY_DEVICE_CHECK_BYPASS` env variable in the Xcode scheme's Run arguments before testing. Get the value from the AIProxy dashboard.
**Warning signs:** Any AI call immediately throws with an HTTP 403 or "DeviceCheck failed" error.

### Pitfall 2: Forgetting iCloud KV Entitlement for useStableID

**What goes wrong:** `AIProxy.configure(useStableID: true)` silently falls back to a device-local ID, defeating cross-device rate limiting.
**Why it happens:** iCloud Key-Value storage requires an explicit entitlement in the app's entitlements file.
**How to avoid:** Add the iCloud KV capability in `project.yml` OR via Xcode Signing & Capabilities. After adding to `project.yml`, run `xcodegen generate` and verify `.entitlements` file was updated.
**Warning signs:** Xcode logs a warning about iCloud KV not being configured.

### Pitfall 3: DeepSeekAIProvider.defaultAPIKey Still Reachable

**What goes wrong:** Key is removed from source but a compiled `.o` or `.swiftmodule` still references it in a stale build.
**Why it happens:** Xcode incremental build doesn't always recompile untouched files.
**How to avoid:** After removing the hardcoded key, do a clean build (`Product > Clean Build Folder` in Xcode, or `xcodebuild clean` before build) and verify with `strings` on the compiled binary.
**Verification:** `strings path/to/ToDay.app/ToDay | grep sk-94d311` should return nothing.

### Pitfall 4: AIProxySwift Type Name Mismatch

**What goes wrong:** `AnthropicMessageRequestBody` or `AnthropicMessageParam` compile errors because the actual AIProxySwift type names differ slightly.
**Why it happens:** AIProxySwift is a community package and the README examples may lag behind the actual API.
**How to avoid:** After adding the package, use Xcode's autocomplete on `AnthropicService` to discover the exact type names. The README example in the repo README showed `AnthropicMessageRequestBody` and `AnthropicMessageParam` as of April 2026.
**Warning signs:** Compiler errors referencing unknown types immediately after adding the package.

### Pitfall 5: EchoAIService Tier Defaults to .free, Never Calls Anthropic

**What goes wrong:** `EchoAIService.currentTier` returns `.free` by default (when no UserDefaults key exists), routing to `AppleLocalAIProvider` which is a stub returning `"[本地 AI] 已处理请求"`. The daily summary is stored but contains placeholder text.
**Why it happens:** `EchoUserTier` defaults to `.free` in `EchoAIService.currentTier` getter. `AppleLocalAIProvider.isAvailable` returns `true` on iOS 26+ (placeholder check), and `false` on iOS 17-25. On iOS 17-25 simulator, `AppleLocalAIProvider.isAvailable` returns `false` so it falls back to `proProvider` (Claude). On iOS 26 device, it routes to the stub.
**How to avoid:** For testing on device, set `EchoAIService.currentTier = .pro` in a debug settings menu or hardcode `.pro` as the default for Phase 1. Alternatively, fix `AppleLocalAIProvider._checkModelAvailability()` to actually check `SystemLanguageModel.default.availability` so it correctly returns `false` until the real implementation exists.
**Warning signs:** Summary text shows `"[本地 AI] 已处理请求"` in the Echo inbox.

### Pitfall 6: project.yml SPM Package Section Missing

**What goes wrong:** `import AIProxy` compiles fine in Xcode (added via GUI) but `xcodegen generate` regenerates `.xcodeproj` and drops the package dependency.
**Why it happens:** XcodeGen reads `project.yml` exclusively; packages added only through Xcode GUI are lost on regeneration.
**How to avoid:** Add AIProxySwift to `project.yml` under `packages:` AND `targets.ToDay.dependencies:`. Always use `xcodegen generate` as the source of truth.

### Pitfall 7: Summary Prompt Missing Observational Tone Instruction

**What goes wrong:** Claude generates prescriptive text like "你应该早点睡觉" violating AIS-04.
**Why it happens:** The current `buildDailySummaryPrompt` says "生成简洁的中文日记摘要" without specifying observational tone.
**How to avoid:** Update the prompt instruction to explicitly prohibit "应该/要/需要" and specify "观察性语气". See Pattern 5 above.

---

## Code Examples

### Full AnthropicAIProvider Structure (verified against AIProxySwift README)

```swift
// Source: github.com/lzell/AIProxySwift README (April 2026)
import Foundation
import AIProxy

final class AnthropicAIProvider: EchoAIProviding, @unchecked Sendable {

    private static let partialKey = "REPLACE_WITH_AIPROXY_PARTIAL_KEY"
    private static let serviceURL = "REPLACE_WITH_AIPROXY_SERVICE_URL"

    private let anthropicService: AnthropicService

    init() {
        self.anthropicService = AIProxy.anthropicService(
            partialKey: Self.partialKey,
            serviceURL: Self.serviceURL
        )
    }

    var isAvailable: Bool { true }

    func summarize(prompt: String) async throws -> String {
        let body = AnthropicMessageRequestBody(
            maxTokens: 512,
            messages: [AnthropicMessageParam(content: prompt, role: .user)],
            model: "claude-haiku-4-5-20251001",
            system: "你是 Echo，用户的生活观察者。根据今日数据，用100-150字的中文描述用户今天的一天，" +
                    "只描述发生了什么，不评判、不给建议、不使用"应该"等词。"
        )
        do {
            let response = try await anthropicService.messageRequest(body: body, secondsToWait: 30)
            return response.content
                .compactMap { if case .textBlock(let b) = $0 { return b.text } else { return nil } }
                .joined()
        } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
            if statusCode == 429 { throw EchoAIError.rateLimited }
            throw EchoAIError.providerUnavailable("HTTP \(statusCode): \(responseBody)")
        }
    }

    func respond(messages: [EchoChatMessage]) async throws -> String {
        let systemMsg = messages.first(where: { $0.role == .system })?.content ?? ""
        let params = messages
            .filter { $0.role != .system }
            .map { msg -> AnthropicMessageParam in
                AnthropicMessageParam(
                    content: msg.content,
                    role: msg.role == .user ? .user : .assistant
                )
            }
        let body = AnthropicMessageRequestBody(
            maxTokens: 1024,
            messages: params,
            model: "claude-haiku-4-5-20251001",
            system: systemMsg
        )
        do {
            let response = try await anthropicService.messageRequest(body: body, secondsToWait: 30)
            return response.content
                .compactMap { if case .textBlock(let b) = $0 { return b.text } else { return nil } }
                .joined()
        } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
            if statusCode == 429 { throw EchoAIError.rateLimited }
            throw EchoAIError.providerUnavailable("HTTP \(statusCode): \(responseBody)")
        }
    }

    func generateProfile(prompt: String) async throws -> String {
        return try await summarize(prompt: prompt)
    }
}
```

### AIProxy Configure Call in ToDayApp

```swift
// Source: AIProxySwift README — SwiftUI app init
import AIProxy

@main
struct ToDayApp: App {
    // ... existing properties ...

    init() {
        AIProxy.configure(
            logLevel: .warning,
            resolveDNSOverTLS: true,
            useStableID: true  // requires iCloud KV entitlement
        )
        backgroundTaskManager.registerTasks()
    }

    // ... existing body ...
}
```

### project.yml Package Addition

```yaml
# Add to root level of project.yml:
packages:
  AIProxy:
    url: https://github.com/lzell/AIProxySwift
    branch: main

# Add to targets.ToDay.dependencies:
targets:
  ToDay:
    dependencies:
      - package: AIProxy
        product: AIProxy
```

### Privacy Verification — No GPS in Prompts

The existing `EchoPromptBuilder.loadRecentTimelineSummaries()` already formats events correctly:

```swift
// Source: ios/ToDay/ToDay/Data/AI/EchoPromptBuilder.swift
// line ~203 (verified in source read)
let eventSummary = timeline.entries
    .filter { $0.kind != .mood }
    .map { "\($0.kindBadgeTitle) \($0.resolvedName) (\($0.scrollDurationText))" }
    .joined(separator: ", ")
// Output example: "步行 星巴克朝阳门店 (45分钟), 久坐 公司 (3小时20分钟)"
// GPS: NEVER included. resolvedName is already geocoded place name.
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| DeepSeek API (current) | Claude Haiku 4.5 via AIProxy | Phase 1 | Privacy-aligned; no Chinese routing; AIProxy eliminates key exposure |
| Hardcoded API key | AIProxy split-key (partial key safe in binary) | Phase 1 | Key cannot be extracted from binary; DeviceCheck prevents abuse |
| EchoScheduler not connected | Scheduler already wired in ToDayApp.swift | Already done | No wiring work needed — discovery, not a task |
| Claude Haiku 3.5 | Claude Haiku 4.5 (`claude-haiku-4-5-20251001`) | Oct 2025 | Haiku 3 deprecated April 19, 2026; must use Haiku 4.5 |
| SwiftAnthropic (community) | AIProxySwift (also community, but solves key security) | — | AIProxy is the recommended pattern for iOS AI key protection |

**Deprecated/outdated:**
- `claude-3-haiku-20240307`: Deprecated, retires April 19, 2026. Do not use.
- `DeepSeekAIProvider.defaultAPIKey`: Remove entirely. Never add any `defaultAPIKey` pattern again.
- `AppleLocalAIProvider._checkModelAvailability()` returning `true` as placeholder: This causes iOS 26 devices to get stub responses. Fix to actually check `SystemLanguageModel.default.availability` (separate from Phase 1 if iOS 26 is not available for testing).

---

## Open Questions

1. **AIProxy Partial Key Values**
   - What we know: AIProxy provides a `partialKey` and `serviceURL` from the developer dashboard after registering the Anthropic API key
   - What's unclear: These specific values cannot be pre-determined — they are generated by AIProxy on account setup
   - Recommendation: Create an AIProxy account, add the Anthropic API key, copy the generated `partialKey` and `serviceURL`, store them in the source file as string constants (safe to commit — partial key is designed to be in the binary)

2. **EchoUserTier Default for Phase 1 Testing**
   - What we know: `EchoAIService` defaults to `.free` tier when no UserDefaults value exists; `.free` tier routes to `AppleLocalAIProvider` (stub); on iOS 17-25 the stub's `isAvailable` returns `false`, causing fallback to `proProvider` (Claude)
   - What's unclear: Whether the simulator correctly falls back to Claude or whether the default tier needs to be changed for testing
   - Recommendation: In Phase 1, either (a) add a Debug Settings toggle to force `.pro` tier, or (b) change the default tier to `.pro` during Phase 1 and revert when Foundation Models is implemented. Option (b) is simpler.

3. **iCloud KV Entitlement for useStableID**
   - What we know: AIProxy recommends `useStableID: true` for cross-device per-user rate limiting; it requires iCloud KV storage entitlement
   - What's unclear: Whether the `group.com.looanli.today` app group already satisfies this, or whether a separate `com.apple.developer.ubiquity-kvstore-identifier` entitlement is needed
   - Recommendation: Add iCloud capability explicitly via Xcode Signing & Capabilities → iCloud → Key-Value storage. XcodeGen will reflect it in `project.yml` on next inspection.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode | Build + test | Assumed | Unknown — check locally | — |
| XcodeGen | project.yml regeneration | Assumed (per CLAUDE.md) | 2.45.0+ | — |
| AIProxy account | AnthropicAIProvider | External — must create | — | BYOK (user provides own key) — but defeats SEC-01 |
| Anthropic API key | AIProxy setup | External — must have one | — | No fallback for Phase 1 |
| iPhone 17 Pro simulator | Test execution | Assumed (per CLAUDE.md test command) | — | Any iOS 17+ simulator |

**Missing dependencies with no fallback:**
- AIProxy account + Anthropic API key: Must be created before implementing `AnthropicAIProvider`. Takes ~10 minutes on aiproxy.com.

**Missing dependencies with fallback:**
- iCloud KV (for `useStableID`): If not configured, AIProxy falls back to device-local ID. Per-user cross-device rate limiting degrades but per-device limiting still works.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (built-in) |
| Config file | `ios/ToDay/project.yml` (scheme: ToDayTests) |
| Quick run command | `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/EchoAIServiceTests` |
| Full suite command | `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SEC-01 | No hardcoded key in binary | Manual | `strings path/to/ToDay.app/ToDay \| grep sk-94d311` returns empty | N/A — manual verification |
| SEC-02 | All cloud calls go through AIProxy | Unit | Test `AnthropicAIProvider` with mock AIProxy service | ❌ Wave 0 — `AnthropicAIProviderTests.swift` |
| SEC-03 | Daily rate limit enforced | Unit | Existing `EchoSchedulerTests` — `testShouldGenerateDailySummaryReturnsFalseWhenAlreadyRan` | ✅ `EchoSchedulerTests.swift` |
| AIS-01 | Summary generated when scheduler fires | Unit | `EchoDailySummaryGeneratorTests` with MockAIProvider | ✅ `EchoDailySummaryGeneratorTests.swift` |
| AIS-02 | Summary references place names not GPS | Unit | `EchoPromptBuilderTests` — verify no CLLocationCoordinate2D in prompt output | ✅ `EchoPromptBuilderTests.swift` |
| AIS-04 | Summary tone is observational | Unit | Prompt test — verify prompt instruction contains "不评判" / "不使用'应该'" | ✅ `EchoPromptBuilderTests.swift` (update needed) |
| AIS-05 | Summary auto-generates on background | Integration | Manual — run on device, background app after 20:00, check Echo inbox | Manual only |
| PRV-01 | No GPS in cloud payload | Unit | `EchoPromptBuilderTests` — format events as place names, assert no coordinate strings | ✅ `EchoPromptBuilderTests.swift` |

### Sampling Rate
- **Per task commit:** Run `EchoAIServiceTests` + `EchoSchedulerTests` + `EchoPromptBuilderTests`
- **Per wave merge:** Full suite (180+ tests)
- **Phase gate:** Full suite green before phase completion

### Wave 0 Gaps
- [ ] `ios/ToDay/ToDayTests/AnthropicAIProviderTests.swift` — tests `AnthropicAIProvider` with a mock HTTP session, verifying correct model ID, system prompt, and error mapping
- [ ] Update `EchoPromptBuilderTests.swift` to assert that `buildDailySummaryPrompt` output contains observational tone instruction (PRV-01/AIS-04)

---

## Sources

### Primary (HIGH confidence)
- AIProxySwift GitHub README — https://github.com/lzell/AIProxySwift (read directly via curl, April 2026)
- Anthropic Models Overview — https://platform.claude.com/docs/en/about-claude/models/overview (fetched April 2026)
- Existing codebase — `/Users/looanli/Projects/ToDay/ios/ToDay/ToDay/Data/AI/` (read all files directly)
- `ToDayApp.swift` — scheduler wiring confirmed by direct source read
- `AppContainer.swift` — dependency graph confirmed by direct source read
- `EchoScheduler.swift` — rate limiting and lifecycle hooks confirmed by direct source read
- `EchoPromptBuilder.swift` — privacy boundary confirmed: `resolvedName` not coordinates

### Secondary (MEDIUM confidence)
- AIProxy integration guide — https://www.aiproxy.com/docs/integration-guide.html (confirmed DeviceCheck setup, partialKey/serviceURL flow)
- `.planning/research/STACK.md` — project research confirming AIProxy + Claude as recommended stack
- `.planning/research/ARCHITECTURE.md` — project research confirming component boundaries and privacy constraints
- `.planning/codebase/CONCERNS.md` — confirmed hardcoded key location: `DeepSeekAIProvider.swift` line 18

### Tertiary (LOW confidence)
- None in this phase — all critical claims verified against primary sources

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — AIProxySwift README read directly; Anthropic model list fetched live from official docs; model IDs verified
- Architecture: HIGH — all AI layer source files read directly; EchoScheduler wiring confirmed in ToDayApp.swift
- Pitfalls: HIGH — pitfalls derived from direct source inspection plus AIProxy documentation
- Existing wiring state: HIGH — `ToDayApp.swift` read directly; scheduler lifecycle calls confirmed

**Research date:** 2026-04-04
**Valid until:** 2026-07-04 (AIProxy API stable; Anthropic model IDs stable; verify model availability before execution)

**Critical discovery:** The previous planning documents stated "EchoScheduler is not wired to app lifecycle." This is incorrect as of the current codebase state. `ToDayApp.swift` already calls `echoScheduler.onAppBackground()` from `.onChange(of: scenePhase)` and `echoScheduler.onAppLaunch()` from `.task`. The planner should NOT create tasks to wire the scheduler — it is already wired. The actual work is: (1) remove hardcoded key, (2) create `AnthropicAIProvider`, (3) update `EchoAIService` default proProvider, (4) add AIProxy configure call, (5) update prompt for observational tone.
