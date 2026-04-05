# Phase 4: Pattern Recognition and Proactive Push - Research

**Researched:** 2026-04-04
**Domain:** SwiftData multi-day behavioral analysis, UserNotifications, prompt engineering for pattern insight
**Confidence:** HIGH

---

## Summary

Phase 4 adds the behavioral pattern engine on top of the existing AI and data infrastructure. The core question is: "has the user done something recognizable across multiple days, and can we say something true and resonant about it in one sentence?"

The answer lives in `DayTimelineEntity` and `DailySummaryEntity` — both already populated by the recording pipeline and EchoScheduler. No new data stores are required. The algorithmic pattern detection is a database query problem, not a machine learning problem: fetch the last N days of timeline entries, group by `displayName`, count consecutive occurrences, and identify the highest-signal pattern. That structured finding is then fed as a narrow, specific prompt to the AI for natural-language generation. The output is surfaced both as an `EchoMessageType.dailyInsight` in the Echo inbox and as a single `UNCalendarNotificationTrigger` push at an evening hour.

The critical data-gate constraint (3+ weeks of real data) documented in STATE.md is an operational concern, not an engineering blocker. The code can be shipped as soon as Phase 3 is verified. The guard is a runtime check comparing `DailySummaryEntity` count against a minimum threshold, not a code-level lock.

**Primary recommendation:** Build `PatternDetectionEngine` as a pure value-type struct that reads from SwiftData and returns typed `DetectedPattern` values. Wire it into `EchoScheduler` as a third trigger alongside `onAppBackground` and `onAppLaunch`. The notification fires once daily at the same hour as the daily summary trigger.

---

## Project Constraints (from CLAUDE.md)

- SwiftUI + iOS 17+ + SwiftData; no third-party UI frameworks
- Privacy-first: no raw GPS coordinates to any cloud API; only place names and event descriptions
- Local-first: all pattern data stays on-device; AI call sends only the pattern description text
- AI backend: existing `EchoAIService` / `EchoAIProviding` protocol; no new provider needed
- 180+ tests must remain passing after each change
- Build flow: `xcodegen generate` → build passes → tests pass
- Naming conventions: Engine suffix for domain engines, Entity suffix for SwiftData models
- `@MainActor final class` for ViewModels, pure structs for value types

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| AIP-01 | App detects repeated behavioral patterns across days (e.g. "连续3天下午都在图书馆") | `PatternDetectionEngine` reads `DayTimelineEntity.entries` across 21+ days; groups by `displayName` and time-of-day window; detects consecutive-day streaks |
| AIP-02 | Patterns are surfaced as insights on the today screen when sufficient data exists (3+ weeks); no placeholder shown when data is insufficient | Data-sufficiency guard in `EchoScheduler`; `TodayViewModel` reads persisted `EchoMessageEntity` of type `.dailyInsight`; conditional rendering with nil-coalescing, not placeholder |
| AIP-03 | App sends at most one push notification per day containing a meaningful behavioral insight (not a generic reminder) | `UNCalendarNotificationTrigger` scheduled once per day at the daily summary hour; idempotency key in `UserDefaults` matching `DailySummaryEntity.dateKey` pattern; permission check before scheduling |
</phase_requirements>

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftData (`FetchDescriptor`) | iOS 17+ built-in | Multi-day timeline and summary queries | Already the project's persistence layer; `dateKey` string sort enables date-range scans without Date comparisons |
| UserNotifications (`UNUserNotificationCenter`) | iOS 17+ built-in | Schedule one-per-day behavioral push | Already used in `EchoEngine.swift` via `SystemNotificationScheduler`; no new framework import required |
| Foundation (`Calendar`, `DateComponents`) | Built-in | Time-of-day bucketing (morning / afternoon / evening) and date arithmetic | Used throughout the codebase; `Calendar.current.component(.hour, from:)` is the right primitive |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `EchoAIService` (existing) | In-project | Natural-language formatting of detected patterns | Use `summarize(prompt:)` with a narrow, specific pattern prompt; same path as daily summary |
| `EchoMessageManager` (existing) | In-project | Persist pattern insight as Echo inbox message | Call `generateMessage(type: .dailyInsight, ...)` — same path as `EchoScheduler.onAppBackground` already uses |
| `EchoScheduler` (existing) | In-project | Orchestrate when pattern detection runs | Extend with `onPatternCheck()` method; called from `onAppBackground` after daily summary guard |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SwiftData string-sorted `dateKey` query | NSPredicate with Date comparison | `dateKey` is "yyyy-MM-dd" ISO format — string sort is lexicographically equivalent to date sort, and avoids SwiftData `#Predicate` Date-capture bugs |
| Algorithmic streak detection | Core ML sequence classification | No training data exists; "3 days in a row at library in afternoon" is a deterministic query, not a probabilistic classification problem |
| Local notification direct delivery | Push notification server | No server needed; all data is local; `UNCalendarNotificationTrigger` with `nil` trigger for immediate delivery or scheduled `DateComponents` works fully offline |

