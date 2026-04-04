# Project Research Summary

**Project:** Unfold (working name)
**Domain:** iOS passive auto life-tracking with AI insight layer
**Researched:** 2026-04-04
**Confidence:** HIGH

---

## Executive Summary

Unfold is a brownfield iOS project — the sensor pipeline, inference engine, SwiftData persistence, and Echo AI skeleton all exist and function. The research challenge is not "what to build" but "what to wire together, in what order, with what fixes." The codebase has a clean five-layer architecture (Sensor → Inference → Memory → AI Provider → Presentation) that is fundamentally sound. The two most urgent problems are a live API key hardcoded in source (an immediate security breach) and the AI layer never being surfaced in the main screen despite being fully generated and stored. Everything the user can actually see — the timeline, the history, the mood taps — works. Everything the user should feel — the AI insight that makes today meaningful — is built but invisible.

The recommended approach: fix the security hole first (non-negotiable before any external distribution), wire the scheduler to the app lifecycle so summaries actually generate, and then surface the AI summary in TodayScreen. These three steps produce the core emotional loop of the product with minimal new code. The cloud AI provider should migrate from DeepSeek to Claude via AIProxy before any public release — DeepSeek routing contradicts the privacy-first positioning and the hardcoded key problem cannot be solved cleanly without also switching to a proxy architecture. The on-device Apple Foundation Models path (iOS 26+) should be implemented in parallel as the free tier, but cannot block shipping since only iOS 26 devices with Apple Intelligence qualify.

The primary competitive gap Unfold is targeting is real: no competitor delivers both beautiful passive recording and emotional AI insight. Life Cycle and Arc give data; Gyroscope and Exist require setup effort; Apple Journal requires manual writing. Unfold's moat is zero-friction plus design plus one resonant AI moment per day. That moment — the daily AI summary in a beautifully designed timeline — is the single most important thing to ship next. The research converges strongly on this prioritization.

---

## Key Findings

### Recommended Stack

The existing AI infrastructure is correctly architected. `EchoAIService` with tier-based routing, `EchoPromptBuilder` with 4-layer context, and `EchoMemoryManager` with SwiftData-backed layered memory are all sound patterns. The required changes are targeted: replace DeepSeek with Claude (Haiku 3.5 for daily summaries, Sonnet 4.6 for complex pattern analysis), add AIProxy to keep the API key off the device binary, implement the Foundation Models stub for iOS 26+ free tier, and add algorithmic pattern detection as structured input to LLM prompts.

**Core technologies:**
- Foundation Models framework (iOS 26+): free-tier daily summary and Echo chat — zero cost, zero latency, full privacy; already stubbed, needs real implementation
- Anthropic Claude via SwiftAnthropic + AIProxy: pro-tier and fallback — replaces DeepSeek; Haiku 3.5 is cost-competitive at $1/$5 per million tokens; AIProxy eliminates key exposure via Apple DeviceCheck
- NaturalLanguage framework (iOS 17+): on-device sentiment scoring for mood notes — no token budget, available now, no iOS 26 gate
- Swift stdlib + SwiftData FetchDescriptor: algorithmic pattern detection — "library 3 days in a row" is a database query problem, not a machine learning problem; no Create ML needed
- UNUserNotificationCenter + BGProcessingTask: proactive insight delivery — local notifications from background tasks, no push server needed for MVP

**Critical constraint:** Foundation Models has a hard 4096 combined token limit and requires iOS 26, Apple Intelligence enabled, and iPhone 15 Pro or later. This is the free tier, not the universal tier. All users on iOS 17-25 or older devices need the cloud fallback — which means Claude via AIProxy must work correctly even for users who never qualify for on-device AI.

### Expected Features

The feature dependency chain is clearly sequenced by research: location recording enables place recognition, which enables clean place names in AI context, which enables a meaningful AI daily summary, which is the foundation for every downstream AI feature. Shipping in wrong order wastes effort.

**Must have (table stakes — already done or blocking):**
- Automatic location tracking (background) — core premise, DONE
- Place recognition and labeling — minimum readable unit, DONE
- Activity/transport detection — DONE
- Daily timeline view — DONE
- History / past days access — DONE
- Permission onboarding — nothing else works without Always location grant; ACTIVE, NOT SHIPPED
- Battery efficiency validation — needs real-device testing at scale
- Graceful data gap handling — dead battery / airplane mode periods must not corrupt the timeline

