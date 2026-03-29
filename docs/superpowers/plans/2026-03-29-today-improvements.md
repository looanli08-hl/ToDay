# ToDay v0.5.0 Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 8 user-reported issues: auto-record onboarding, retroactive sensor query, real-time status, elastic echo push, conversation rename, custom moods, button styling, and auto-record toggle.

**Architecture:** Incremental improvements to existing phone-first architecture. New SwiftData entity for custom moods. Elastic echo replaces fixed-interval scheduling. Retroactive query leverages iOS 7-day sensor history.

**Tech Stack:** SwiftUI, SwiftData, CoreMotion, CoreLocation, UNUserNotificationCenter

**Design Spec:** Approved in conversation 2026-03-29

---

## File Structure

### New Files

```
ToDay/Data/Sensors/CurrentActivityProvider.swift  — Real-time activity status from latest sensor data
ToDay/Data/CustomMoodEntity.swift                 — SwiftData entity for user-defined moods
ToDay/Data/EchoRelevanceScorer.swift              — Scores shutter records for elastic echo push
ToDay/Features/Onboarding/SmartRecordingPage.swift — Onboarding page for enabling auto-record
ToDayTests/EchoRelevanceScorerTests.swift
ToDayTests/CurrentActivityProviderTests.swift
ToDayTests/CustomMoodEntityTests.swift
```

### Modified Files

```
ToDay/Features/Onboarding/OnboardingView.swift    — Add smart recording step
ToDay/Features/History/HistoryScreen.swift         — Show real-time activity status
ToDay/Features/Settings/SettingsView.swift         — Add auto-record toggle
ToDay/Features/Today/QuickRecordSheet.swift        — Custom moods + button styling
ToDay/Features/Echo/EchoMessageListView.swift      — Add rename context menu
ToDay/Data/EchoMessageEntity.swift                 — Add customTitle field
ToDay/Data/EchoEngine.swift                        — Replace fixed scheduling with elastic push
ToDay/Data/Sensors/PhoneTimelineDataProvider.swift  — Add retroactive query
ToDay/Data/BackgroundTaskManager.swift             — Respect auto-record toggle
ToDay/Shared/MoodRecord.swift                      — Support custom mood identifiers
ToDay/App/AppContainer.swift                       — Wire new providers
```

---

## Task 1: Auto-Record Toggle + Settings

**Files:**
- Modify: `ToDay/Features/Settings/SettingsView.swift`
- Modify: `ToDay/Data/BackgroundTaskManager.swift`

- [ ] **Step 1: Add auto-record toggle to SettingsView**

Add a new section above "Echo 回响" in `SettingsView.swift`:

```swift
// MARK: - 智能记录
Section {
    Toggle("智能记录", isOn: Binding(
        get: { UserDefaults.standard.bool(forKey: "today.smartRecording.enabled") },
        set: { newValue in
            UserDefaults.standard.set(newValue, forKey: "today.smartRecording.enabled")
            NotificationCenter.default.post(name: .smartRecordingToggled, object: nil)
        }
    ))
} header: {
    Text("智能记录")
} footer: {
    Text("开启后，ToDay 会在后台自动感知你的运动、位置和作息，生成每日时间线。")
}
```

Add notification name extension somewhere accessible (e.g. bottom of SettingsView or a shared file):

```swift
extension Notification.Name {
    static let smartRecordingToggled = Notification.Name("today.smartRecordingToggled")
}
```

- [ ] **Step 2: Guard BackgroundTaskManager with toggle**

In `BackgroundTaskManager.swift`, add a check at the top of `generateTodayTimeline()` and `backfillRecentTimelines()`:

```swift
guard UserDefaults.standard.bool(forKey: "today.smartRecording.enabled") else { return }
```

- [ ] **Step 3: Set default value to true**

In `ToDayApp.swift` or `AppContainer.swift` init, register default:

```swift
UserDefaults.standard.register(defaults: ["today.smartRecording.enabled": true])
```

- [ ] **Step 4: Build and verify**

```bash
cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add smart recording toggle in settings"
```

---

## Task 2: Smart Recording Onboarding Page

**Files:**
- Create: `ToDay/Features/Onboarding/SmartRecordingPage.swift`
- Modify: `ToDay/Features/Onboarding/OnboardingView.swift`

- [ ] **Step 1: Create SmartRecordingPage**