**Installation:** No new packages required. All required frameworks are already imported in the project.

---

## Architecture Patterns

### Pattern Detection Component Structure
```
Data/
├── AI/
│   ├── PatternDetectionEngine.swift   # NEW — pure struct, reads SwiftData, returns [DetectedPattern]
│   ├── EchoScheduler.swift            # EXTEND — add onPatternCheck() method
│   └── EchoPromptBuilder.swift        # EXTEND — add buildPatternInsightPrompt(_:) method
```

### Pattern 1: Data-Sufficiency Gate

**What:** Before running any pattern detection or sending any notification, check that a minimum number of `DailySummaryEntity` records exist. The REQUIREMENTS.md specifies "3+ weeks" — use 21 days as the threshold.

**When to use:** At the start of `onPatternCheck()` in `EchoScheduler`; also as a guard in `TodayViewModel` before displaying the pattern insight card.

**Example:**
```swift
// PatternDetectionEngine.swift
func hasSufficientData(context: ModelContext, minimumDays: Int = 21) -> Bool {
    var descriptor = FetchDescriptor<DailySummaryEntity>()
    let count = (try? context.fetchCount(descriptor)) ?? 0
    return count >= minimumDays
}
```
Source: SwiftData FetchDescriptor official docs — `fetchCount` is the correct API for a count-only query. Avoids fetching full objects.

### Pattern 2: Multi-Day Timeline Fetch with String-Range Predicate

**What:** Fetch `DayTimelineEntity` records for the last N days using the `dateKey` string property. Because the format is "yyyy-MM-dd" (ISO 8601), lexicographic string comparison equals chronological order — this avoids Date-capture bugs in SwiftData `#Predicate`.

**When to use:** Inside `PatternDetectionEngine.detectPatterns(context:lookbackDays:)`.

**Example:**
```swift
// PatternDetectionEngine.swift
func fetchRecentTimelines(context: ModelContext, lookbackDays: Int) -> [DayTimelineEntity] {
    let calendar = Calendar.current
    let cutoff = calendar.date(byAdding: .day, value: -lookbackDays, to: Date())!
    let cutoffKey = DayTimelineEntity.dateKey(for: cutoff)
    let descriptor = FetchDescriptor<DayTimelineEntity>(
        predicate: #Predicate { $0.dateKey >= cutoffKey },
        sortBy: [SortDescriptor(\.dateKey, order: .forward)]
    )
    return (try? context.fetch(descriptor)) ?? []
}
```
This pattern is already used in `EchoPromptBuilder.loadRecentTimelineSummaries(days:)` — replicate with a wider window (21–30 days).

### Pattern 3: Consecutive-Day Streak Detection

**What:** Group timeline entries across days by `(kind, displayName, timeOfDayBucket)`, then scan for streaks of N or more consecutive calendar days.

**When to use:** Core logic of `PatternDetectionEngine`. Operates entirely in memory after the SwiftData fetch.

**Time-of-day buckets:**
- Morning: 06:00–12:00
- Afternoon: 12:00–18:00
- Evening: 18:00–24:00

