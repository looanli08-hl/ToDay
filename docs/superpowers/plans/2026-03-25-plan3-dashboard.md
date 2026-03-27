# Plan 3: Dashboard (仪表盘首页)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Dashboard view as the new home tab content — a card grid showing 6 life dimensions (运动/睡眠/屏幕时间/消费/步数/快门数), a trend insight section, and a timeline preview linking to the full timeline tab.

**Architecture:** Create `DashboardView` as the home tab body, `DashboardCardView` as a reusable card component, and `DashboardViewModel` to compute dashboard-specific data from the existing `DayTimeline`. The existing `TodayScreen` code stays untouched — Dashboard replaces it in `AppRootScreen`'s home tab. Data flows from `TodayViewModel.timeline` through `DashboardViewModel` computed properties.

**Tech Stack:** Swift 5, SwiftUI, XCTest

**Spec:** `docs/superpowers/specs/2026-03-25-auto-journal-evolution-design.md` (sections 6, 8)

**Prerequisite:** Plan 1 must be completed (EventKind extensions, 4-tab navigation, mock data with new event types).

---

## File Structure

### New Files

| File | Responsibility |
|------|----------------|
| `ToDay/Features/Dashboard/DashboardCardView.swift` | Reusable card component: icon + label + value + optional trend indicator |
| `ToDay/Features/Dashboard/DashboardView.swift` | Main dashboard view: date header, card grid, insight section, timeline preview |
| `ToDay/Features/Dashboard/DashboardViewModel.swift` | Computes card data, trend insights, and timeline preview from DayTimeline |
| `ToDayTests/DashboardViewModelTests.swift` | Unit tests for DashboardViewModel computed properties |

### Modified Files

| File | Changes |
|------|---------|
| `ToDay/App/AppRootScreen.swift` | Home tab switches from `TodayScreen` to `DashboardView` |
| `ToDay/Features/Today/TodayTheme.swift` | Add `purple` / `purpleSoft` / `orange` / `orangeSoft` color pairs for new card dimensions |

All paths are relative to `ios/ToDay/`.

---

## Task 1: DashboardCardView — Reusable Card Component

**Files:**
- Create: `ios/ToDay/ToDay/Features/Dashboard/DashboardCardView.swift`
- Modify: `ios/ToDay/ToDay/Features/Today/TodayTheme.swift`

- [ ] **Step 1: Add new theme colors for card dimensions**

In `ios/ToDay/ToDay/Features/Today/TodayTheme.swift`, find the line:

```swift
    static let glass = Color.white.opacity(0.18)
```

Insert the following lines immediately before it:

```swift
    static let purple = dynamicColor(light: 0x9B7BC9, dark: 0xB89BDD)
    static let purpleSoft = dynamicColor(light: 0xF0E8F9, dark: 0x2E2343)
    static let orange = dynamicColor(light: 0xD98B4A, dark: 0xE8A96B)
    static let orangeSoft = dynamicColor(light: 0xFBEEDE, dark: 0x3A2A1A)
```

- [ ] **Step 2: Create DashboardCardView.swift**

Create directory `ios/ToDay/ToDay/Features/Dashboard/` and file `DashboardCardView.swift`:

