# Feature Landscape: iOS Auto Life-Tracking + AI

**Domain:** Passive iOS life-tracking with AI insight layer
**Project:** Unfold (working name)
**Researched:** 2026-04-04
**Research mode:** Ecosystem + Competitive analysis

---

## Competitive Landscape Summary

| App | Core Bet | AI? | Model |
|-----|----------|-----|-------|
| Life Cycle | Donut pie chart of time allocation | No (stats only) | Freemium |
| Arc Timeline | Richest automatic GPS + activity log | No | Subscription / Lifetime |
| Gyroscope | Comprehensive health OS with AI coach | Yes (heavy) | $29/mo |
| Exist | Cross-service correlations, data aggregation | Light (correlations) | Subscription |
| Daylio | Manual mood + activity log with stats | Minimal | Freemium |
| Apple Journal | Passive suggestion-driven journaling | Yes (on-device) | Free (iOS built-in) |
| Limitless/Rewind | Screen + audio lifelogging, AI recall | Yes (heavy) | Acquired by Meta (dead) |

**Key gap Unfold is targeting:** None of the above delivers both beautiful passive recording AND emotional AI insight. Life Cycle and Arc give data. Gyroscope and Exist require setup effort. Apple Journal requires manual writing. Unfold's bet: zero-friction + design-as-differentiator + one resonant AI moment per day.

---

## Table Stakes

Features users expect from any auto life-tracking app. Missing = users leave or never return after day one.

| Feature | Why Expected | Complexity | Unfold Status |
|---------|--------------|------------|---------------|
| Automatic location tracking (background) | Core premise — if user must open app to record, product is dead | Low (infra) / High (battery) | DONE — CoreLocation significant changes + visits |
| Place recognition and labeling | Raw GPS is unreadable; "Home", "Coffee shop" is the minimum readable unit | Medium | DONE — PlaceManager + CLGeocoder |
| Activity/transport detection | Walking vs driving matters for interpreting a day | Medium | DONE — CoreMotion activity recognition |
| Daily timeline view | Users must see "their day" in one scroll; no timeline = no product | Medium | DONE — DayScrollView + EventCardView |
| History / past days access | Users re-open the app to revisit yesterday, last week; no history = no retention | Low | DONE — HistoryScreen |
| Permission onboarding | CoreLocation "Always" requires clear value explanation to get granted | Medium | ACTIVE — not shipped |
| Battery efficiency | If tracking drains battery, users disable it or delete the app immediately | High | Needs validation at scale |
| Privacy-first architecture | Location data is highly sensitive; local-first is now a strong expectation post-Limitless/Rewind acquisition | Low (decision) / Medium (execution) | DONE — SwiftData local-first |
| Graceful data gaps | Periods of no signal, airplane mode, dead phone — must handle gracefully without corrupting the timeline | Medium | Needs explicit gap-handling review |
| Manual entry / annotation | Users want to add context auto-tracking cannot infer (mood, a note, a photo) | Low | DONE — mood/shutter/spending/annotation |

---

## Differentiators

Features that create competitive advantage. Not universally expected, but drive word-of-mouth and retention when done well.

### Tier 1 — Core Differentiators (ship in current milestone)

| Feature | Value Proposition | Complexity | Dependencies | Unfold Status |
|---------|-------------------|------------|--------------|---------------|
| Visual design / "画卷" aesthetic | Design is the moat — Arc and Life Cycle are functional but cold; a timeline users want to look at is viral by nature | High (craft) | Timeline foundation | ACTIVE |
| AI daily summary (one sentence / short paragraph) | The product's emotional payoff — gives users a reason to open at night; Arc and Life Cycle never do this | Medium | Cloud API, clean event data | ACTIVE |
| Semantic place naming | Going beyond raw geocoding to infer "your library," "Starbucks on Xujiahui" — makes the timeline feel known | Medium | PlaceManager, clustering history | Partial — geocoding exists |
| "You've been here before" pattern recognition | "Third Tuesday in a row at the library" — makes data feel alive without overwhelming | High | Multi-day history, pattern engine | ACTIVE (roadmap) |

### Tier 2 — Strong Differentiators (next milestone)