**Example:**
```swift
struct DetectedPattern: Sendable {
    let kind: EventKind
    let placeName: String        // e.g. "北大图书馆"
    let timeOfDay: TimeOfDayBucket
    let streakLength: Int        // number of consecutive days
    let recentDates: [Date]      // the specific days (for prompt context)
}

enum TimeOfDayBucket: String, Sendable {
    case morning, afternoon, evening
    static func from(hour: Int) -> TimeOfDayBucket {
        switch hour {
        case 6..<12: return .morning
        case 12..<18: return .afternoon
        default: return .evening
        }
    }
}

// Detection algorithm:
// 1. For each day's timeline, extract entries where kind == .quietTime or .workout
// 2. Group by (displayName, timeOfDayBucket(startDate))
// 3. Build a Set<String> of dateKeys for each group
// 4. Sort dateKeys and check for consecutive runs using Calendar.date(byAdding:value:to:)
// 5. Return patterns where streakLength >= minimumStreak (default 3)
```

### Pattern 4: AI Prompt for Pattern Natural-Language Formatting

**What:** A narrow, facts-only prompt fed to `EchoAIService.summarize(prompt:)` that turns a `DetectedPattern` into a resonant one-sentence Chinese insight.

**When to use:** In `EchoScheduler.onPatternCheck()` after a pattern is detected.

**Critical prompt constraints:**
- Supply only factual pattern data: place name, day count, time-of-day bucket
- Explicitly instruct: "描述，不评价，不建议，语气像老朋友说话"
- Output constraint: one sentence only, 20–40 characters
- Include specific place name and day count in the output

**Example:**
```swift
// EchoPromptBuilder.swift
func buildPatternInsightPrompt(_ pattern: DetectedPattern) -> String {
    let timeLabel: String
    switch pattern.timeOfDay {
    case .morning: timeLabel = "早上"
    case .afternoon: timeLabel = "下午"
    case .evening: timeLabel = "晚上"
    }
    return """
    请根据以下行为规律，生成一句简洁的中文观察（20-40字）。只描述规律，不评价，不建议，语气温和自然，像老朋友观察到的一件事。

    规律：用户连续\(pattern.streakLength)天\(timeLabel)都在\(pattern.placeName)

    只输出一句话，不加标题或解释。
    """
}
```

### Pattern 5: One-Per-Day Notification via UNCalendarNotificationTrigger

**What:** Schedule a single local notification for the daily pattern insight. The notification identifier uses the same `dateKey` idempotency pattern as `EchoScheduler.lastDailySummaryKey`.

**When to use:** In `EchoScheduler.onPatternCheck()` after successful AI generation.

**Key facts verified:**
- iOS max pending local notifications: 64 total per app (system discards oldest beyond limit)
- For one-per-day delivery, reuse the notification identifier keyed by `dateKey` — re-adding with the same identifier replaces the pending request, preventing duplicates
- Check `UNAuthorizationStatus` before scheduling; request permission only if `.notDetermined`
- `SystemNotificationScheduler.scheduleEchoNotification(identifier:title:body:triggerDate:)` already exists in `EchoEngine.swift` — reuse this, don't duplicate the UNNotificationCenter call

**Example:**
```swift
// EchoScheduler.swift — inside onPatternCheck()
let notificationID = "echo.pattern.\(dateKey)"
// Remove any previously scheduled notification for today (idempotent)
UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationID])

// Schedule for evening (same hour as daily summary trigger)
let triggerDate = Calendar.current.date(
    bySettingHour: dailySummaryHour, minute: 5, second: 0, of: Date()
)!
notificationScheduler.scheduleEchoNotification(
    identifier: notificationID,
    title: "Echo",
    body: insightText,  // the AI-generated one-sentence pattern
    triggerDate: triggerDate
)
```

### Pattern 6: Hooking PatternDetectionEngine into EchoScheduler

**What:** `EchoScheduler.onAppBackground()` already runs at the right time. After the daily summary guard succeeds, add a call to `onPatternCheck()`.