```swift
import SwiftUI

struct DashboardCardData: Identifiable {
    let id: String
    let icon: String
    let label: String
    let value: String
    let tint: Color
    let background: Color
    let trend: TrendDirection?

    init(
        id: String,
        icon: String,
        label: String,
        value: String,
        tint: Color,
        background: Color,
        trend: TrendDirection? = nil
    ) {
        self.id = id
        self.icon = icon
        self.label = label
        self.value = value
        self.tint = tint
        self.background = background
        self.trend = trend
    }
}

enum TrendDirection {
    case up
    case down
    case flat

    var iconName: String {
        switch self {
        case .up:   return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .flat: return "arrow.right"
        }
    }
}

struct DashboardCardView: View {
    let card: DashboardCardData

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: card.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(card.tint)

                Spacer()

                if let trend = card.trend {
                    Image(systemName: trend.iconName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(trendColor(trend))
                }
            }

            Spacer()

            Text(card.label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(TodayTheme.inkMuted)
                .lineLimit(1)

            Text(card.value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(TodayTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .aspectRatio(1.0, contentMode: .fit)
        .background(card.background)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(TodayTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func trendColor(_ trend: TrendDirection) -> Color {
        switch trend {
        case .up:   return TodayTheme.teal
        case .down: return TodayTheme.rose
        case .flat: return TodayTheme.inkMuted
        }
    }
}

#Preview {
    LazyVGrid(columns: [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ], spacing: 12) {
        DashboardCardView(card: DashboardCardData(
            id: "workout",
            icon: "figure.run",
            label: "运动",
            value: "46m",
            tint: TodayTheme.orange,
            background: TodayTheme.orangeSoft,
            trend: .up
        ))
        DashboardCardView(card: DashboardCardData(
            id: "sleep",
            icon: "moon.fill",
            label: "睡眠",
            value: "7h",
            tint: TodayTheme.sleepIndigo,
            background: TodayTheme.blueSoft,
            trend: .flat
        ))
        DashboardCardView(card: DashboardCardData(
            id: "steps",
            icon: "figure.walk",
            label: "步数",
            value: "8,240",
            tint: TodayTheme.walkGreen,
            background: TodayTheme.tealSoft,
            trend: .down
        ))
    }
    .padding()
}
```

- [ ] **Step 3: Build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
cd ios/ToDay && git add ToDay/Features/Dashboard/DashboardCardView.swift ToDay/Features/Today/TodayTheme.swift
git commit -m "feat: add DashboardCardView component with theme color extensions"
```

---

## Task 2: DashboardViewModel — Data Computation

**Files:**
- Create: `ios/ToDay/ToDay/Features/Dashboard/DashboardViewModel.swift`
- Create: `ios/ToDay/ToDayTests/DashboardViewModelTests.swift`

- [ ] **Step 1: Write tests for DashboardViewModel**

Create `ios/ToDay/ToDayTests/DashboardViewModelTests.swift`:

```swift
import XCTest
@testable import ToDay

final class DashboardViewModelTests: XCTestCase {
    func testCardsCountIsSixWithFullTimeline() {
        let vm = makeDashboardVM(timeline: mockTimeline())
        let cards = vm.cards
        XCTAssertEqual(cards.count, 6)
    }

    func testCardsCountIsSixWithNilTimeline() {
        let vm = makeDashboardVM(timeline: nil)
        let cards = vm.cards
        XCTAssertEqual(cards.count, 6)
    }

    func testWorkoutCardShowsExerciseMinutes() {
        let vm = makeDashboardVM(timeline: mockTimeline())
        let workoutCard = vm.cards.first { $0.id == "workout" }
        XCTAssertNotNil(workoutCard)
        XCTAssertEqual(workoutCard?.label, "运动")
        XCTAssertTrue(workoutCard?.value.contains("46") == true || workoutCard?.value.contains("分钟") == true)
    }

    func testSleepCardShowsHours() {
        let vm = makeDashboardVM(timeline: mockTimeline())
        let sleepCard = vm.cards.first { $0.id == "sleep" }
        XCTAssertNotNil(sleepCard)
        XCTAssertEqual(sleepCard?.label, "睡眠")
        // Mock timeline has 7h sleep
        XCTAssertTrue(sleepCard?.value.contains("7") == true)
    }

    func testStepCardShowsStepCount() {
        let vm = makeDashboardVM(timeline: mockTimeline())
        let stepCard = vm.cards.first { $0.id == "steps" }
        XCTAssertNotNil(stepCard)
        XCTAssertEqual(stepCard?.label, "步数")
    }

    func testScreenTimeCardShowsDuration() {
        let vm = makeDashboardVM(timeline: mockTimeline())
        let screenCard = vm.cards.first { $0.id == "screenTime" }
        XCTAssertNotNil(screenCard)
        XCTAssertEqual(screenCard?.label, "屏幕时间")
    }