```swift
import SwiftUI

struct SmartRecordingPage: View {
    let onEnable: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 0.95, green: 0.45, blue: 0.35), Color(red: 0.98, green: 0.60, blue: 0.38)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 12) {
                Text("开启智能记录")
                    .font(.system(size: 28, weight: .bold))

                Text("ToDay 会在后台安静记录你的一天——\n运动、出行、作息，都会自动出现在时间线上。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            VStack(spacing: 8) {
                featureRow(icon: "figure.walk", text: "自动识别步行、跑步、骑行")
                featureRow(icon: "location.fill", text: "记录到访地点和停留时间")
                featureRow(icon: "moon.fill", text: "推断睡眠和作息规律")
                featureRow(icon: "lock.shield.fill", text: "所有数据仅存储在你的设备上")
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 12) {
                Button(action: onEnable) {
                    Text("开启智能记录")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.95, green: 0.45, blue: 0.35), Color(red: 0.98, green: 0.60, blue: 0.38)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Button("稍后再说", action: onSkip)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .background(AppColor.background)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(AppColor.labelSecondary)
                .frame(width: 28)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(AppColor.label)
            Spacer()
        }
    }
}
```

- [ ] **Step 2: Wire into OnboardingView**

Add the SmartRecordingPage as the final step in the onboarding flow. After the user taps "开启智能记录", set the UserDefaults flag and request CoreMotion + Location permissions, then call the completion handler.

- [ ] **Step 3: Build and verify**

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: add smart recording onboarding page"
```

---

## Task 3: Retroactive Sensor Query

**Files:**
- Modify: `ToDay/Data/Sensors/PhoneTimelineDataProvider.swift`

- [ ] **Step 1: Add retroactive collection method**

Add a new method to `PhoneTimelineDataProvider`:

```swift
/// Retroactively queries CoreMotion and Pedometer for historical data.
/// iOS stores ~7 days of motion/pedometer data natively.
/// This ensures the timeline is populated even if background tasks didn't run.
private func retroactiveCollect(for date: Date) async throws -> [SensorReading] {
    var readings: [SensorReading] = []
    // Only use collectors that support retroactive queries (motion + pedometer)
    // Location and DeviceState are real-time only
    for collector in collectors {
        guard collector.isAvailable else { continue }
        let type = collector.sensorType
        guard type == .motion || type == .pedometer || type == .healthKit else { continue }
        do {
            let data = try await collector.collectData(for: date)
            readings.append(contentsOf: data)
        } catch {
            print("[PhoneTimelineDataProvider] Retroactive \(type) failed: \(error)")
        }
    }
    return readings
}
```

- [ ] **Step 2: Call retroactive collect in loadTimeline when data is sparse**

In `loadTimeline(for:)`, after step 3 (retrieve stored data), check if readings are sparse and supplement:

```swift
// 3b. If stored data is sparse, retroactively query sensors
if allReadings.filter({ $0.sensorType == .motion }).isEmpty {
    let retroReadings = try await retroactiveCollect(for: date)
    if !retroReadings.isEmpty {
        try await MainActor.run { try store.save(retroReadings) }
        allReadings = try await MainActor.run { try store.readings(for: date) }
    }
}
```

- [ ] **Step 3: Build and verify**

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: retroactive sensor query fills sparse timelines"
```

---

## Task 4: Real-Time Activity Status

**Files:**
- Create: `ToDay/Data/Sensors/CurrentActivityProvider.swift`
- Modify: `ToDay/Features/History/HistoryScreen.swift`

- [ ] **Step 1: Create CurrentActivityProvider**