**When to use:** The pattern check runs in the same background execution window as the daily summary — no additional lifecycle hook needed.

**Example:**
```swift
// EchoScheduler.swift
func onPatternCheck() async {
    let context = ModelContext(AppContainer.modelContainer)
    let engine = PatternDetectionEngine()

    guard engine.hasSufficientData(context: context) else { return }

    let today = DayTimelineEntity.dateKey(for: Date())
    let lastKey = UserDefaults.standard.string(forKey: Self.lastPatternInsightKey)
    guard lastKey != today else { return }  // already ran today

    guard let pattern = engine.detectBestPattern(context: context) else { return }

    let prompt = promptBuilder.buildPatternInsightPrompt(pattern)
    let insightText = try await aiService.summarize(prompt: prompt)

    // Persist as Echo message
    if let manager = messageManager {
        await MainActor.run {
            try? manager.generateMessage(
                type: .dailyInsight,
                title: "Echo 发现了一个规律",
                preview: String(insightText.prefix(60)),
                sourceDescription: "来自：行为规律分析",
                sourceData: EchoSourceData(type: .dateRange, sourceDescription: "近期行为规律"),
                initialEchoMessage: insightText
            )
        }
    }

    // Schedule push notification
    // ... (see Pattern 5)

    UserDefaults.standard.set(today, forKey: Self.lastPatternInsightKey)
}
```

### Anti-Patterns to Avoid

- **Don't use Core ML for streak detection:** "3 consecutive days at library" is a deterministic query. Core ML adds training data requirements, model file size, and complexity for zero benefit here.
- **Don't send raw event coordinates to AI:** Pattern prompt must contain only place name and behavioral description — consistent with existing `EchoPromptBuilder` privacy contract.
- **Don't generate pattern insights from < 21 days of data:** Produces false positives (e.g., "you went to the library 2 days in a row" after barely one week of data). 21 days is the minimum signal window.
- **Don't schedule multiple notifications for the same day:** Use date-keyed identifier (`echo.pattern.2026-04-04`) and `removePendingNotificationRequests` before re-adding. The 64-notification limit is not at risk from one-per-day scheduling, but duplicate scheduling from repeated background triggers is a real risk.
- **Don't show a placeholder insight card:** AIP-02 explicitly requires "no insight shown when data is insufficient rather than showing a placeholder." Use `nil` guard in TodayViewModel, not empty/loading state.
- **Don't block on notification permission:** Pattern detection and Echo inbox message should proceed regardless. Push notification is amplification only; in-app Echo inbox is the primary surface.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Streak detection over sorted lists | Custom interval-overlap algorithm | Pure array iteration over ISO-sorted `dateKey` strings from SwiftData | `dateKey` lexicographic sort = chronological order; no date arithmetic needed for streak counting |
| Notification scheduling | Custom notification queue | `SystemNotificationScheduler` in `EchoEngine.swift` + `UNCalendarNotificationTrigger` | Already handles the UNNotificationRequest + error logging pattern; reuse, don't duplicate |
| Pattern natural-language generation | Template string interpolation | `EchoAIService.summarize(prompt:)` with narrow prompt | Template strings for Chinese produce stilted output; AI generates natural phrasing from consistent input |
| Data-sufficiency tracking | New SwiftData entity | `context.fetchCount(FetchDescriptor<DailySummaryEntity>())` | Zero-cost count query on existing entity; no new storage |
| AI pattern insight persistence | Custom SwiftData entity | `EchoMessageManager.generateMessage(type: .dailyInsight, ...)` | Already stores thread + inbox entry atomically; reuse exactly |

**Key insight:** Every new component this phase introduces should be thin glue between existing infrastructure. `PatternDetectionEngine` is ~120 lines of pure Swift with no dependencies. `EchoScheduler` gains one method. `EchoPromptBuilder` gains one prompt builder. The UI renders what's already in `EchoMessageEntity`.

---

## Common Pitfalls