**Should have (Tier 1 differentiators — ship in current milestone):**
- AI daily summary — the emotional payoff that separates Unfold from Arc/Life Cycle; one paragraph generated from clean event + place data
- Visual polish of "画卷" timeline — design is the only moat; must reach Apple-quality before any other surface
- Semantic place naming — "your library" rather than raw geocoding output

**Should have (Tier 2 — next milestone after core loop proven):**
- AI proactive push (one meaningful insight per day) — requires pattern engine and 3+ weeks of user data
- Echo conversation — EchoEngine exists but daily summary must prove itself first
- Cross-week trend visualization — secondary surface; builds on daily summary foundation
- Shareable day recap card — depends on timeline visual quality reaching the bar

**Defer to v2+:**
- Apple Watch heart rate + workout correlation — explicitly out of MVP scope
- Year in Review annual report — needs 365 days of data
- On-device custom Core ML activity classification — no training data, rule-based engine already has 180 passing tests

**Anti-features (never build):**
- Gamification (streaks, badges) — attracts wrong users, creates anxiety
- Social feed / leaderboards — location data is too personal for social pressure
- Coaching / behavioral nudges — AI must describe, never prescribe
- Chat-first AI interface — timeline is the primary surface, Echo is secondary
- Push notification flood — one meaningful push per day maximum

### Architecture Approach

The architecture is a clean five-layer separation: Sensor (CoreLocation + CoreMotion on-device), Inference (deterministic rule-based PhoneInferenceEngine), Memory (SwiftData 4-layer: profile + daily summaries + today data + conversation), AI Provider (hybrid on-device/cloud with tier routing), and Presentation (SwiftUI + ViewModels). The critical privacy boundary is that raw GPS coordinates never enter the AI layer — only geocoded place names travel to any cloud API. This boundary already exists in the code and must be maintained as new features are added.

**Major components:**
1. PhoneInferenceEngine — deterministic rule-based activity classification; must stay synchronous and testable; no AI calls here
2. EchoPromptBuilder — assembles 4-layer context into a text prompt; this is the privacy transform: structured personal data in, text prompt out; GPS coordinates never included
3. EchoAIService — tier-based routing to AppleLocalAIProvider (iOS 26+ on-device) or AnthropicAIProvider (cloud via AIProxy); current DeepSeekAIProvider to be replaced
4. EchoScheduler — triggers daily summary generation on app background + app launch; fully implemented but not connected to app lifecycle
5. TodayScreen + EchoMessageManager — presentation layer that must surface the AI summary; DailySummaryEntity is being stored but never shown

**Build order from architecture research (sequential dependencies):**
1. Remove hardcoded DeepSeek key (no dependencies — security fix)
2. Wire EchoScheduler to app lifecycle (depends on 1)
3. Connect TodayViewModel to EchoScheduler data feed (depends on 2)
4. Surface DailySummaryEntity in TodayScreen (depends on 3 — first visible AI output)
5. Implement FoundationModels in AppleLocalAIProvider (depends on Xcode 26 / iOS 26 — parallel track)
6. Pattern recognition layer (depends on 4 + 7+ days of accumulated summaries)
7. Proactive push notifications (depends on 6)

### Critical Pitfalls

1. **Hardcoded API key in source (ACTIVE)** — `sk-94d311f460e54b4cac9c216ed8d5af36` is committed in `DeepSeekAIProvider.swift`. Extractable from any distributed binary. Fix: remove `defaultAPIKey`, migrate to Claude via AIProxy where the key never touches the app binary. This is a ship blocker for any external distribution.

2. **App Store rejection for Always Location** — Vague usage strings and onboarding that requests permission before showing value are the primary rejection reasons. Fix: write a specific usage description (20+ words explaining passive life timeline), build onboarding that demonstrates value first (show populated sample timeline), include explicit App Review Notes in every submission.

3. **BGTask unreliability** — iOS makes no scheduling guarantees for BGAppRefreshTask; the 30-second budget is easily exceeded by geocoding. Fix: generate timeline on foreground app open as primary path; BGTask is supplementary refresh only. Users must see a "last updated" timestamp so they can manually refresh.

4. **Force-quit stops recording permanently** — `startMonitoringSignificantLocationChanges()` does not relaunch a user-force-quit app. This is a platform limit, not a bug to fix. Fix: be honest in onboarding ("don't force-quit"), show gap indicators in timeline, and never promise 24/7 recording in marketing.

