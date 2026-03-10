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

    func testAddingSecondRecordDoesNotDuplicateExistingTimelineEntries() async {
        let provider = StubTimelineProvider()
        let store = InMemoryMoodRecordStore()
        let viewModel = TodayViewModel(provider: provider, recordStore: store)

        await viewModel.load(forceReload: true)

        let firstRecord = MoodRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000211")!,
            mood: .happy,
            note: "早餐",
            createdAt: sameDay(hour: 9, minute: 0),
            isTracking: false
        )
        let secondRecord = MoodRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000212")!,
            mood: .focused,
            note: "开会",
            createdAt: sameDay(hour: 10, minute: 0),
            isTracking: false
        )

        viewModel.startMoodRecord(firstRecord)
        viewModel.startMoodRecord(secondRecord)

        XCTAssertEqual(viewModel.timeline?.entries.filter { $0.id == firstRecord.id.uuidString }.count, 1)
        XCTAssertEqual(viewModel.timeline?.entries.filter { $0.id == secondRecord.id.uuidString }.count, 1)
        XCTAssertEqual(viewModel.todayManualRecordCount, 2)
    }

    func testForceReloadDoesNotDuplicateManualTimelineEntries() async {
        let provider = StubTimelineProvider()
        let store = InMemoryMoodRecordStore()
        let viewModel = TodayViewModel(provider: provider, recordStore: store)

        await viewModel.load(forceReload: true)

        let record = MoodRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000311")!,
            mood: .tired,
            note: "下午犯困",
            createdAt: sameDay(hour: 15, minute: 0),
            isTracking: false
        )

        viewModel.startMoodRecord(record)
        await viewModel.load(forceReload: true)

        XCTAssertEqual(viewModel.timeline?.entries.filter { $0.id == record.id.uuidString }.count, 1)
        XCTAssertEqual(viewModel.todayManualRecordCount, 1)
    }

    func testInitializerDeduplicatesPersistedRecords() {
        let provider = StubTimelineProvider()
        let createdAt = sameDay(hour: 18, minute: 0)
        let duplicateA = MoodRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000411")!,
            mood: .calm,
            note: "散步",
            createdAt: createdAt,
            isTracking: false
        )
        let duplicateB = MoodRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000412")!,
            mood: .calm,
            note: "散步",
            createdAt: createdAt,
            isTracking: false
        )
        let store = InMemoryMoodRecordStore(records: [duplicateA, duplicateB])

        let viewModel = TodayViewModel(provider: provider, recordStore: store)

        XCTAssertEqual(viewModel.todayManualRecordCount, 1)
        XCTAssertEqual(store.records.count, 1)
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

private final class InMemoryMoodRecordStore: MoodRecordStoring {
    var records: [MoodRecord]

    init(records: [MoodRecord] = []) {
        self.records = records
    }

    func loadRecords() -> [MoodRecord] {
        records
    }

    func saveRecords(_ records: [MoodRecord]) throws {
        self.records = records
    }
}

private func sameDay(hour: Int, minute: Int) -> Date {
    let calendar = Calendar.current
    return calendar.date(
        bySettingHour: hour,
        minute: minute,
        second: 0,
        of: Date()
    ) ?? Date()
}