### Pitfall 1: SwiftData `#Predicate` Date-Capture Bug
**What goes wrong:** Capturing a `Date` variable inside `#Predicate { $0.date >= cutoffDate }` sometimes fails at runtime with a SwiftData predicate conversion crash.
**Why it happens:** SwiftData's `#Predicate` macro has known limitations with `Date` type captures in certain iOS versions. The issue is not consistently reproduced but has been reported since iOS 17.
**How to avoid:** Use the `dateKey: String` property for all date-range queries. The project already uses this pattern in `BackgroundTaskManager.persistTimeline`, `EchoPromptBuilder.loadRecentTimelineSummaries`, and `EchoScheduler.loadTodayTimelineSummary`. Keep the pattern consistent.
**Warning signs:** A `fatalError` or empty results from a `DayTimelineEntity` fetch that should return records.

### Pitfall 2: Notification Permission Race Condition
**What goes wrong:** `requestNotificationPermission()` is called, permission is denied or not yet determined, and then `scheduleEchoNotification()` is called immediately — silently fails.
**Why it happens:** Authorization is async; the completion handler fires on an arbitrary thread.
**How to avoid:** Check `UNUserNotificationCenter.current().notificationSettings()` before scheduling. If `.notDetermined`, request permission first using `async/await` (`requestAuthorization(options:)` has an async variant in iOS 17+). If `.denied`, skip notification silently — the Echo inbox message is still created.
**Warning signs:** Notification never arrives in simulator testing; no error logged either.

### Pitfall 3: Streak False Positives from Short Data Windows
**What goes wrong:** User has 5 days of data; engine detects "3 days in a row at Starbucks"; this looks like a meaningful pattern but is actually noise.
**Why it happens:** Consecutive occurrence over a short window is not a habit — it could be a project deadline week or a single event's aftermath.
**How to avoid:** Two guards: (1) minimum 21 days of `DailySummaryEntity` for the data-sufficiency gate; (2) minimum streak length of 3 days within that window. Don't lower either threshold. The user-facing promise is that the insight feels true — false positives destroy trust permanently.
**Warning signs:** Insights reference events from a single week repeatedly.

### Pitfall 4: AI Prompt Drift to Prescriptive Tone
**What goes wrong:** AI response begins with "你应该..." or "建议你..." despite the prompt prohibition.
**Why it happens:** The model's RLHF training biases toward advice-giving. Without explicit format instruction, it will often frame observations as suggestions.
**How to avoid:** The `buildPatternInsightPrompt` must include explicit negative instruction: "只描述规律，不评价，不建议". Additionally, implement a post-processing tone guard (already used in Phase 1 for daily summaries) that checks for prescriptive keywords before persisting the insight.
**Warning signs:** Insight text contains "建议", "应该", "需要", "可以考虑", "尝试".

### Pitfall 5: Pattern Insight Noise from `quietTime` Events at "未知地点"
**What goes wrong:** The engine detects "you've been at 未知地点 3 afternoons in a row" — factually true but meaningless to the user.
**Why it happens:** `inferLocationStays` in `PhoneInferenceEngine` uses "未知地点" as fallback when no `KnownPlace` matches. These events are plentiful.
**How to avoid:** Filter out events where `displayName` is "未知地点", "离开了手机", or other inference-engine fallback strings before running streak detection. Only detect patterns on events with a resolved, human-readable place name.
**Warning signs:** Pattern insight text references "未知地点" or generic activity labels.

### Pitfall 6: Duplicate Pattern Insights on Same Day
**What goes wrong:** `onAppBackground` fires multiple times in one evening session (each time the user backgrounds the app); each call generates a new pattern insight and schedules another notification.
**Why it happens:** `scenePhase` → `.background` fires on every app background event, including brief interruptions (phone call, Notification Center peek).
**How to avoid:** Use the same idempotency key pattern as `EchoScheduler.lastDailySummaryKey`: store `today.echo.lastPatternInsightDate` in `UserDefaults` and return early if already run today. This exact guard is already implemented for daily summary — copy the pattern.
**Warning signs:** Multiple Echo inbox entries with identical content on the same day.

