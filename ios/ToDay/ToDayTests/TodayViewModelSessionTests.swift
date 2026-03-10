import XCTest
@testable import ToDay

@MainActor
final class TodayViewModelSessionTests: XCTestCase {
    func testStartAndFinishMoodSessionUpdatesTimelineEntry() async {
        let provider = StubTimelineProvider()
        let store = InMemoryMoodRecordStore()
        let viewModel = TodayViewModel(provider: provider, recordStore: store)

        await viewModel.load(forceReload: true)

        let startDate = Date()
        let activeRecord = MoodRecord.active(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000111")!,
            mood: .focused,
            note: "推进一版交互",
            createdAt: startDate
        )

        viewModel.startMoodRecord(activeRecord)

        XCTAssertEqual(viewModel.activeRecord?.id, activeRecord.id)
        XCTAssertTrue(viewModel.timeline?.entries.contains(where: { $0.id == activeRecord.id.uuidString && $0.isLive }) == true)

        let finishDate = startDate.addingTimeInterval(45 * 60)
        viewModel.finishActiveMoodRecord(at: finishDate)

        let finalizedEntry = viewModel.timeline?.entries.first(where: { $0.id == activeRecord.id.uuidString })

        XCTAssertNil(viewModel.activeRecord)
        XCTAssertEqual(finalizedEntry?.durationMinutes, 45)
        XCTAssertEqual(finalizedEntry?.isLive, false)
        XCTAssertTrue(finalizedEntry?.moment.label.contains(" - ") == true)
    }

    func testStartMoodRecordIgnoresDuplicateSubmission() async {
        let provider = StubTimelineProvider()
        let store = InMemoryMoodRecordStore()
        let viewModel = TodayViewModel(provider: provider, recordStore: store)

        await viewModel.load(forceReload: true)

        let createdAt = Date()
        let record = MoodRecord(
            mood: .calm,
            note: "喝咖啡",
            createdAt: createdAt,
            isTracking: false
        )

        viewModel.startMoodRecord(record)
        viewModel.startMoodRecord(
            MoodRecord(
                mood: .calm,
                note: "喝咖啡",
                createdAt: createdAt,
                isTracking: false
            )
        )

        XCTAssertEqual(viewModel.todayManualRecordCount, 1)
        XCTAssertEqual(
            viewModel.timeline?.entries.filter { $0.title == "平静" && $0.detail.contains("喝咖啡") }.count,
            1
        )
    }
}

private struct StubTimelineProvider: TimelineDataProviding {
    let source: TimelineSource = .mock

    func loadTimeline(for date: Date) async throws -> DayTimeline {
        DayTimeline(
            date: date,
            summary: "测试时间线",
            source: source,
            stats: [TimelineStat(title: "模式", value: "测试")],
            entries: []
        )
    }
}

private struct InMemoryMoodRecordStore: MoodRecordStoring {
    var records: [MoodRecord] = []

    func loadRecords() -> [MoodRecord] {
        records
    }

    func saveRecords(_ records: [MoodRecord]) throws {}
}
