# Technology Stack — AI Layer

**Project:** Unfold (working name)
**Scope:** Adding AI capabilities to existing iOS auto life-tracking app
**Researched:** 2026-04-04
**Overall confidence:** HIGH for architecture decisions, MEDIUM for specific versions

---

## Context: What Already Exists

The codebase already has a complete AI infrastructure skeleton:

- `EchoAIProviding` protocol — provider abstraction (respond/summarize/generateProfile)
- `EchoAIService` — tier-based routing (free → `AppleLocalAIProvider`, pro → `DeepSeekAIProvider`)
- `AppleLocalAIProvider` — iOS 26 Foundation Models stub (placeholder, real API not wired)
- `DeepSeekAIProvider` — live cloud calls, **hardcoded API key** (critical security debt)
- `EchoDailySummaryGenerator` + `EchoScheduler` — daily summary pipeline (complete but not connected to phone-first flow)
- `EchoPromptBuilder` — 4-layer context assembly (profile + summaries + timeline + conversation)
- `EchoMemoryManager` — SwiftData-backed layered memory

The architecture is correct. The problems are: (1) wrong cloud provider choice, (2) hardcoded key security hole, (3) Foundation Models stub not implemented, (4) ecosystem not connected to phone-first data pipeline.

---

## Recommended Stack

### On-Device AI: Apple Foundation Models Framework

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Foundation Models framework | iOS 26+ | Free-tier daily summary, Echo chat | Zero cost, zero latency, full privacy, already stubbed in `AppleLocalAIProvider` |
| `SystemLanguageModel` | iOS 26+ | Session-based text generation | The only official Apple on-device LLM API |
| `@Generable` macro | iOS 26+ | Structured pattern output (mood trends, activity labels) | Type-safe Swift structs from model output — eliminates fragile string parsing |
| NaturalLanguage framework | iOS 17+ | Sentiment scoring on mood notes | Fully on-device, no token budget, available now (not gated by iOS 26) |

**Foundation Models capabilities relevant to this app:**
- Daily summary generation (100-150 Chinese characters) — fits within 4096 token limit
- Mood trend classification via `@Generable` enum — replaces brittle `parseSummaryResponse()` string matching
- User profile synthesis from weekly summaries — fits easily in 4096 tokens
- Echo chat responses (bounded conversation history)

**Foundation Models hard limits:**
- 4096 combined input+output tokens — cannot process more than ~7 days of raw timeline data in one call
- Text-only input — no image/audio
- Requires iOS 26 AND Apple Intelligence enabled AND iPhone 15 Pro+ (or iPhone 16+)
- ~3B parameter model — weaker reasoning than cloud models; will hallucinate on cross-week pattern analysis
- Unpredictable model updates from Apple with no versioning — behavior can change silently

**Implementation for `AppleLocalAIProvider`:**
```swift
import FoundationModels

@available(iOS 26, *)
private func _generateText(prompt: String) async throws -> String {
    let availability = SystemLanguageModel.default.availability
    guard case .available = availability else {
        throw EchoAIError.modelNotSupported
    }
    let session = LanguageModelSession()
    let response = try await session.respond(to: prompt)
    return response.content
}
```

**Confidence:** HIGH — verified against Apple WWDC25 session 286/301 and azamsharp.com guide.

---

### Cloud AI: Claude via Direct HTTP (replacing DeepSeek)

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Anthropic Messages API | `2023-06-01` | Complex pattern recognition, cross-week analysis, Echo Pro chat | Claude Haiku 3.5 is cheaper than DeepSeek at scale; Claude Sonnet 4.6 outperforms DeepSeek on nuanced personal insight |
| SwiftAnthropic | v2.1.8 | Swift HTTP wrapper for Anthropic API | Most maintained community package; supports streaming, async/await, Swift 6 concurrency |
| AIProxy | current | API key security proxy for iOS | Prevents key exposure using Apple DeviceCheck + split-key encryption |

**Why replace DeepSeek:**
- DeepSeek has a hardcoded key in the codebase — an active security leak that needs fixing regardless
- DeepSeek API is a Chinese service; data routing/privacy concerns for an app marketed on privacy
- Claude Haiku 3.5 pricing ($1/$5 per million tokens) is competitive with DeepSeek's pricing
- Claude Sonnet 4.6 ($3/$15) is significantly stronger for multi-day pattern reasoning
- Anthropic has first-class Swift ecosystem (multiple maintained packages)

**Why not GPT-4o:** Costs $5/$20 per million tokens vs. Claude Haiku at $1/$5. For a solo dev with a free-first model, cost matters.

**Why not Gemini:** Google's standalone Swift SDK is deprecated. The current path requires Firebase SDK dependency. Adding Firebase to a local-first, privacy-focused app is architecturally hostile and adds significant bloat.