5. **Privacy policy mismatch on App Store submission** — Sending timeline context (inferred activities, place names) to a cloud LLM is third-party data sharing under Apple's guidelines and GDPR. This must be disclosed. Fix: write the privacy policy before first TestFlight external build; explicitly disclose that anonymized activity summaries (not GPS) are sent to an AI provider for Pro features; link to it from within the app.

---

## Implications for Roadmap

Based on combined research, the following phase structure is recommended. The ordering is driven by three constraints: security fix before distribution, feature dependencies in the AI chain, and data accumulation requirements for pattern features.

### Phase 1: Security and Pipeline Wiring

**Rationale:** The hardcoded API key is a live security issue that blocks all external distribution. Connecting the existing (but disconnected) EchoScheduler to the app lifecycle is the prerequisite for every AI feature. These are infrastructure fixes with no new UI — but without them, nothing downstream works or can be safely distributed.

**Delivers:** Working AI daily summary pipeline (generated in background, stored in SwiftData), no security vulnerabilities in the binary, Claude as cloud provider via AIProxy.

**Addresses:** API key security (Pitfall 1), AI daily summary (Tier 1 differentiator), cloud provider migration (STACK recommendation)

**Avoids:** Key exposure on TestFlight distribution, cost runaway without rate limiting guardrails

**Must implement:** Remove `defaultAPIKey`, add `AnthropicAIProvider` with SwiftAnthropic + AIProxy, wire `EchoScheduler.onAppBackground()` from SceneDelegate, connect `TodayViewModel` to scheduler data feed, implement client-side rate limiting (1 summary/day max)

### Phase 2: Permission Onboarding and First Visible AI

**Rationale:** Permission onboarding is the single highest-leverage unshipped feature — without Always location granted, nothing records. Simultaneously, Phase 1 generates AI summaries that are stored but invisible; surfacing them in TodayScreen completes the core emotional loop. These two pieces together create the minimum viable product that is both acquirable (onboarding works) and retentive (AI insight gives reason to return).

**Delivers:** Complete acquisition funnel (onboarding → Always location granted → recording starts), AI daily summary visible in TodayScreen, graceful gap handling in timeline

**Addresses:** Permission onboarding (table stakes ACTIVE), AI summary surface in UI (ARCHITECTURE Step 5), privacy policy requirement before TestFlight external

**Avoids:** App Store rejection for Always Location (Pitfall 2), approximate location breaking PlaceManager (Pitfall 7), privacy policy mismatch rejection (Pitfall 9)

**Must implement:** Onboarding flow with value-first demonstration, specific `NSLocationAlwaysAndWhenInUseUsageDescription`, accurate accuracy authorization detection, AI summary card in TodayScreen reading latest `DailySummaryEntity`, gap indicators in timeline, privacy policy written and linked from Settings

### Phase 3: Visual Polish and Design Moat

**Rationale:** Design is Unfold's only sustainable competitive moat — Life Cycle and Arc are functional but cold. The "画卷" aesthetic must reach Apple-quality before the app is shared publicly or submitted for review. This phase has no technical dependencies beyond a working timeline, but it is the highest-craft-effort phase. It should follow onboarding so the designer/developer can experience the real data flowing through the UI.

**Delivers:** Timeline that users want to look at; shareable quality visual design; EventCardView polish; the "11pm passive viewing moment" actually feeling resonant

**Addresses:** Visual design (Tier 1 core differentiator), "画卷" timeline aesthetic (FEATURES MVP recommendation)

**Avoids:** Shipping before design bar is reached — once public, first impressions cannot be reversed

**Note:** This phase may overlap with Phase 2 UI work; the separation is conceptual. The test is: does opening the app at 11pm and seeing your day feel worth doing again tomorrow?

### Phase 4: Background Reliability and Battery Validation

**Rationale:** Once the core loop is proven on developer devices, the app needs real-user reliability testing before wider distribution. BGTask unreliability, force-quit data gaps, and battery drain are silent killers that only surface with real usage patterns.

**Delivers:** Foreground refresh as primary timeline generation path, BGTask as supplement, "last updated" timestamp in UI, force-quit gap handling, battery validation on non-developer devices

**Addresses:** BGTask unreliability (Pitfall 4), force-quit data gaps (Pitfall 3), battery efficiency (table stakes needing validation)

**Avoids:** Users experiencing stale timelines at the 11pm check-in moment; users uninstalling due to battery drain

**Must implement:** Foreground refresh path (timeline generation on app open), pull-to-refresh, gap indicators distinguishing "no data" from "phone was off", real-device battery testing protocol

### Phase 5: Apple Foundation Models (Free Tier)

