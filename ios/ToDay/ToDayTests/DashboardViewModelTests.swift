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