```swift
import CoreMotion
import Foundation

/// Provides a human-readable description of the user's current activity
/// by querying the most recent sensor readings.
final class CurrentActivityProvider: ObservableObject {
    @Published var statusText: String = ""
    @Published var statusIcon: String = "circle.fill"

    private let activityManager = CMMotionActivityManager()
    private let pedometer = CMPedometer()

    func refresh() {
        guard CMMotionActivityManager.isActivityAvailable() else {
            statusText = "传感器不可用"
            return
        }

        let now = Date()
        let fiveMinAgo = now.addingTimeInterval(-300)

        activityManager.queryActivityStarting(from: fiveMinAgo, to: now, to: .main) { [weak self] activities, _ in
            guard let self, let last = activities?.last else { return }

            // Query current step count for today
            let startOfDay = Calendar.current.startOfDay(for: now)
            self.pedometer.queryPedometerData(from: startOfDay, to: now) { data, _ in
                let steps = data?.numberOfSteps.intValue ?? 0
                DispatchQueue.main.async {
                    self.updateStatus(activity: last, todaySteps: steps)
                }
            }
        }
    }

    private func updateStatus(activity: CMMotionActivity, todaySteps: Int) {
        let stepsText = todaySteps > 0 ? " \u{00b7} 今日 \(todaySteps) 步" : ""

        if activity.running {
            statusIcon = "figure.run"
            statusText = "正在跑步" + stepsText
        } else if activity.cycling {
            statusIcon = "figure.outdoor.cycle"
            statusText = "正在骑行"
        } else if activity.automotive {
            statusIcon = "car.fill"
            statusText = "正在出行"
        } else if activity.walking {
            statusIcon = "figure.walk"
            statusText = "正在步行" + stepsText
        } else if activity.stationary {
            statusIcon = "circle.fill"
            statusText = todaySteps > 0 ? "静止中 \u{00b7} 今日 \(todaySteps) 步" : "静止中"
        } else {
            statusIcon = "circle.fill"
            statusText = todaySteps > 0 ? "今日 \(todaySteps) 步" : ""
        }
    }
}
```

- [ ] **Step 2: Wire into HistoryScreen**

In `HistoryScreen.swift`, add `@StateObject private var activityProvider = CurrentActivityProvider()`.

Below the "正在记录" status bar, add a line showing `activityProvider.statusText`:

```swift
if !activityProvider.statusText.isEmpty {
    HStack(spacing: 6) {
        Image(systemName: activityProvider.statusIcon)
            .font(.caption2)
            .foregroundStyle(AppColor.labelTertiary)
        Text(activityProvider.statusText)
            .font(.caption)
            .foregroundStyle(AppColor.labelSecondary)
    }
}
```

Call `activityProvider.refresh()` in `.task` and on a 30-second timer.

- [ ] **Step 3: Build and verify**

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: show real-time activity status on home screen"
```

---

## Task 5: Echo Conversation Rename

**Files:**
- Modify: `ToDay/Data/EchoMessageEntity.swift`
- Modify: `ToDay/Features/Echo/EchoMessageListView.swift`

- [ ] **Step 1: Add customTitle to EchoMessageEntity**

In `EchoMessageEntity.swift`, add:

```swift
var customTitle: String?
```

Add a computed display title:

```swift
var displayTitle: String {
    customTitle ?? messageType.defaultTitle
}
```

- [ ] **Step 2: Add rename context menu to EchoMessageListView**

In the message row's existing `.contextMenu` (or add one), add a rename button:

```swift
.contextMenu {
    Button {
        renamingMessage = message
        renameText = message.displayTitle
        showRenameAlert = true
    } label: {
        Label("重命名", systemImage: "pencil")
    }

    Button(role: .destructive) {
        messageManager.delete(message)
    } label: {
        Label("删除", systemImage: "trash")
    }
}
```

Add state variables and an alert:

```swift
@State private var renamingMessage: EchoMessageEntity?
@State private var renameText = ""
@State private var showRenameAlert = false
```

```swift
.alert("重命名对话", isPresented: $showRenameAlert) {
    TextField("对话名称", text: $renameText)
    Button("保存") {
        if let msg = renamingMessage {
            msg.customTitle = renameText.isEmpty ? nil : renameText
            try? modelContext.save()
        }
    }
    Button("取消", role: .cancel) {}
}
```

- [ ] **Step 3: Update row display to use displayTitle**

Replace references to `message.title` with `message.displayTitle` in the list row.

- [ ] **Step 4: Build and verify**

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: echo conversation rename via context menu"
```

---

## Task 6: Custom Mood Panel

**Files:**
- Create: `ToDay/Data/CustomMoodEntity.swift`
- Modify: `ToDay/Features/Today/QuickRecordSheet.swift`
- Modify: `ToDay/Shared/MoodRecord.swift`
- Modify: `ToDay/App/AppContainer.swift`

- [ ] **Step 1: Create CustomMoodEntity**

```swift
import Foundation
import SwiftData

@Model
final class CustomMoodEntity {
    var id: UUID
    var emoji: String
    var name: String
    var sortOrder: Int
    var createdAt: Date

    init(id: UUID = UUID(), emoji: String, name: String, sortOrder: Int, createdAt: Date = Date()) {
        self.id = id
        self.emoji = emoji
        self.name = name
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}
```