**Prompt budget for daily summary:**
A typical day's timeline data in text form is roughly 300-500 tokens. A full 4-layer context prompt (profile + 7-day summaries + timeline + conversation) runs 800-1200 tokens. Response ~150-200 tokens. Total: well under 2000 tokens per call. At Claude Haiku pricing, 1000 daily-active users generating one summary/day costs ~$0.05/day.

**Confidence:** HIGH for Claude being a better fit. MEDIUM for exact pricing (verified against IntuitionLabs and official Claude pricing pages, accurate as of research date).

---

### API Key Security: AIProxy

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| AIProxy | current | Proxy Anthropic/OpenAI calls without bundling key | Split-key encryption + Apple DeviceCheck — the hardcoded DeepSeek key problem cannot repeat |

**How it works:** Your Anthropic API key never lives in the app binary. AIProxy stores half the encrypted key on their servers; the app carries the other half (useless alone). Apple DeviceCheck verifies the request comes from a real, non-jailbroken app installation. Rate limiting is configurable.

**Free tier** exists with no credit card required, sufficient for early-stage development and beta.

**Alternative: Cloudflare Worker proxy.** Also valid — gives you full control, 100,000 free requests/day, global edge deployment. Requires you to build and maintain the worker. Appropriate if the project eventually scales to warrant infrastructure ownership.

**For solo dev MVP: use AIProxy.** For post-launch with steady traffic: migrate to Cloudflare Worker or own backend.

**Confidence:** HIGH — verified against AIProxy documentation and Cloudflare Worker pattern articles.

---

### Pattern Recognition: Algorithmic (Not ML)

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Swift stdlib (Set, Dictionary, reduce) | Swift 5.10+ | Cross-day behavioral pattern detection | "You've been at the library 3 days in a row" is a simple frequency query over SwiftData — no ML needed |
| SwiftData FetchDescriptor with predicates | iOS 17+ | Querying historical timeline events | Already in codebase; sufficient for streak detection and location frequency |

**Do not use Create ML for pattern recognition here.** The use case ("user was at X location 3+ days") is a database query problem, not a classification problem. Create ML requires training data you don't have, adds maintenance burden, and produces inferior results to a direct query for this specific case.

The output of algorithmic pattern detection feeds into a cloud LLM prompt as structured text: "Past 7 days: library (4 days), gym (2 days), café (1 day)." The LLM generates the human-readable insight from that structured input.

**Confidence:** HIGH — this is a well-established pattern in quantified-self apps.

---

### Notification Delivery: UNUserNotificationCenter (Existing)

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| UNUserNotificationCenter | iOS 17+ | Scheduled proactive insight delivery | Already used in project; local notifications triggered by EchoScheduler logic, no push server needed |
| BGProcessingTask | iOS 17+ | Background AI summary generation when device is charging | `requiresExternalPower: true` avoids battery complaints; already have BGTaskScheduler in place |

**Do not use APNs/FCM for proactive insights in MVP.** Local notifications scheduled from BGProcessingTask output are sufficient and eliminate server infrastructure. Remote push requires a backend, APNs certificates, and server costs.

**iOS 26 note:** `BGContinuedProcessingTask` (new in iOS 26) allows completing foreground-started tasks after backgrounding. Useful for long-running Foundation Models inference if the user initiates a summary from the UI. Register this when targeting iOS 26+.

**Confidence:** HIGH — verified against Apple developer documentation and iOS 26 background task WWDC25 session.

---

## What NOT to Use (and Why)

