# Requirements: Unfold

**Defined:** 2026-04-04
**Core Value:** 让用户睡前打开 App，一眼看到自己今天是怎么度过的，并从 AI 那里获得一句让他想继续用的洞察。

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Security

- [ ] **SEC-01**: App binary does not contain any hardcoded API keys or secrets
- [ ] **SEC-02**: Cloud API calls route through AIProxy or equivalent key protection layer
- [ ] **SEC-03**: AI API calls have per-user daily rate limits to prevent cost runaway

### Onboarding

- [x] **ONB-01**: User is guided through Location "Always" permission with clear value explanation before system dialog
- [x] **ONB-02**: User is guided through Motion permission with clear value explanation
- [x] **ONB-03**: Permission denial is handled gracefully with path to Settings
- [x] **ONB-04**: App Store usage description strings are specific enough to pass App Review

### Recording

- [x] **REC-01**: App automatically records location visits in background without user action
- [x] **REC-02**: App detects and records activity type (walking, running, driving, cycling, stationary)
- [x] **REC-03**: App infers events from sensor data (sleep, commute, exercise, location stay)
- [x] **REC-04**: Places are auto-labeled via reverse geocoding (e.g. "星巴克", "北大图书馆")
- [x] **REC-05**: Places are auto-classified as home/work/frequent based on visit patterns
- [x] **REC-06**: Recording survives app being killed by system (significant location change re-launch)
- [x] **REC-07**: Data gaps from force-quit/airplane mode are displayed gracefully, not hidden

### Timeline UI

- [x] **TML-01**: User sees a vertical timeline of their day with time-of-day gradient background
- [x] **TML-02**: Each event shows type badge, duration, and place name
- [x] **TML-03**: User can tap an event to see details
- [x] **TML-04**: User can annotate blank periods with what they were doing
- [x] **TML-05**: Timeline visual quality reaches Apple-level design standard per .impeccable.md
- [x] **TML-06**: User can browse any past day's timeline via history screen

### AI Daily Summary

- [ ] **AIS-01**: App generates a short AI summary of the user's day (1-2 sentences) using cloud API
- [ ] **AIS-02**: Summary references specific places and activities from the user's actual data
- [x] **AIS-03**: Summary is displayed prominently on the today screen
- [ ] **AIS-04**: Summary tone is observational ("你今天..."), never prescriptive ("你应该...")
- [ ] **AIS-05**: Summary generation runs automatically when user opens app in evening or on app background

### AI Pattern Recognition

- [x] **AIP-01**: App detects repeated behavioral patterns across days (e.g. "连续3天下午都在图书馆")
- [x] **AIP-02**: Patterns are surfaced as insights in the today screen when sufficient data exists (3+ weeks)
- [x] **AIP-03**: App sends one daily push notification with a meaningful AI insight (max 1/day)

### AI Conversation

- [x] **AIC-01**: User can ask Echo questions about their life data ("我这周运动了几次？")
- [x] **AIC-02**: Echo responds with accurate answers based on stored timeline data
- [x] **AIC-03**: Echo conversation history persists across sessions

### Manual Recording

- [x] **MAN-01**: User can record mood with one tap
- [x] **MAN-02**: User can capture moments via text/voice/photo (shutter)
- [x] **MAN-03**: Manual records appear inline on the timeline

### Privacy & Compliance

- [ ] **PRV-01**: No raw GPS coordinates are sent to cloud AI — only place names and event descriptions
- [x] **PRV-02**: Privacy policy page exists and is accessible from app settings
- [x] **PRV-03**: App Review Notes explain Always Location usage clearly

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Apple Watch Integration

- **WAT-01**: Heart rate data enriches timeline events
- **WAT-02**: Sleep data from Watch replaces screen-lock inference
- **WAT-03**: Workout detection from Watch supplements CoreMotion

### On-Device AI

- **DEV-01**: Apple Intelligence / Foundation Models provides free-tier AI summaries (iOS 26+)
- **DEV-02**: On-device fallback when cloud API unavailable

### Social & Sharing

- **SHR-01**: User can export a day as a shareable image card
- **SHR-02**: Share card has Instagram-quality design

### Trends & Analytics

- **TRD-01**: Cross-week trend visualization
- **TRD-02**: Year-in-review annual report

### Monetization

- **MON-01**: Pro subscription tier with AI features
- **MON-02**: Free tier with limited AI usage

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Gamification (streaks, badges, XP) | Conflicts with "intimate, unhurried" brand; creates anxiety |
| Social feed / leaderboards | Location data is deeply personal; social pressure destroys reflective use |
| Coaching / behavioral nudges | Crosses from mirror to parent; AI describes, never prescribes |
| Screen time auto-capture | Requires Family Controls entitlement; Apple hostile to this |
| Manual time entry / work timer | Toggl/Timery territory; wrong mental model for passive recording |
| Mood questionnaires / daily prompts | Breaks passive recording promise |
| Aggregate health dashboard | Gyroscope does this at $29/mo; wrong competitive axis |
| Cloud sync / multi-device | Adds complexity and privacy attack surface |
| Web dashboard | Phone-in-bed moment; web is wrong context |
| Push notification flood | 45% iOS opt-in rate; spam kills retention permanently |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| SEC-01 | Phase 1 | Pending |
| SEC-02 | Phase 1 | Pending |
| SEC-03 | Phase 1 | Pending |
| AIS-01 | Phase 1 | Pending |
| AIS-02 | Phase 1 | Pending |
| AIS-04 | Phase 1 | Pending |
| AIS-05 | Phase 1 | Pending |
| PRV-01 | Phase 1 | Pending |
| ONB-01 | Phase 2 | Complete |
| ONB-02 | Phase 2 | Complete |
| ONB-03 | Phase 2 | Complete |
| ONB-04 | Phase 2 | Complete |
| AIS-03 | Phase 2 | Complete |
| REC-07 | Phase 2 | Complete |
| PRV-02 | Phase 2 | Complete |
| PRV-03 | Phase 2 | Complete |
| TML-01 | Phase 3 | Complete |
| TML-02 | Phase 3 | Complete |
| TML-03 | Phase 3 | Complete |
| TML-04 | Phase 3 | Complete |
| TML-05 | Phase 3 | Complete |
| TML-06 | Phase 3 | Complete |
| REC-01 | Phase 3 | Complete |
| REC-02 | Phase 3 | Complete |
| REC-03 | Phase 3 | Complete |
| REC-04 | Phase 3 | Complete |
| REC-05 | Phase 3 | Complete |
| REC-06 | Phase 3 | Complete |
| MAN-01 | Phase 3 | Complete |
| MAN-02 | Phase 3 | Complete |
| MAN-03 | Phase 3 | Complete |
| AIP-01 | Phase 4 | Complete |
| AIP-02 | Phase 4 | Complete |
| AIP-03 | Phase 4 | Complete |
| AIC-01 | Phase 5 | Complete |
| AIC-02 | Phase 5 | Complete |
| AIC-03 | Phase 5 | Complete |