**Rationale:** This phase is gated on iOS 26 stability and Xcode 26 toolchain. It should be implemented once the cloud path is proven working — implementing a fallback to a working system is lower risk than building against a brand-new OS API as the primary path.

**Delivers:** On-device AI for iOS 26+ users with Apple Intelligence; zero API cost for free tier; stronger privacy story

**Addresses:** `AppleLocalAIProvider` stub implementation (STACK recommendation), free tier architecture

**Avoids:** Foundation Models 4096 token limit violations (STACK constraint) — requires prompt size validation; one-session-per-message anti-pattern (ARCHITECTURE warning)

**Requires:** iOS 26 release stability, Xcode 26, iPhone 15 Pro+ or iPhone 16+ test devices

### Phase 6: Pattern Recognition and Proactive Push

**Rationale:** Pattern recognition ("you've been at the library 3 days in a row") requires a minimum of 3 weeks of daily summaries to produce meaningful output. This phase cannot ship until the data accumulates. The algorithmic pattern detection is a database query over `DailySummaryEntity` records — no Core ML, no new storage models required. The output feeds a structured text prompt to Claude Sonnet 4.6 for human-readable insight generation.

**Delivers:** Cross-day pattern detection, one proactive daily notification with a meaningful insight, in-app Echo inbox as primary surface for insights (not just push)

**Addresses:** Pattern recognition (Tier 1 ACTIVE roadmap feature), AI proactive push (Tier 2 differentiator), proactive insight architecture (ARCHITECTURE Step 6+7)

**Avoids:** Notification opt-in rate reality (~44%) — in-app inbox must be the primary surface, push is amplification only; Core ML misuse for sequence pattern recognition (Pitfall 13)

**Prerequisite:** 3+ weeks of daily summaries accumulated from real users

### Phase 7: Echo Conversation

**Rationale:** "Chat with your data" is a clear step-change over every competitor, but it requires: (a) proven daily summary quality as conversational context, (b) indexed history of summaries and events for retrieval, (c) multi-turn session handling with FoundationModels or Claude. The EchoEngine infrastructure exists; this phase is query design and UI polish.

**Delivers:** Natural language query over personal history ("how many hours did I spend at the library this week?"), multi-turn Echo chat, retrieval over SwiftData `DailySummaryEntity` records

**Addresses:** Echo conversation (Tier 2 differentiator), EchoThreadViewModel / EchoChatViewModel UI

**Avoids:** Chat-first AI interface anti-feature — timeline remains primary surface; one-session-per-message anti-pattern (ARCHITECTURE warning — cache LanguageModelSession per chat thread)

---

### Phase Ordering Rationale

- Security fix (Phase 1) must precede all external distribution — no exceptions
- Onboarding (Phase 2) must precede marketing or sharing — without Always location, nothing works
- Design polish (Phase 3) must precede any public positioning as a premium product
- Pattern features (Phase 6) are data-gated — they cannot ship before accumulating weeks of user data regardless of engineering readiness
- Echo conversation (Phase 7) is foundation-gated — daily summary quality must be validated before building conversation on top of it
- Foundation Models (Phase 5) is toolchain-gated — decoupled from user-facing phases by iOS 26 requirement

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 5 (Foundation Models):** iOS 26 toolchain is new; `@Generable` macro behavior for structured output, session lifetime management, and streaming token UX patterns will need hands-on exploration
- **Phase 6 (Pattern Recognition):** Prompt engineering for cross-day behavioral insight generation is domain-specific with no established templates; requires experimentation to avoid generic or inaccurate outputs
- **Phase 7 (Echo Conversation):** SwiftData retrieval strategy for natural language query routing (what data to fetch given an arbitrary question) needs design; no standard pattern exists for this use case

Phases with well-documented standard patterns (research-phase likely unnecessary):
- **Phase 1 (Security + Wiring):** AIProxy integration and SwiftAnthropic are well-documented; EchoScheduler wiring is a mechanical connection of existing pieces
- **Phase 2 (Onboarding):** CoreLocation permission request patterns are exhaustively documented; App Store reviewer expectations for Always location are clearly stated in guidelines
- **Phase 4 (Background Reliability):** BGTask patterns, foreground refresh, and battery testing methodology are standard iOS engineering

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Foundation Models verified against WWDC25 official sessions; Claude pricing verified against official Anthropic pages; AIProxy documented; DeepSeek deprecation rationale is clear |
| Features | HIGH for table stakes; MEDIUM for differentiators | Competitive feature set verified against official App Store listings; AI retention lift claims are inferred, not studied for this app specifically |
| Architecture | HIGH | Existing codebase was read directly; FoundationModels framework verified against official Apple developer documentation and WWDC25 sessions |
| Pitfalls | HIGH for CoreLocation/BGTask/API security; MEDIUM for App Store review specifics | CoreLocation behavior verified against official Apple docs and production engineering blog posts; App Store review specifics based on guideline text + community reports |