| Feature | Value Proposition | Complexity | Dependencies |
|---------|-------------------|------------|--------------|
| AI proactive push — one insight per day | Single daily notification that says something true and specific about the user's actual behavior — not generic; this is the "AI mirror" moment | High | Pattern engine, fine-tuned prompting, multi-day data |
| Echo conversation (chat with your data) | "How many hours did I spend at the library this week?" — Arc exports to GPX but never answers questions; this is a clear step-change | High | EchoEngine, natural language query layer, retrieval over SwiftData |
| Cross-week trend visualization | "You slept in 4 of the last 7 days" — goes beyond today to show trajectory; Exist does this but requires 20+ integrations | Medium | Multi-week data, chart components |
| Shareable "day recap" card | Instagram-quality export of today's timeline — organic growth vector, especially for students / young users | Medium | Timeline visual polish, share sheet |

### Tier 3 — Long-term Differentiators (future milestones)

| Feature | Value Proposition | Complexity | Dependencies |
|---------|-------------------|------------|--------------|
| Apple Watch heart rate + workout correlation | Adds body layer to place/movement layer — "You were at the gym but your heart rate suggests it was light" | High | Watch integration, HealthKit HRV |
| On-device lightweight AI inference | Privacy-forward analysis that works offline; Apple Intelligence integration if Apple opens APIs | High | Apple Intelligence APIs, Core ML models |
| "Year in Review" annual report | Gyroscope does this well; high shareability, strong retention driver for annual subscription tier | Medium | 365+ days of data, report template |
| Personalized place categories (custom labels) | Power user feature — "Name this place 'Dad's house'"; Arc supports this, users love it | Low | Place data model extension |

---

## Anti-Features

Features to deliberately NOT build, with rationale.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Gamification (streaks, badges, XP) | Attracts wrong users; creates anxiety when users skip a day; conflicts with "intimate, unhurried" brand | Quiet acknowledgment of consistency in AI summary tone |
| Social feed / leaderboards | Life Cycle tried social and removed it; location data is deeply personal; social pressure destroys the reflective use case | Optional shareable card is enough — pull not push |
| Coaching / behavioral nudges | "You should go to bed earlier" — crosses from mirror to parent; users did not ask for advice | AI summary describes, never prescribes |
| Screen time auto-capture | Requires Family Controls entitlement (MDM-level approval); Apple is hostile to this; violates app store guidelines without specific justification | Explicitly out of scope per PROJECT.md |
| Manual time entry (work timer mode) | This is Toggl / Timery territory; pulls product into B2B time tracking; wrong user mental model | Stay passive — tracking is never the user's job |
| Mood questionnaires | Daylio does daily mood prompts; asking "how do you feel?" breaks passive recording promise | Accept mood as optional manual tap, never prompt |
| Aggregate health dashboard (steps, HRV, calories) | Gyroscope already does this at $29/mo; competing on health data breadth against HealthKit integration leaders is losing | Own the place + time narrative, not the health metric narrative |
| Chat-first AI interface | An AI chatbot as the primary surface makes the product feel like ChatGPT with location data; the timeline is the primary surface | Echo conversation is a secondary surface, never the entry point |
| Cloud sync / multi-device | Adds infrastructure complexity and privacy attack surface; local-first is simpler and resonates with privacy-aware users | SwiftData + iCloud backup as optional, not primary |
| Web dashboard | Unfold's "sleeping hours" use case is a phone-in-bed moment; web is wrong context | iPhone native only |
| Push notification flood | 45% iOS opt-in rate; users who feel spammed disable notifications permanently; once disabled, retention collapses | One meaningful push per day maximum — the AI insight |

---

## Feature Dependencies

```
CoreLocation background recording
  └── PlaceManager clustering
        └── Semantic place labeling
              └── AI daily summary (needs clean place names as context)
                    └── AI proactive push (needs reliable summary as foundation)
                          └── Echo conversation (needs indexed history of summaries + events)

CoreMotion activity detection
  └── PhoneInferenceEngine (sleep/commute/exercise/stay)
        └── Daily timeline view (EventCardView renders inferred events)
              └── Cross-week trend visualization (aggregates timeline events)
                    └── "Year in Review" annual report

Historical data (SwiftData)
  └── History screen (browse past days)
        └── Pattern recognition ("third Tuesday in a row")
              └── AI proactive push (pattern as content of push)

Visual design / timeline polish
  └── Shareable day recap card (must look good before sharing)

Permission onboarding
  └── Everything (without Always location, nothing works)
```