    func testSpendingCardShowsTotalAmount() {
        let vm = makeDashboardVM(timeline: mockTimeline())
        let spendingCard = vm.cards.first { $0.id == "spending" }
        XCTAssertNotNil(spendingCard)
        XCTAssertEqual(spendingCard?.label, "消费")
        // Two spending events: ¥35 + ¥68 = ¥103
        XCTAssertTrue(spendingCard?.value.contains("103") == true)
    }

    func testShutterCardShowsCount() {
        let vm = makeDashboardVM(timeline: mockTimeline())
        let shutterCard = vm.cards.first { $0.id == "shutter" }
        XCTAssertNotNil(shutterCard)
        XCTAssertEqual(shutterCard?.label, "快门")
        XCTAssertTrue(shutterCard?.value.contains("2") == true)
    }

    func testTimelinePreviewReturnsLatestEvents() {
        let vm = makeDashboardVM(timeline: mockTimeline())
        let preview = vm.timelinePreview
        XCTAssertTrue(preview.count <= 5)
        // Entries should be in reverse chronological order
        if preview.count >= 2 {
            XCTAssertTrue(preview[0].startDate >= preview[1].startDate)
        }
    }

    func testTimelinePreviewEmptyWhenNilTimeline() {
        let vm = makeDashboardVM(timeline: nil)
        let preview = vm.timelinePreview
        XCTAssertTrue(preview.isEmpty)
    }

    func testNilTimelineProducesPlaceholderValues() {
        let vm = makeDashboardVM(timeline: nil)
        for card in vm.cards {
            XCTAssertEqual(card.value, "--")
        }
    }

    func testInsightTextNonEmptyWithTimeline() {
        let vm = makeDashboardVM(timeline: mockTimeline())
        XCTAssertFalse(vm.insightText.isEmpty)
    }

    // MARK: - Helpers

    private func makeDashboardVM(timeline: DayTimeline?) -> DashboardViewModel {
        DashboardViewModel(timeline: timeline)
    }

    private func mockTimeline() -> DayTimeline {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())

        func time(_ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(byAdding: .minute, value: (hour * 60) + minute, to: startOfDay) ?? startOfDay
        }

        let entries: [InferredEvent] = [
            InferredEvent(
                kind: .sleep,
                startDate: time(0, 0),
                endDate: time(7, 0),
                confidence: .high,
                displayName: "睡眠",
                associatedMetrics: EventMetrics(stepCount: nil)
            ),
            InferredEvent(
                kind: .workout,
                startDate: time(14, 0),
                endDate: time(14, 46),
                confidence: .high,
                displayName: "跑步",
                associatedMetrics: EventMetrics(
                    stepCount: 5200,
                    activeEnergy: 430,
                    distance: 6100,
                    workoutType: "跑步"
                )
            ),
            InferredEvent(
                kind: .activeWalk,
                startDate: time(7, 30),
                endDate: time(8, 0),
                confidence: .medium,
                displayName: "通勤步行",
                associatedMetrics: EventMetrics(stepCount: 3040)
            ),
            InferredEvent(
                kind: .shutter,
                startDate: time(10, 15),
                endDate: time(10, 15),
                confidence: .high,
                displayName: "路上看到一只猫，很可爱",
                subtitle: "text"
            ),
            InferredEvent(
                kind: .spending,
                startDate: time(12, 20),
                endDate: time(12, 20),
                confidence: .high,
                displayName: "餐饮 ¥35",
                subtitle: "午餐便当"
            ),
            InferredEvent(
                kind: .screenTime,
                startDate: time(13, 0),
                endDate: time(15, 30),
                confidence: .medium,
                displayName: "屏幕时间 2h 30m",
                subtitle: "主要使用：Xcode、Safari"
            ),
            InferredEvent(
                kind: .shutter,
                startDate: time(16, 0),
                endDate: time(16, 0),
                confidence: .high,
                displayName: "突然想到一个产品创意...",
                subtitle: "voice"
            ),
            InferredEvent(
                kind: .spending,
                startDate: time(18, 30),
                endDate: time(18, 30),
                confidence: .high,
                displayName: "餐饮 ¥68",
                subtitle: "晚餐"
            )
        ]