**Overall confidence:** HIGH

### Gaps to Address

- **Claude pricing stability:** Verified as of research date but subject to Anthropic pricing changes. Monitor before committing to free-tier economics in any pricing copy.
- **Foundation Models token limit validation:** The 4096 combined token limit is verified from multiple sources, but real-world prompt sizes with Chinese-language output and emoji may differ from English estimates. Validate with actual prompts before committing to prompt architecture.
- **Battery drain at scale:** No data exists for this specific app's tracking profile on non-developer devices. Real user battery testing is required before any claim about battery efficiency.
- **AI insight retention lift:** Whether the daily AI summary actually improves D7/D30 retention is untested. The assumption that it does — based on Gyroscope G1 and Apple Journal analogies — is a product hypothesis, not a research finding. The fastest way to validate is to ship and measure.
- **SwiftAnthropic Swift 6 concurrency compliance:** Package is community-maintained (v2.1.8). Monitor for Swift 6 strict concurrency warnings as the project moves toward iOS 26 / Swift 6 targets.
- **Approximate location handling in PlaceManager:** The 200m cluster radius is currently hard-coded. Whether adjusting it dynamically on reduced accuracy improves or degrades timeline quality is unknown without user testing.

---

## Sources

### Primary (HIGH confidence)
- Apple WWDC25: "Meet the Foundation Models framework" — https://developer.apple.com/videos/play/wwdc2025/286/
- Apple WWDC25: "Deep dive into the Foundation Models framework" — https://developer.apple.com/videos/play/wwdc2025/301/
- Apple Foundation Models documentation — https://developer.apple.com/documentation/FoundationModels
- Apple BGTaskScheduler documentation — https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler
- Apple App Store Review Guidelines — https://developer.apple.com/app-store/review/guidelines/
- Apple: startMonitoringSignificantLocationChanges() — https://developer.apple.com/documentation/corelocation/cllocationmanager/startmonitoringsignificantlocationchanges()
- Existing codebase read directly — `/Users/looanli/Projects/ToDay/ios/ToDay/ToDay/Data/AI/`
- Arc Timeline — https://www.bigpaua.com/arcapp/ and https://apps.apple.com/us/app/arc-timeline-trips-places/id1063151918
- Life Cycle — https://apps.apple.com/us/app/life-cycle-track-your-time/id1064955217
- Gyroscope — https://gyrosco.pe/

### Secondary (MEDIUM confidence)
- SwiftAnthropic GitHub — https://github.com/jamesrochabrun/SwiftAnthropic (community package, v2.1.8)
- AIProxy documentation — https://www.aiproxy.com/docs/integration-guide.html
- LLM pricing comparison — https://intuitionlabs.ai/articles/llm-api-pricing-comparison-2025
- Foundation Models guide (AzamSharp) — https://azamsharp.com/2025/06/18/the-ultimate-guide-to-the-foundation-models-framework.html
- Foundation Models limitations (Natasha the Robot) — https://www.natashatherobot.com/p/apple-foundation-models
- High Performance SwiftData Apps (Jacob Bartlett) — https://blog.jacobstechtavern.com/p/high-performance-swiftdata
- Core Location Modern API Tips (twocentstudios) — https://twocentstudios.com/2024/12/02/core-location-modern-api-tips/
- iOS Location Tracking Caveats (Bumble Tech) — https://medium.com/bumble-tech/ios-location-tracking-aac4e2323629
- Push notification opt-in rates (Pushwoosh) — https://www.pushwoosh.com/blog/push-notification-benchmarks/
- AI API cost best practices (Skywork) — https://skywork.ai/blog/ai-api-cost-throughput-pricing-token-math-budgets-2025/

### Tertiary (LOW confidence)
- AI insight retention lift assumption — inferred from Gyroscope G1 market success and Apple Journal adoption; no independent A/B study for this app type
- Approximate location cluster radius adjustment — theoretical recommendation; not validated with user testing

---

*Research completed: 2026-04-04*
*Ready for roadmap: yes*