---

## Code Examples

### Verified Pattern: SwiftData Date-Range Query via String Key
```swift
// Source: Existing pattern in EchoPromptBuilder.loadRecentTimelineSummaries(days:)
// Verified by reading the live codebase

func fetchRecentTimelines(context: ModelContext, lookbackDays: Int) -> [DayTimelineEntity] {
    let calendar = Calendar.current
    let cutoff = calendar.date(byAdding: .day, value: -lookbackDays, to: Date())!
    let cutoffKey = DayTimelineEntity.dateKey(for: cutoff)  // "yyyy-MM-dd"
    var descriptor = FetchDescriptor<DayTimelineEntity>(
        predicate: #Predicate { $0.dateKey >= cutoffKey },
        sortBy: [SortDescriptor(\.dateKey, order: .forward)]
    )
    return (try? context.fetch(descriptor)) ?? []
}
```

### Verified Pattern: Count-Only SwiftData Query
```swift
// Source: BackgroundTaskManager.hasPersistedTimeline(for:) — existing codebase pattern

var descriptor = FetchDescriptor<DailySummaryEntity>()
// No predicate, no sort — just count all records
let count = (try? context.fetchCount(descriptor)) ?? 0
return count >= 21
```

### Verified Pattern: Notification Scheduling (existing infrastructure)
```swift
// Source: EchoEngine.swift — SystemNotificationScheduler.scheduleEchoNotification

// Pattern already in use for ShutterRecord echoes.
// For pattern insights, reuse the same SystemNotificationScheduler instance.
// Key difference: trigger date is computed from dailySummaryHour on the current calendar day.

let notificationID = "echo.pattern.\(dateKey)"  // idempotent key
notificationScheduler.scheduleEchoNotification(
    identifier: notificationID,
    title: "Echo",
    body: insightText,
    triggerDate: triggerDate  // today at dailySummaryHour + 5 min
)
```

### Verified Pattern: Notification Permission Check (async/await)
```swift
// Source: Apple official docs — UNUserNotificationCenter.notificationSettings() async variant
// Confidence: HIGH — verified against official Apple developer documentation

let settings = await UNUserNotificationCenter.current().notificationSettings()
switch settings.authorizationStatus {
case .authorized, .provisional:
    // schedule notification
    schedulePatternNotification(...)
case .notDetermined:
    let granted = try await UNUserNotificationCenter.current()
        .requestAuthorization(options: [.alert, .sound])
    if granted { schedulePatternNotification(...) }
case .denied:
    break  // silent — inbox message still created
default:
    break
}
```