        let stats = [
            TimelineStat(title: "活动", value: "540/600 千卡"),
            TimelineStat(title: "锻炼", value: "46/30 分钟"),
            TimelineStat(title: "站立", value: "10/12 小时"),
            TimelineStat(title: "屏幕时间", value: "3h 15m"),
            TimelineStat(title: "消费", value: "¥103"),
            TimelineStat(title: "快门", value: "2 条")
        ]

        return DayTimeline(
            date: startOfDay,
            summary: "模拟完整的一天。",
            source: .mock,
            stats: stats,
            entries: entries
        )
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/DashboardViewModelTests 2>&1 | tail -20`

Expected: Compile error — `DashboardViewModel` not defined

- [ ] **Step 3: Create DashboardViewModel.swift**

Create `ios/ToDay/ToDay/Features/Dashboard/DashboardViewModel.swift`:

```swift
import Foundation
import SwiftUI

struct DashboardViewModel {
    let timeline: DayTimeline?

    // MARK: - Card Data

    var cards: [DashboardCardData] {
        [
            workoutCard,
            sleepCard,
            screenTimeCard,
            spendingCard,
            stepsCard,
            shutterCard
        ]
    }

    // MARK: - Timeline Preview

    /// Returns the last few events in reverse chronological order, capped at 5.
    var timelinePreview: [InferredEvent] {
        guard let timeline else { return [] }
        return Array(
            timeline.entries
                .sorted { $0.startDate > $1.startDate }
                .prefix(5)
        )
    }

    // MARK: - Insight Text

    var insightText: String {
        guard let timeline else {
            return "今天的数据还在路上，稍后再看看。"
        }

        var parts: [String] = []

        let workoutMinutes = totalWorkoutMinutes
        if workoutMinutes > 0 {
            parts.append("今日运动 \(workoutMinutes) 分钟")
        }

        let sleepHours = totalSleepHours
        if sleepHours > 0 {
            parts.append("睡眠 \(sleepHours) 小时")
        }

        let steps = totalSteps
        if steps > 0 {
            parts.append("步行 \(formatNumber(steps)) 步")
        }

        let spending = totalSpending
        if spending > 0 {
            parts.append("消费 ¥\(Int(spending))")
        }

        let shutters = shutterCount
        if shutters > 0 {
            parts.append("快门 \(shutters) 条")
        }

        if parts.isEmpty {
            return "今天还没有可展示的维度数据，戴上 Apple Watch 活动一下吧。"
        }

        let entryCount = timeline.entries.count
        let summaryPrefix = "已记录 \(entryCount) 个片段："
        return summaryPrefix + parts.joined(separator: "，") + "。"
    }

    // MARK: - Date Header

    var dateText: String {
        Self.dateHeaderFormatter.string(from: timeline?.date ?? Date())
    }

    // MARK: - Individual Cards

    private var workoutCard: DashboardCardData {
        let minutes = totalWorkoutMinutes
        let value = minutes > 0 ? "\(minutes) 分钟" : "--"
        return DashboardCardData(
            id: "workout",
            icon: "figure.run",
            label: "运动",
            value: value,
            tint: TodayTheme.orange,
            background: TodayTheme.orangeSoft
        )
    }

    private var sleepCard: DashboardCardData {
        let hours = totalSleepHours
        let value = hours > 0 ? "\(hours) 小时" : "--"
        return DashboardCardData(
            id: "sleep",
            icon: "moon.fill",
            label: "睡眠",
            value: value,
            tint: TodayTheme.sleepIndigo,
            background: TodayTheme.blueSoft
        )
    }

    private var screenTimeCard: DashboardCardData {
        let screenTimeStat = timeline?.stats.first { $0.title == "屏幕时间" }
        let value = screenTimeStat?.value ?? screenTimeFromEntries ?? "--"
        return DashboardCardData(
            id: "screenTime",
            icon: "iphone",
            label: "屏幕时间",
            value: value,
            tint: TodayTheme.purple,
            background: TodayTheme.purpleSoft
        )
    }