---

## MVP Recommendation

**The one thing that makes Unfold worth opening tonight:**

The core loop is: passive recording runs in background → user opens at night → sees their day as a beautiful timeline → reads one AI sentence that says something true about their day → closes with a feeling of being seen.

**Prioritize in current milestone:**
1. Permission onboarding — nothing works without Always location granted; this is the single highest-leverage unshipped feature
2. AI daily summary — the one moment of payoff that separates Unfold from Arc/Life Cycle; one paragraph, cloud API, generated from clean event + place data
3. Visual polish of the "画卷" timeline — design is the moat; must reach Apple-level quality before any other surface is added
4. Graceful gap handling — ship confidence that dead battery / airplane mode doesn't corrupt the timeline

**Defer from current milestone:**
- Pattern recognition ("third Tuesday"): needs 3+ weeks of data to be meaningful; premature to ship
- Echo conversation: EchoEngine exists but the AI foundation (daily summary) must prove itself first
- Shareable recap card: depends on timeline polish reaching the quality bar
- Cross-week trends: secondary surface; adds complexity without proving core loop
- Apple Watch integration: explicitly out of scope per PROJECT.md

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Competitive feature set (Life Cycle, Arc) | HIGH | Official App Store listings + press releases + user reviews verified |
| Competitive feature set (Gyroscope, Exist) | HIGH | Official websites + product pages verified |
| User expectations / table stakes | MEDIUM | Inferred from app reviews, competitive gaps, general iOS app retention data |
| AI feature patterns (what works) | MEDIUM | Gyroscope G1 and Apple Journal are leading examples; no independent study on "AI insight" retention lift |
| Anti-feature rationale | MEDIUM | Based on competitive observations + push notification research; not A/B tested for Unfold's specific user |
| Churn reasons specific to life tracking | LOW | General mobile churn data applied; life tracking app-specific churn studies are scarce |

---

## Sources

- [Life Cycle - App Store](https://apps.apple.com/us/app/life-cycle-track-your-time/id1064955217)
- [Life Cycle press release — Northcube](https://northcube.com/lifecycle/press/introducing-life-cycle-new-app-tracks-time-life-automatically/)
- [Tracking Life in Life Cycle — Podfeet Podcasts (2024)](https://www.podfeet.com/blog/2024/08/tracking-life-in-life-cycle/)
- [Arc Timeline — Big Paua official site](https://www.bigpaua.com/arcapp/)
- [Arc Timeline — App Store](https://apps.apple.com/us/app/arc-timeline-trips-places/id1063151918)
- [Arc Timeline support forum — feature requests v3.17](https://support.bigpaua.com/t/what-would-you-like-to-see-in-arc-timeline-v3-17/677)
- [Gyroscope — official site](https://gyrosco.pe/)
- [Gyroscope G1 — official page](https://gyrosco.pe/one/)
- [Gyroscope V8 launch — Athletech News](https://athletechnews.com/gyroscope-v8-glp1-smart-health-tracking/)
- [Exist — official site](https://exist.io/)
- [Exist blog — use cases](https://exist.io/blog/use-cases/)
- [Daylio — official site](https://daylio.net/)
- [Apple Journal launch — Apple Newsroom](https://www.apple.com/newsroom/2023/12/apple-launches-journal-app-a-new-app-for-reflecting-on-everyday-moments/)
- [Meta acquires Limitless / Rewind sunset — WinBuzzer (Dec 2025)](https://winbuzzer.com/2025/12/05/meta-acquires-ai-wearables-startup-limitless-kills-pendant-sales-and-sunsets-rewind-app-xcxwbn/)
- [Push notification best practices 2026 — Appbot](https://appbot.co/blog/app-push-notifications-2026-best-practices/)
- [Mobile app churn benchmarks 2025 — UXCam](https://uxcam.com/blog/mobile-app-churn-rate/)
- [AlternativeTo — Arc Timeline alternatives](https://alternativeto.net/software/arc-app/)