Register `CustomMoodEntity.self` in `AppContainer.makeModelContainer()`.

- [ ] **Step 2: Add default mood seeding**

Create a static method to seed the default 6 moods:

```swift
extension CustomMoodEntity {
    static let defaults: [(emoji: String, name: String)] = [
        ("😊", "开心"),
        ("🌿", "平静"),
        ("🎯", "专注"),
        ("😴", "疲惫"),
        ("😔", "难过"),
        ("☺️", "满足"),
    ]

    @MainActor
    static func seedDefaultsIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<CustomMoodEntity>(sortBy: [SortDescriptor(\.sortOrder)])
        guard let existing = try? context.fetch(descriptor), existing.isEmpty else { return }
        for (index, mood) in defaults.enumerated() {
            context.insert(CustomMoodEntity(emoji: mood.emoji, name: mood.name, sortOrder: index))
        }
        try? context.save()
    }
}
```

Call from `AppContainer` after creating the model container.

- [ ] **Step 3: Refactor QuickRecordSheet to use custom moods**

Replace `MoodRecord.Mood.allCases` grid with a query for `CustomMoodEntity`:

```swift
@Query(sort: \CustomMoodEntity.sortOrder) private var customMoods: [CustomMoodEntity]
```

The mood grid renders from `customMoods` instead of the enum. When user selects a mood, create a `MoodRecord` with the custom mood's name as the raw value.

Add edit mode with:
- Long press to enter edit mode (delete badges on each mood)
- "+" card at the end to add new mood
- Add mood sheet: emoji text field + name text field

- [ ] **Step 4: Update MoodRecord.Mood to support custom values**

Add a `custom` case to handle user-defined moods that don't match the enum:

```swift
case custom(name: String, emoji: String)
```

Or simpler: change `MoodRecord` to store mood as a plain string + emoji string pair instead of the enum, with backwards compatibility.

- [ ] **Step 5: Build and verify**

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: custom mood panel with 6 defaults and user editing"
```

---

## Task 7: Button Styling (打点/记录一段)

**Files:**
- Modify: `ToDay/Features/Today/QuickRecordSheet.swift`

- [ ] **Step 1: Update button styles**

Replace the current flat buttons with styled versions:

"打点" (secondary): light border style
```swift
Button { /* ... */ } label: {
    Text("打点")
        .font(.headline)
        .foregroundStyle(AppColor.label)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColor.labelQuaternary, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
}
```

"开始一段" (primary): gradient fill matching app's orange theme
```swift
Button { /* ... */ } label: {
    Text("开始一段")
        .font(.headline)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.45, blue: 0.35), Color(red: 0.98, green: 0.60, blue: 0.38)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color(red: 0.95, green: 0.45, blue: 0.35).opacity(0.25), radius: 8, x: 0, y: 3)
}
```

- [ ] **Step 2: Build and verify**

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: upgrade mood button styling with gradient primary action"
```

---

## Task 8: Elastic Echo Push

**Files:**
- Create: `ToDay/Data/EchoRelevanceScorer.swift`
- Modify: `ToDay/Data/EchoEngine.swift`

- [ ] **Step 1: Create EchoRelevanceScorer**