### Verified Pattern: Consecutive-Day Streak Count
```swift
// Algorithm: sort dateKey strings (ISO lexicographic == chronological),
// then walk the list checking each consecutive pair for a 1-day gap.

func longestStreak(dateKeys: [String], calendar: Calendar) -> (length: Int, recent: [String]) {
    let sorted = dateKeys.sorted()
    guard !sorted.isEmpty else { return (0, []) }

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")

    var currentStreak = [sorted[0]]
    var bestStreak = currentStreak

    for i in 1..<sorted.count {
        guard let prev = formatter.date(from: sorted[i-1]),
              let curr = formatter.date(from: sorted[i]) else { continue }
        let diff = calendar.dateComponents([.day], from: prev, to: curr).day ?? 0
        if diff == 1 {
            currentStreak.append(sorted[i])
        } else {
            if currentStreak.count > bestStreak.count { bestStreak = currentStreak }
            currentStreak = [sorted[i]]
        }
    }
    if currentStreak.count > bestStreak.count { bestStreak = currentStreak }
    return (bestStreak.count, bestStreak)
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| BGTask as primary timeline generation | Foreground refresh primary + BGTask supplement | STATE.md decision | Pattern detection should also run on foreground (app open at 8PM) not just background |
| DeepSeek provider | Claude via AIProxy (Phase 1 goal) | Phase 1 roadmap | Pattern prompt goes to Claude; same `EchoAIService.summarize(prompt:)` call |
| One notification type (shutter echo) | Multiple notification channels (shutter + daily summary + pattern insight) | Phase 4 | Notification identifier namespacing matters more; `echo.pattern.*` prefix is new |

**Deprecated/outdated:**
- `EchoEngine.evaluateAndPushIfNeeded()` is the existing elastic echo system for shutter records — do NOT route behavioral pattern notifications through this function. It uses a relevance scorer for memory-surface notifications. Behavioral patterns are a different signal and should use their own scheduler path.

---

## Open Questions

1. **What is the minimum meaningful streak length?**
   - What we know: REQUIREMENTS.md says "3+ weeks" of data (21 days minimum). The example in AIP-01 is "连续3天" (3 consecutive days).
   - What's unclear: Should the minimum streak be 3, 4, or 5 days? 3 might produce noise; 5 might never trigger.
   - Recommendation: Ship with `minimumStreakDays = 3` and `minimumDataDays = 21`. These are constants in `PatternDetectionEngine` that can be tuned after real-user data is available.

2. **Which event kinds are pattern-worthy?**
   - What we know: Location stays (`quietTime` with resolved place name) and workouts (`workout`) are the clearest behavioral signals. Sleep is consistent but boring. Commute is too noisy.
   - What's unclear: Should we detect workout-frequency patterns ("you've run 3 mornings this week") in addition to location patterns?
   - Recommendation: Phase 4 scope is location-stay patterns only (`kind == .quietTime`, `displayName != "未知地点"`). Workout frequency patterns are a natural extension but add complexity. Keep scope tight.

3. **What happens when no meaningful pattern is found?**
   - What we know: AIP-02 requires "no insight shown when data is insufficient" but doesn't explicitly address the case where data is sufficient but no pattern is detected.
   - What's unclear: Should we skip the notification entirely, or send a generic daily summary reminder?
   - Recommendation: If `PatternDetectionEngine.detectBestPattern()` returns `nil`, skip both the notification and the inbox message creation for that day. Never send a generic push. One high-quality insight per day >> one push every day.

4. **How is the pattern insight surfaced on TodayScreen vs. Echo inbox?**
   - What we know: The pattern insight is created as an `EchoMessageEntity(type: .dailyInsight, ...)`. `TodayScreen` already reads `aiDailySummary: DailySummaryEntity?` from `TodayViewModel`. These are separate data paths.
   - What's unclear: Should pattern insight appear on TodayScreen separately, or only in the Echo inbox?
   - Recommendation: AIP-02 says "surfaced as insights in the today screen." The cleanest path: `TodayViewModel` checks `EchoMessageManager.allMessages` for the most recent unread `.dailyInsight` message and shows a preview card. This reuses the message infrastructure without adding a new persisted type. This is a planner decision, not a research gap.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| UserNotifications framework | AIP-03 push notification | Built-in iOS | iOS 17+ | In-app Echo inbox only |
| SwiftData | AIP-01 multi-day query | Built-in iOS | iOS 17+ | — (required) |
| EchoAIService | Pattern natural-language generation | In-project | Current | Skip AI formatting, use template string |
| Notification permission (user-granted) | AIP-03 | Runtime — varies | — | Echo inbox message created regardless; push is amplification only |

**Missing dependencies with no fallback:** None — all required frameworks are built into iOS 17+.

**Missing dependencies with fallback:** Notification permission — if denied, pattern insight still appears in Echo inbox. This is the design intent (in-app is primary surface, push is secondary).

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (built-in) |
| Config file | Xcode scheme `ToDay` — no separate config file |
| Quick run command | `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/PatternDetectionEngineTests` |
| Full suite command | `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AIP-01 | `PatternDetectionEngine` detects streak of 3+ days at same place+timeslot | unit | `xcodebuild test ... -only-testing:ToDayTests/PatternDetectionEngineTests` | ❌ Wave 0 |
| AIP-01 | Engine returns nil when no streak meets minimum threshold | unit | same | ❌ Wave 0 |
| AIP-01 | Engine filters out "未知地点" and generic fallback display names | unit | same | ❌ Wave 0 |
| AIP-02 | `hasSufficientData()` returns false when < 21 days exist | unit | `xcodebuild test ... -only-testing:ToDayTests/PatternDetectionEngineTests` | ❌ Wave 0 |
| AIP-02 | `hasSufficientData()` returns true when >= 21 days exist | unit | same | ❌ Wave 0 |
| AIP-03 | `EchoScheduler.onPatternCheck()` does not run twice on same day | unit | `xcodebuild test ... -only-testing:ToDayTests/EchoSchedulerTests` | partial (file exists, needs new test) |
| AIP-03 | Notification not scheduled when auth status is `.denied` | unit | `xcodebuild test ... -only-testing:ToDayTests/EchoSchedulerTests` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** Run `PatternDetectionEngineTests` only (< 5 seconds)
- **Per wave merge:** Full suite — 180+ tests must pass
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `ToDayTests/PatternDetectionEngineTests.swift` — covers AIP-01 streak detection, data sufficiency, display name filtering
- [ ] `PatternDetectionEngine.swift` itself (production code) — created in first plan task