    private var spendingCard: DashboardCardData {
        let total = totalSpending
        let value = total > 0 ? "¥\(Int(total))" : "--"
        return DashboardCardData(
            id: "spending",
            icon: "yensign.circle.fill",
            label: "消费",
            value: value,
            tint: TodayTheme.rose,
            background: TodayTheme.roseSoft
        )
    }

    private var stepsCard: DashboardCardData {
        let steps = totalSteps
        let value = steps > 0 ? formatNumber(steps) : "--"
        return DashboardCardData(
            id: "steps",
            icon: "figure.walk",
            label: "步数",
            value: value,
            tint: TodayTheme.walkGreen,
            background: TodayTheme.tealSoft
        )
    }

    private var shutterCard: DashboardCardData {
        let count = shutterCount
        let value = count > 0 ? "\(count) 条" : "--"
        return DashboardCardData(
            id: "shutter",
            icon: "camera.fill",
            label: "快门",
            value: value,
            tint: TodayTheme.accent,
            background: TodayTheme.accentSoft
        )
    }

    // MARK: - Data Extraction

    private var totalWorkoutMinutes: Int {
        guard let entries = timeline?.entries else { return 0 }
        let workoutEntries = entries.filter { $0.kind == .workout }
        let totalSeconds = workoutEntries.reduce(0.0) { $0 + $1.duration }
        return Int(totalSeconds / 60)
    }

    private var totalSleepHours: Int {
        guard let entries = timeline?.entries else { return 0 }
        let sleepEntries = entries.filter { $0.kind == .sleep }
        let totalSeconds = sleepEntries.reduce(0.0) { $0 + $1.duration }
        return Int(totalSeconds / 3600)
    }

    private var totalSteps: Int {
        guard let entries = timeline?.entries else { return 0 }
        return entries.compactMap { $0.associatedMetrics?.stepCount }.reduce(0, +)
    }

    private var totalSpending: Double {
        guard let entries = timeline?.entries else { return 0 }
        let spendingEntries = entries.filter { $0.kind == .spending }
        return spendingEntries.reduce(0.0) { total, event in
            // Parse amount from displayName (format: "餐饮 ¥35")
            let name = event.displayName
            if let range = name.range(of: "¥") {
                let amountStr = name[range.upperBound...]
                    .trimmingCharacters(in: .whitespaces)
                    .components(separatedBy: CharacterSet.decimalDigits.inverted)
                    .joined()
                return total + (Double(amountStr) ?? 0)
            }
            return total
        }
    }

    private var shutterCount: Int {
        guard let entries = timeline?.entries else { return 0 }
        return entries.filter { $0.kind == .shutter }.count
    }

    private var screenTimeFromEntries: String? {
        guard let entries = timeline?.entries else { return nil }
        let screenTimeEntries = entries.filter { $0.kind == .screenTime }
        guard !screenTimeEntries.isEmpty else { return nil }
        let totalSeconds = screenTimeEntries.reduce(0.0) { $0 + $1.duration }
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    // MARK: - Formatting

    private func formatNumber(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static let dateHeaderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy · MM · dd EEE"
        return formatter
    }()
}
```

- [ ] **Step 4: Run tests — expect pass**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/DashboardViewModelTests 2>&1 | tail -20`

Expected: All 11 tests PASS

- [ ] **Step 5: Run full test suite to check no regressions**

Run: `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All existing tests still pass

- [ ] **Step 6: Commit**

```bash
cd ios/ToDay && git add ToDay/Features/Dashboard/DashboardViewModel.swift ToDayTests/DashboardViewModelTests.swift
git commit -m "feat: add DashboardViewModel with card data computation and tests"
```

---

## Task 3: DashboardView — Main Dashboard Screen

**Files:**
- Create: `ios/ToDay/ToDay/Features/Dashboard/DashboardView.swift`

- [ ] **Step 1: Create DashboardView.swift**

Create `ios/ToDay/ToDay/Features/Dashboard/DashboardView.swift`:

```swift
import SwiftUI

struct DashboardView: View {
    @ObservedObject var todayViewModel: TodayViewModel
    let onOpenTimeline: () -> Void