| Technology | Why Not |
|------------|---------|
| **DeepSeek API (current)** | Hardcoded key is a live security breach. Chinese routing contradicts privacy-first positioning. Replace immediately. |
| **Create ML / MLActivityClassifier** | This app already has `PhoneInferenceEngine` doing activity classification. Create ML would duplicate existing logic and requires training data you don't have. Only relevant if you want custom activity types not covered by CoreMotion. |
| **Gemini / Firebase AI Logic** | Deprecated standalone SDK. Firebase dependency is bloat for a local-first app. Google is also direct competition (Gemini app competes with Unfold's positioning). |
| **OpenAI GPT-4o** | 5x more expensive than Claude Haiku for equivalent task quality on personal diary summarization. No meaningful quality advantage for this use case. |
| **Core ML with custom .mlmodel** | No training data exists. Custom Core ML models for NLP are largely superseded by Foundation Models for iOS 26+ targets. Only valuable for very specific, trainable classification tasks. |
| **MLTensor / custom Neural Engine ops** | Extremely low-level. Only useful if you're building custom model architecture. Not appropriate for application-level AI features. |
| **Apple Intelligence Writing Tools API** | This is a system-level UI enhancement for text editing fields. Irrelevant to Echo's background analysis pipeline. |
| **LangChain / LlamaIndex Swift ports** | Immature Swift ecosystem. The existing `EchoPromptBuilder` 4-layer context system already implements what these frameworks provide. Don't add abstractions over abstractions. |
| **On-device Llama via Core ML** | Models are 4-8GB. App Store limit is effectively 4GB total. Users will not accept this. Foundation Models (provided by OS, no download) is the right answer for on-device. |

---

## Final Architecture: Tier-Based Hybrid

```
Free tier (iOS 26+, Apple Intelligence ON):
  User data → EchoPromptBuilder → Foundation Models (on-device)
  → Daily summary, Echo chat, mood classification

Free tier (iOS 17-25 OR Apple Intelligence OFF):
  Show UI with "AI features require iOS 26 and Apple Intelligence"
  OR fall back to cloud (see below)

Pro tier (any iOS 17+):
  User data → EchoPromptBuilder → AIProxy → Anthropic Claude Haiku 3.5
  → Daily summary, Echo chat

Pro tier (complex / cross-week analysis):
  Algorithmic pattern query → structured text → AIProxy → Claude Sonnet 4.6
  → Proactive insight text for notification
```

The existing `EchoAIService` tier-routing architecture is correct. The only changes needed are:
1. Wire real `FoundationModels` API into `AppleLocalAIProvider` (replace placeholder)
2. Replace `DeepSeekAIProvider` with `AnthropicAIProvider` using SwiftAnthropic + AIProxy
3. Remove hardcoded key from `DeepSeekAIProvider`
4. Add algorithmic pattern detection layer that feeds LLM prompts

---

## Installation

```bash
# SwiftAnthropic (Anthropic API client)
# Add via Xcode: File > Add Package Dependencies
# URL: https://github.com/jamesrochabrun/SwiftAnthropic
# Version: Up to Next Major from 2.1.8

# AIProxy (API key security — optional, can use direct HTTP initially)
# URL: https://github.com/lzell/AIProxySwift
# Version: Up to Next Major

# NaturalLanguage — system framework, no installation needed
# FoundationModels — system framework (iOS 26+), no installation needed
```

No third-party UI or ML libraries. All heavy lifting is system frameworks + one network client.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Foundation Models framework API | HIGH | Verified via WWDC25 sessions 286/301 and third-party guides. iOS 26 requirement confirmed. |
| Foundation Models 4096 token limit | HIGH | Multiple independent sources. Critical constraint for prompt design. |
| Claude pricing | MEDIUM | Verified against IntuitionLabs comparison and official Anthropic pages as of research date. Subject to change. |
| SwiftAnthropic package quality | MEDIUM | v2.1.8 current, actively maintained, but community package (not Anthropic-official). Monitor for Swift 6 concurrency compliance. |
| AIProxy security model | MEDIUM | Verified against their documentation. No independent security audit found. Appropriate for MVP; evaluate before scale. |
| Gemini deprecation | HIGH | Official Google documentation confirms standalone Swift SDK deprecated; Firebase AI Logic is the current path. |
| BGProcessingTask for charging-only summary | HIGH | Apple documentation and iOS 26 WWDC session both confirmed. |

---

## Sources

- Apple WWDC25: "Meet the Foundation Models framework" — https://developer.apple.com/videos/play/wwdc2025/286/
- Apple WWDC25: "Deep dive into the Foundation Models framework" — https://developer.apple.com/videos/play/wwdc2025/301/
- Apple WWDC25: "Finish tasks in the background" — https://developer.apple.com/videos/play/wwdc2025/227/
- Apple Foundation Models documentation — https://developer.apple.com/documentation/FoundationModels
- Foundation Models guide (AzamSharp, verified current) — https://azamsharp.com/2025/06/18/the-ultimate-guide-to-the-foundation-models-framework.html
- Foundation Models limitations (Natasha the Robot) — https://www.natashatherobot.com/p/apple-foundation-models
- SwiftAnthropic GitHub — https://github.com/jamesrochabrun/SwiftAnthropic
- AIProxy documentation — https://www.aiproxy.com/docs/integration-guide.html
- LLM pricing comparison — https://intuitionlabs.ai/articles/llm-api-pricing-comparison-2025
- Apple ML Research: Foundation Models 2025 updates — https://machinelearning.apple.com/research/apple-foundation-models-2025-updates
- iOS background task BGContinuedProcessingTask (DEV Community) — https://dev.to/arshtechpro/wwdc-2025-ios-26-background-apis-explained-bgcontinuedprocessingtask-changes-everything-9b5
- Firebase AI Logic (Gemini via Firebase) — https://firebase.google.com/docs/ai-logic
