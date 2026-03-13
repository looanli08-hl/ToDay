import XCTest
@testable import ToDay

final class TodayInsightComposerTests: XCTestCase {
    private var calendar: Calendar!
    private var composer: TodayInsightComposer!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60) ?? .current
        composer = TodayInsightComposer(calendar: calendar)
    }

    func testBuildTodaySummaryUsesDominantMoodAndLatestNote() {
        let referenceDate = makeDate(year: 2026, month: 3, day: 10, hour: 21, minute: 0)
        let records = [
            MoodRecord(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, mood: .focused, note: "推进会员页", createdAt: makeDate(year: 2026, month: 3, day: 10, hour: 20, minute: 40)),
            MoodRecord(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, mood: .focused, note: "", createdAt: makeDate(year: 2026, month: 3, day: 10, hour: 10, minute: 15)),
            MoodRecord(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, mood: .calm, note: "", createdAt: makeDate(year: 2026, month: 3, day: 10, hour: 8, minute: 20))
        ]

        let timeline = DayTimeline(
            date: referenceDate,
            summary: "测试时间线",
            source: .mock,
            stats: [TimelineStat(title: "模式", value: "本地")],
            entries: [
                InferredEvent(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
                    kind: .sleep,
                    startDate: makeDate(year: 2026, month: 3, day: 10, hour: 0, minute: 0),
                    endDate: makeDate(year: 2026, month: 3, day: 10, hour: 7, minute: 0),
                    confidence: .high,
                    displayName: "睡眠",
                    subtitle: "昨夜 7 小时"
                ),
                InferredEvent(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!,
                    kind: .userAnnotated,
                    startDate: makeDate(year: 2026, month: 3, day: 10, hour: 10, minute: 0),
                    endDate: makeDate(year: 2026, month: 3, day: 10, hour: 11, minute: 30),
                    confidence: .medium,
                    displayName: "专注",
                    subtitle: "上午推进"
                )
            ]
        )

        let summary = composer.buildTodaySummary(
            referenceDate: referenceDate,
            timeline: timeline,
            recordsForDay: records
        )

        XCTAssertEqual(summary.headline, "今天的主线偏向专注")
        XCTAssertTrue(summary.narrative.contains("推进会员页"))
        XCTAssertTrue(summary.badges.contains("3 条记录"))
        XCTAssertTrue(summary.badges.contains("1 条备注"))
        XCTAssertTrue(summary.badges.contains("主情绪 专注"))
        XCTAssertTrue(summary.badges.contains("2 个片段"))
    }

    func testBuildWeeklyInsightCountsActiveDaysAndStreak() {
        let referenceDate = makeDate(year: 2026, month: 3, day: 10, hour: 12, minute: 0)
        let records = [
            MoodRecord(mood: .focused, createdAt: makeDate(year: 2026, month: 3, day: 10, hour: 20, minute: 0)),
            MoodRecord(mood: .focused, createdAt: makeDate(year: 2026, month: 3, day: 9, hour: 9, minute: 0)),
            MoodRecord(mood: .happy, createdAt: makeDate(year: 2026, month: 3, day: 8, hour: 11, minute: 0)),
            MoodRecord(mood: .calm, createdAt: makeDate(year: 2026, month: 3, day: 6, hour: 14, minute: 0))
        ]

        let insight = composer.buildWeeklyInsight(referenceDate: referenceDate, manualRecords: records)

        XCTAssertEqual(insight.headline, "最近 7 天存在明显推进段")
        XCTAssertTrue(insight.narrative.contains("最近 7 天里有 4 天留下记录"))
        XCTAssertTrue(insight.narrative.contains("连续 3 天"))
        XCTAssertTrue(insight.badges.contains("4/7 活跃天"))
        XCTAssertTrue(insight.badges.contains("4 条记录"))
        XCTAssertTrue(insight.badges.contains("连续 3 天"))
        XCTAssertTrue(insight.badges.contains("主情绪 专注"))
    }

    func testBuildHistoryDetailReturnsChronologicalSpanAndRecords() {
        let targetDate = makeDate(year: 2026, month: 3, day: 10, hour: 0, minute: 0)
        let records = [
            MoodRecord(mood: .tired, note: "开会太久", createdAt: makeDate(year: 2026, month: 3, day: 10, hour: 21, minute: 5)),
            MoodRecord(mood: .tired, note: "", createdAt: makeDate(year: 2026, month: 3, day: 10, hour: 8, minute: 15)),
            MoodRecord(mood: .calm, note: "无关前一天", createdAt: makeDate(year: 2026, month: 3, day: 9, hour: 22, minute: 0))
        ]

        let detail = composer.buildHistoryDetail(for: targetDate, manualRecords: records)

        XCTAssertEqual(detail?.title, "疲惫")
        XCTAssertEqual(detail?.records.count, 2)
        XCTAssertTrue(detail?.badges.contains("2 条记录") == true)
        XCTAssertTrue(detail?.badges.contains("1 条备注") == true)
        XCTAssertTrue(detail?.badges.contains("主情绪 疲惫") == true)
        XCTAssertTrue(
            detail?.badges.contains(where: { $0.contains("08:15") && $0.contains("21:05") }) == true
        )
        XCTAssertTrue(detail?.narrative.contains("开会太久") == true)
    }

    func testMoodRecordToInferredEventPreservesStableIdentity() {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000099")!
        let record = MoodRecord(
            id: id,
            mood: .happy,
            note: "散步回来",
            createdAt: makeDate(year: 2026, month: 3, day: 10, hour: 18, minute: 32)
        )

        let entry = record.toInferredEvent(referenceDate: makeDate(year: 2026, month: 3, day: 10, hour: 20, minute: 0))

        XCTAssertEqual(entry.id, id)
        XCTAssertEqual(entry.startDate, makeDate(year: 2026, month: 3, day: 10, hour: 18, minute: 32))
        XCTAssertEqual(entry.endDate, entry.startDate)
        XCTAssertEqual(entry.displayName, "开心")
        XCTAssertEqual(entry.kind, .mood)
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }
}