Note: `EchoSchedulerTests.swift` already exists. It needs new test cases for `onPatternCheck()` idempotency and notification-skip-when-denied behavior. This is an extension, not a new file.

---

## Sources

### Primary (HIGH confidence)
- Existing codebase read directly — `ios/ToDay/ToDay/Data/AI/EchoScheduler.swift`, `EchoEngine.swift`, `EchoPromptBuilder.swift`, `DayTimelineEntity.swift`, `EchoMemoryEntities.swift`, `BackgroundTaskManager.swift`, `AppContainer.swift`, `ToDayApp.swift` — all architectural patterns verified against live code
- REQUIREMENTS.md — AIP-01, AIP-02, AIP-03 requirements read verbatim; 21-day threshold from AIP-02 ("3+ weeks")
- STATE.md — data-gate blocker documented; Phase 4 cannot ship until 3+ weeks of real user data accumulates
- CLAUDE.md — tech stack constraints, naming conventions, privacy rules verified

### Secondary (MEDIUM confidence)
- Apple FetchDescriptor documentation — https://developer.apple.com/documentation/swiftdata/fetchdescriptor — `fetchCount` API and `#Predicate` usage patterns
- Apple UNUserNotificationCenter documentation — https://developer.apple.com/documentation/usernotifications/unusernotificationcenter — authorization status check patterns
- Hacking with Swift SwiftData predicates guide — https://www.hackingwithswift.com/quick-start/swiftdata/how-to-filter-swiftdata-results-with-predicates — date value capture pattern in `#Predicate`
- Donnywals.com daily notification scheduling — https://www.donnywals.com/scheduling-daily-notifications-on-ios-using-calendar-and-datecomponents/ — `UNCalendarNotificationTrigger` with `DateComponents` for once-per-day scheduling
- iOS 64 pending notification limit — https://copyprogramming.com/howto/is-the-ios-local-notification-limit-per-day — verified against Apple dev forums

### Tertiary (LOW confidence)
- Minimum streak length recommendation (3 days) — derived from REQUIREMENTS.md example and general UX heuristic; no user testing data exists for this specific app

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries are built-in iOS 17+; patterns verified against live codebase
- Architecture: HIGH — `PatternDetectionEngine` design directly mirrors existing `PhoneInferenceEngine` and `EchoScheduler` patterns; no new abstractions invented
- Pitfalls: HIGH — Pitfalls 1, 4, 5, 6 verified from reading existing code patterns and project history in STATE.md; Pitfall 2 and 3 from Apple documentation and general iOS engineering knowledge
- Prompt engineering: MEDIUM — pattern prompt structure is new; tone guard and output constraints are adapted from existing `EchoDailySummaryGenerator` patterns; actual output quality requires real-device validation

**Research date:** 2026-04-04
**Valid until:** 2026-06-01 (SwiftData and UserNotifications APIs are stable; no deprecations expected in current iOS release cycle)
