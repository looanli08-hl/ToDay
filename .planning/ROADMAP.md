# Roadmap: Unfold

## Overview

Unfold has a complete sensor-to-timeline pipeline that already works — location, motion, inference, and SwiftData storage are all running with 180 passing tests. The AI layer (EchoScheduler, EchoAIService, EchoPromptBuilder) is built but disconnected and has a live security breach (hardcoded API key). This roadmap wires together what exists, closes the security hole, ships the emotional core of the product (daily AI summary), and then builds the differentiating AI features that give users a reason to keep recording.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Security and AI Pipeline** - Remove hardcoded API key, migrate to Claude via AIProxy, wire EchoScheduler to app lifecycle so daily summaries generate and persist
- [x] **Phase 2: Onboarding and First Visible AI** - Ship permission onboarding that gets Always Location granted, surface AI summary on TodayScreen, handle data gaps gracefully, complete privacy compliance (completed 2026-04-04)
- [ ] **Phase 3: Timeline and Recording Polish** - Raise the "画卷" timeline to Apple-quality design; validate the complete passive recording pipeline on real devices
- [x] **Phase 4: Pattern Recognition and Proactive Push** - Detect behavioral patterns across days, surface one meaningful daily notification insight (completed 2026-04-05)
- [ ] **Phase 5: Echo Conversation** - Enable users to ask Echo natural language questions about their life data

## Phase Details

### Phase 1: Security and AI Pipeline
**Goal**: The AI daily summary pipeline runs correctly and the app binary contains no secrets
**Depends on**: Nothing (first phase)
**Requirements**: SEC-01, SEC-02, SEC-03, AIS-01, AIS-02, AIS-04, AIS-05, PRV-01
**Success Criteria** (what must be TRUE):
  1. No API key, secret, or credential appears in any source file or compiled binary
  2. AI daily summary is generated automatically when the user backgrounds or opens the app in the evening, and the result is stored in SwiftData
  3. Summary text references actual place names and activities from the user's recorded day (not generic filler)
  4. Summary tone is observational — it describes what happened, never tells the user what they should do
  5. Cloud AI calls pass through AIProxy; per-user daily rate limit prevents cost runaway
**Plans**: 3 plans

Plans:
- [ ] 01-01-PLAN.md — Add AIProxySwift package and create AnthropicAIProvider
- [ ] 01-02-PLAN.md — Remove hardcoded key, wire provider, configure AIProxy, add tone guard
- [ ] 01-03-PLAN.md — Binary strings verification and user credential checkpoint

### Phase 2: Onboarding and First Visible AI
**Goal**: A new user can install the app, grant Always Location, see their day record, and read their AI insight — all within the first session
**Depends on**: Phase 1
**Requirements**: ONB-01, ONB-02, ONB-03, ONB-04, AIS-03, REC-07, PRV-02, PRV-03
**Success Criteria** (what must be TRUE):
  1. User sees a value explanation screen before any system permission dialog appears
  2. User who denies location permission sees a clear recovery path to Settings rather than a broken empty state
  3. AI daily summary card appears on the TodayScreen at a prominent position the user encounters naturally
  4. Periods where the phone was off, force-quit, or in airplane mode are shown as labeled gap indicators, not missing time
  5. Privacy policy is accessible from app Settings and accurately discloses that anonymized activity summaries (not GPS) are sent to an AI provider
**Plans**: 3 plans

Plans:
- [x] 02-01-PLAN.md — Rewrite OnboardingView as multi-step flow with two-step Always Location and denial recovery
- [x] 02-02-PLAN.md — Wire AI summary to TodayScreen, add dataGap EventKind, fix LocationCollector whenInUse bug
- [x] 02-03-PLAN.md — Update DataExplanationView privacy disclosure, produce App Review Notes document

### Phase 3: Timeline and Recording Polish
**Goal**: Opening the app at 11pm and seeing your day feels worth doing again tomorrow
**Depends on**: Phase 2
**Requirements**: TML-01, TML-02, TML-03, TML-04, TML-05, TML-06, REC-01, REC-02, REC-03, REC-04, REC-05, REC-06, MAN-01, MAN-02, MAN-03
**Success Criteria** (what must be TRUE):
  1. Timeline visual quality passes the .impeccable.md design bar — warm cream palette, time-of-day gradient, no generic AI aesthetics
  2. Each event card displays a type badge, duration, and specific place name; tapping reveals detail
  3. Manual mood tap, moment capture, and annotation on blank periods are accessible without leaving the timeline
  4. User can navigate to any past day and see that day's complete timeline
  5. Recording pipeline survives system app kills and resumes correctly when the device registers a significant location change
**Plans**: 4 plans
**UI hint**: yes

Plans:
- [x] 03-01-PLAN.md — EventCardView + TodayScreen typography, corner radius, spacing, and shadow compliance
- [x] 03-02-PLAN.md — HistoryScreen + QuickRecordSheet + DayScrollView timestamp/moodRow compliance
- [x] 03-03-PLAN.md — Proportional event row heights + DayScrollViewTests (5 new tests)
- [x] 03-04-PLAN.md — LocationCollector authorization hardening + real-device recording validation (TestFlight checkpoint)

### Phase 4: Pattern Recognition and Proactive Push
**Goal**: The app surfaces one meaningful behavioral pattern per day that makes the user feel understood
**Depends on**: Phase 3
**Requirements**: AIP-01, AIP-02, AIP-03
**Success Criteria** (what must be TRUE):
  1. App detects repeated cross-day patterns (e.g. "you've been at the library three afternoons in a row") when 3+ weeks of data exist
  2. Pattern insights appear in the today screen when data is sufficient; no insight is shown when data is insufficient rather than showing a placeholder
  3. App sends at most one push notification per day containing a meaningful behavioral insight (not a generic reminder)
**Plans**: 3 plans

Plans:
- [x] 04-01-PLAN.md — PatternDetectionEngine TDD: DetectedPattern types + streak detection + data-sufficiency guard
- [x] 04-02-PLAN.md — EchoScheduler.onPatternCheck() + EchoPromptBuilder.buildPatternInsightPrompt + notification scheduling
- [x] 04-03-PLAN.md — TodayViewModel.latestPatternInsight + TodayScreen patternInsightSection + AppContainer wiring

### Phase 5: Echo Conversation
**Goal**: Users can ask Echo questions about their recorded life and get accurate, specific answers
**Depends on**: Phase 4
**Requirements**: AIC-01, AIC-02, AIC-03
**Success Criteria** (what must be TRUE):
  1. User can type a natural language question ("我这周运动了几次？") and receive an answer grounded in their actual timeline data
  2. Echo's answers are accurate — they reference real stored events, not hallucinated summaries
  3. Conversation history persists across app sessions so users can scroll back through past exchanges
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Security and AI Pipeline | 0/3 | Not started | - |
| 2. Onboarding and First Visible AI | 3/3 | Complete   | 2026-04-04 |
| 3. Timeline and Recording Polish | 3/4 | In Progress|  |
| 4. Pattern Recognition and Proactive Push | 3/3 | Complete   | 2026-04-05 |
| 5. Echo Conversation | 0/TBD | Not started | - |