    private var dashboardVM: DashboardViewModel {
        DashboardViewModel(timeline: todayViewModel.timeline)
    }

    private let cardColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    cardGridSection
                    insightSection
                    timelinePreviewSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(TodayTheme.background)
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await todayViewModel.loadIfNeeded()
            }
            .refreshable {
                await todayViewModel.load(forceReload: true)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(dashboardVM.dateText)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(TodayTheme.inkMuted)
                        .tracking(1.4)

                    Text("仪表盘")
                        .font(.system(size: 33, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(TodayTheme.ink)
                }

                Spacer()

                Button {
                    Task {
                        await todayViewModel.load(forceReload: true)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(TodayTheme.inkSoft)
                        .frame(width: 42, height: 42)
                        .background(TodayTheme.card)
                        .overlay(
                            Circle()
                                .stroke(TodayTheme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            if todayViewModel.isLoading && todayViewModel.timeline == nil {
                Text("正在整理今天的数据...")
                    .font(.system(size: 14))
                    .foregroundStyle(TodayTheme.inkMuted)
            }
        }
    }

    // MARK: - Card Grid

    private var cardGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EyebrowLabel("今日概览")

            if todayViewModel.isLoading && todayViewModel.timeline == nil {
                cardGridPlaceholder
            } else {
                LazyVGrid(columns: cardColumns, spacing: 12) {
                    ForEach(dashboardVM.cards) { card in
                        DashboardCardView(card: card)
                    }
                }
            }
        }
    }

    private var cardGridPlaceholder: some View {
        LazyVGrid(columns: cardColumns, spacing: 12) {
            ForEach(0..<6, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(TodayTheme.elevatedCard)
                    .aspectRatio(1.0, contentMode: .fit)
                    .overlay(
                        ProgressView()
                    )
            }
        }
    }

    // MARK: - Insight

    @ViewBuilder
    private var insightSection: some View {
        let vm = dashboardVM
        ContentCard(background: TodayTheme.tealSoft.opacity(0.7)) {
            EyebrowLabel("今日洞察")

            Text("生活脉搏")
                .font(.system(size: 23, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(TodayTheme.ink)

            Text(vm.insightText)
                .font(.system(size: 14))
                .foregroundStyle(TodayTheme.inkMuted)
                .lineSpacing(4)
        }
    }

    // MARK: - Timeline Preview

    @ViewBuilder
    private var timelinePreviewSection: some View {
        let preview = dashboardVM.timelinePreview
        if !preview.isEmpty {
            ContentCard {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        EyebrowLabel("最近动态")

                        Text("时间线")
                            .font(.system(size: 23, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(TodayTheme.ink)
                    }

                    Spacer()

                    Button(action: onOpenTimeline) {
                        Text("查看全部")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(TodayTheme.inkSoft)
                    }
                    .buttonStyle(.plain)
                }

                VStack(spacing: 0) {
                    ForEach(Array(preview.enumerated()), id: \.element.id) { index, event in
                        TimelinePreviewRow(event: event)

                        if index < preview.count - 1 {
                            Divider()
                                .padding(.leading, 36)
                        }
                    }
                }
            }
        } else if todayViewModel.timeline != nil {
            ContentCard {
                VStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.system(size: 28))
                        .foregroundStyle(TodayTheme.inkFaint)

                    Text("时间线还是空的")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(TodayTheme.inkSoft)

                    Text("戴上 Apple Watch 活动一会儿，或用快门记录生活碎片。")
                        .font(.system(size: 14))
                        .foregroundStyle(TodayTheme.inkMuted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
    }
}

// MARK: - Timeline Preview Row

private struct TimelinePreviewRow: View {
    let event: InferredEvent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background(iconBackground)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(event.resolvedName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(TodayTheme.inkSoft)
                    .lineLimit(1)

                Text(timeText)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(TodayTheme.inkMuted)
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        let start = formatter.string(from: event.startDate)
        if event.duration < 60 {
            return start
        }
        let end = formatter.string(from: event.endDate)
        return "\(start) - \(end)"
    }

    private var iconName: String {
        switch event.kind {
        case .sleep:         return "moon.fill"
        case .workout:       return "figure.run"
        case .commute:       return "car.fill"
        case .activeWalk:    return "figure.walk"
        case .quietTime:     return "leaf.fill"
        case .userAnnotated: return "pencil"
        case .mood:          return "heart.fill"
        case .shutter:       return "camera.fill"
        case .screenTime:    return "iphone"
        case .spending:      return "yensign.circle.fill"
        }
    }

    private var iconColor: Color {
        switch event.kind {
        case .sleep:         return TodayTheme.sleepIndigo
        case .workout:       return TodayTheme.workoutOrange
        case .commute:       return TodayTheme.blue
        case .activeWalk:    return TodayTheme.walkGreen
        case .quietTime:     return TodayTheme.teal
        case .userAnnotated: return TodayTheme.accent
        case .mood:          return TodayTheme.rose
        case .shutter:       return TodayTheme.accent
        case .screenTime:    return TodayTheme.purple
        case .spending:      return TodayTheme.rose
        }
    }

    private var iconBackground: Color {
        switch event.kind {
        case .sleep:         return TodayTheme.blueSoft
        case .workout:       return TodayTheme.orangeSoft
        case .commute:       return TodayTheme.blueSoft
        case .activeWalk:    return TodayTheme.tealSoft
        case .quietTime:     return TodayTheme.tealSoft
        case .userAnnotated: return TodayTheme.accentSoft
        case .mood:          return TodayTheme.roseSoft
        case .shutter:       return TodayTheme.accentSoft
        case .screenTime:    return TodayTheme.purpleSoft
        case .spending:      return TodayTheme.roseSoft
        }
    }
}

#Preview {
    DashboardView(
        todayViewModel: TodayViewModel(
            provider: MockTimelineDataProvider(),
            recordStore: UserDefaultsMoodRecordStore(
                defaults: UserDefaults(suiteName: "DashboardPreviewStore") ?? .standard,
                key: "preview.manualRecords"
            ),
            modelContainer: previewModelContainer
        ),
        onOpenTimeline: {}
    )
}

@MainActor
private let previewModelContainer: ModelContainer = {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try! ModelContainer(for: MoodRecordEntity.self, DayTimelineEntity.self, configurations: configuration)
}()
```

- [ ] **Step 2: Add missing imports at top of file**

The preview code needs `SwiftData` and `SwiftUI`. Ensure the top of the file starts with:

```swift
import SwiftData
import SwiftUI
```

- [ ] **Step 3: Build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Run full test suite**

Run: `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
cd ios/ToDay && git add ToDay/Features/Dashboard/DashboardView.swift
git commit -m "feat: add DashboardView with card grid, insight section, and timeline preview"
```

---

## Task 4: Wire Dashboard into Home Tab

**Files:**
- Modify: `ios/ToDay/ToDay/App/AppRootScreen.swift`

- [ ] **Step 1: Replace TodayScreen with DashboardView in home tab**

In `ios/ToDay/ToDay/App/AppRootScreen.swift`, find:

```swift
                TodayScreen(
                    viewModel: todayViewModel,
                    onOpenHistory: { selectedTab = .timeline }
                )
                .tabItem {
                    Label("首页", systemImage: "square.grid.2x2.fill")
                }
                .tag(AppTab.home)
```

Replace with:

```swift
                DashboardView(
                    todayViewModel: todayViewModel,
                    onOpenTimeline: { selectedTab = .timeline }
                )
                .tabItem {
                    Label("首页", systemImage: "square.grid.2x2.fill")
                }
                .tag(AppTab.home)
```

- [ ] **Step 2: Build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Run full test suite**

Run: `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All tests pass

- [ ] **Step 4: Verify TodayScreen preview still compiles**

The `TodayScreen` file references `AppRootScreen` in its preview. Since `AppRootScreen` now uses `DashboardView`, verify it still builds. If the `TodayScreen` preview breaks, update it to use `TodayScreen` directly:

In `ios/ToDay/ToDay/Features/Today/TodayScreen.swift`, find:

```swift
#Preview {
    AppRootScreen(
        todayViewModel: TodayViewModel(
            provider: MockTimelineDataProvider(),
            recordStore: UserDefaultsMoodRecordStore(
                defaults: UserDefaults(suiteName: "ToDayPreviewStore") ?? .standard,
                key: "preview.manualRecords"
            ),
            modelContainer: previewModelContainer
        )
    )
}
```

Replace with:

```swift
#Preview {
    TodayScreen(
        viewModel: TodayViewModel(
            provider: MockTimelineDataProvider(),
            recordStore: UserDefaultsMoodRecordStore(
                defaults: UserDefaults(suiteName: "ToDayPreviewStore") ?? .standard,
                key: "preview.manualRecords"
            ),
            modelContainer: previewModelContainer
        ),
        onOpenHistory: {}
    )
}
```

- [ ] **Step 5: Build again after preview fix**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
cd ios/ToDay && git add ToDay/App/AppRootScreen.swift ToDay/Features/Today/TodayScreen.swift
git commit -m "feat: wire DashboardView as home tab, replacing TodayScreen"
```

---

## Task 5: Polish — Loading, Error, and Empty States

**Files:**
- Modify: `ios/ToDay/ToDay/Features/Dashboard/DashboardView.swift`

- [ ] **Step 1: Add error state handling to DashboardView**

In `ios/ToDay/ToDay/Features/Dashboard/DashboardView.swift`, find the `headerSection` property. After the loading text block:

```swift
            if todayViewModel.isLoading && todayViewModel.timeline == nil {
                Text("正在整理今天的数据...")
                    .font(.system(size: 14))
                    .foregroundStyle(TodayTheme.inkMuted)
            }
```

Add an error state block immediately after it (still inside the outer VStack):

```swift
            if let errorMessage = todayViewModel.errorMessage, todayViewModel.timeline == nil {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(TodayTheme.rose)

                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(TodayTheme.inkMuted)
                        .lineLimit(2)
                }
            }
```

- [ ] **Step 2: Add foreground refresh handler**

In `ios/ToDay/ToDay/Features/Dashboard/DashboardView.swift`, find the `.refreshable` modifier on the ScrollView. Add the foreground notification handler after it:

```swift
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task {
                    await todayViewModel.load(forceReload: true)
                }
            }
```

Also add the necessary import at the top of the file if not already present:

```swift
import UIKit
```

- [ ] **Step 3: Build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Run full test suite**

Run: `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
cd ios/ToDay && git add ToDay/Features/Dashboard/DashboardView.swift
git commit -m "feat: add error state, foreground refresh to DashboardView"
```

---

## Summary

After completing all 5 tasks, the codebase will have:

- **`DashboardCardView`**: Reusable card component with icon, label, value, and optional trend indicator
- **`DashboardViewModel`**: Pure data computation layer — extracts workout/sleep/screenTime/spending/steps/shutter from `DayTimeline`
- **`DashboardView`**: Full dashboard screen with date header, 3-column card grid, insight section, and timeline preview
- **Home tab wired**: `AppRootScreen` now shows `DashboardView` instead of `TodayScreen`
- **4 new theme colors**: `purple`/`purpleSoft`/`orange`/`orangeSoft` for card dimensions
- **11+ unit tests**: Covering all `DashboardViewModel` computed properties
- **`TodayScreen` preserved**: Original screen intact, still accessible for reference or future use

The existing `TodayScreen` is NOT deleted — it remains in the codebase for the timeline tab or future reuse. The dashboard cleanly replaces it as the home tab content.