```swift
import CoreLocation
import Foundation

/// Scores historical shutter records for echo relevance based on context.
struct EchoRelevanceScorer {

    struct ScoredRecord {
        let recordId: UUID
        let title: String
        let score: Double
    }

    /// Threshold values per frequency setting.
    static func threshold(for frequency: EchoFrequency) -> Double {
        switch frequency {
        case .high:   return 0.3
        case .medium: return 0.5
        case .low:    return 0.7
        case .off:    return Double.infinity
        }
    }

    /// Minimum interval between pushes per frequency setting.
    static func minInterval(for frequency: EchoFrequency) -> TimeInterval {
        switch frequency {
        case .high:   return 15 * 60      // 15 min
        case .medium: return 60 * 60      // 1 hour
        case .low:    return 4 * 3600     // 4 hours
        case .off:    return .infinity
        }
    }

    /// Score a shutter record against the current context.
    func score(
        recordDate: Date,
        recordNote: String,
        now: Date,
        currentLocation: CLLocation?,
        recordLocation: CLLocation?
    ) -> Double {
        var total: Double = 0

        // 1. Time decay with nostalgia boost
        let daysSince = now.timeIntervalSince(recordDate) / 86400
        if daysSince < 1 {
            total += 0.1  // Too recent, low relevance
        } else if daysSince < 7 {
            total += 0.4  // Recent memory
        } else if daysSince < 30 {
            total += 0.3  // Fading
        } else if daysSince > 180 {
            total += 0.5  // Nostalgia boost for old memories
        } else {
            total += 0.2
        }

        // 2. Time-of-day resonance (same hour ±1)
        let recordHour = Calendar.current.component(.hour, from: recordDate)
        let currentHour = Calendar.current.component(.hour, from: now)
        if abs(recordHour - currentHour) <= 1 {
            total += 0.3
        }

        // 3. Location proximity
        if let current = currentLocation, let record = recordLocation {
            let distance = current.distance(from: record)
            if distance < 200 {
                total += 0.5  // Very close — strong trigger
            } else if distance < 1000 {
                total += 0.3
            } else if distance < 5000 {
                total += 0.1
            }
        }

        // 4. Day-of-week match
        let recordWeekday = Calendar.current.component(.weekday, from: recordDate)
        let currentWeekday = Calendar.current.component(.weekday, from: now)
        if recordWeekday == currentWeekday {
            total += 0.1
        }

        return min(total, 1.0)
    }
}
```

- [ ] **Step 2: Write tests for EchoRelevanceScorer**

```swift
// ToDayTests/EchoRelevanceScorerTests.swift
import XCTest
import CoreLocation
@testable import ToDay

final class EchoRelevanceScorerTests: XCTestCase {
    let scorer = EchoRelevanceScorer()

    func testRecentRecordHasLowScore() {
        let now = Date()
        let recent = now.addingTimeInterval(-3600) // 1 hour ago
        let score = scorer.score(recordDate: recent, recordNote: "", now: now,
                                  currentLocation: nil, recordLocation: nil)
        XCTAssertLessThan(score, 0.3)
    }

    func testOldRecordGetsNostalgiaBoost() {
        let now = Date()
        let old = now.addingTimeInterval(-200 * 86400) // 200 days ago
        let score = scorer.score(recordDate: old, recordNote: "", now: now,
                                  currentLocation: nil, recordLocation: nil)
        XCTAssertGreaterThan(score, 0.4)
    }

    func testNearbyLocationBoostsScore() {
        let now = Date()
        let weekAgo = now.addingTimeInterval(-7 * 86400)
        let loc = CLLocation(latitude: 39.9, longitude: 116.4)
        let nearby = CLLocation(latitude: 39.9001, longitude: 116.4001)
        let score = scorer.score(recordDate: weekAgo, recordNote: "", now: now,
                                  currentLocation: loc, recordLocation: nearby)
        XCTAssertGreaterThan(score, 0.7)
    }

    func testThresholdsDecreaseWithHigherFrequency() {
        XCTAssertLessThan(
            EchoRelevanceScorer.threshold(for: .high),
            EchoRelevanceScorer.threshold(for: .low)
        )
    }
}
```

- [ ] **Step 3: Refactor EchoEngine scheduling**

Replace fixed-interval `scheduleEchoes(for:)` with elastic evaluation:

In `EchoEngine`, add a method `evaluateAndPushIfNeeded()` that:
1. Checks min interval since last push
2. Loads recent shutter records
3. Scores each with `EchoRelevanceScorer`
4. If any score exceeds threshold for current frequency, schedule a local notification
5. Store last push timestamp in UserDefaults

Wire this to be called on:
- App entering foreground
- Background refresh task
- Location change events (via NotificationCenter)

- [ ] **Step 4: Build and run tests**

```bash
cd ios/ToDay && xcodegen generate
xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: elastic echo push with relevance scoring"
```

---

## Execution Order

Tasks are ordered by dependency and priority:

1. **Task 1** — Auto-record toggle (foundation)
2. **Task 2** — Onboarding page (depends on toggle)
3. **Task 3** — Retroactive query (fixes empty timeline)
4. **Task 4** — Real-time status (visible improvement)
5. **Task 7** — Button styling (quick win)
6. **Task 5** — Conversation rename (quick win)
7. **Task 6** — Custom moods (medium complexity)
8. **Task 8** — Elastic echo push (most complex)

Tasks 1-4 should be done sequentially. Tasks 5, 6, 7 can be parallelized.
