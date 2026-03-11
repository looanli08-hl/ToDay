import XCTest
@testable import ToDay
import UIKit

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

    func testCompletedShortSessionStillUsesRangeMoment() {
        let record = MoodRecord.active(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
            mood: .focused,
            note: "短时推进",
            createdAt: sameDay(hour: 11, minute: 20)
        )
        let completed = record.completed(at: sameDay(hour: 11, minute: 20).addingTimeInterval(20))
        let entry = completed.toTimelineEntry(referenceDate: sameDay(hour: 11, minute: 21))

        XCTAssertNotNil(entry.moment.endMinuteOfDay)
        XCTAssertTrue(entry.moment.label.contains(" - "))
        XCTAssertEqual(entry.durationMinutes, 1)
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

    func testInitializerPreservesRecordsWithDifferentIDs() {
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

        XCTAssertEqual(viewModel.todayManualRecordCount, 2)
        XCTAssertEqual(store.records.count, 2)
    }

    func testPointRecordCanBeAddedWhileSessionIsActive() async {
        let provider = StubTimelineProvider()
        let store = InMemoryMoodRecordStore()
        let viewModel = TodayViewModel(provider: provider, recordStore: store)

        await viewModel.load(forceReload: true)

        let activeRecord = MoodRecord.active(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000511")!,
            mood: .calm,
            note: "旅行中",
            createdAt: sameDay(hour: 14, minute: 0)
        )
        let pointRecord = MoodRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000512")!,
            mood: .happy,
            note: "拍到一处风景",
            createdAt: sameDay(hour: 14, minute: 25),
            isTracking: false
        )

        viewModel.startMoodRecord(activeRecord)
        viewModel.startMoodRecord(pointRecord)

        XCTAssertEqual(viewModel.activeRecord?.id, activeRecord.id)
        XCTAssertEqual(viewModel.todayManualRecordCount, 2)
        XCTAssertEqual(viewModel.timeline?.entries.filter { $0.id == activeRecord.id.uuidString }.count, 1)
        XCTAssertEqual(viewModel.timeline?.entries.filter { $0.id == pointRecord.id.uuidString }.count, 1)
    }

    func testTimelineEntryPreservesPhotoAttachments() {
        let attachments = [
            MoodPhotoAttachment(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000611")!,
                filename: "sample-1.jpg"
            ),
            MoodPhotoAttachment(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000612")!,
                filename: "sample-2.jpg"
            )
        ]
        let record = MoodRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000613")!,
            mood: .happy,
            note: "路过海边",
            createdAt: sameDay(hour: 16, minute: 30),
            isTracking: false,
            photoAttachments: attachments
        )

        let entry = record.toTimelineEntry(referenceDate: sameDay(hour: 16, minute: 40))

        XCTAssertEqual(entry.photoAttachments, attachments)
    }

    func testCompletingSessionPreservesPhotoAttachments() {
        let attachments = [
            MoodPhotoAttachment(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000621")!,
                filename: "session.jpg"
            )
        ]
        let record = MoodRecord.active(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000622")!,
            mood: .focused,
            note: "旅行中",
            createdAt: sameDay(hour: 17, minute: 0),
            photoAttachments: attachments
        )

        let completed = record.completed(at: sameDay(hour: 18, minute: 0))

        XCTAssertEqual(completed.photoAttachments, attachments)
    }

    func testMoodRecordEncodingIncludesSchemaVersion() throws {
        let record = MoodRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000631")!,
            mood: .happy,
            note: "傍晚散步",
            createdAt: sameDay(hour: 19, minute: 0),
            isTracking: false
        )

        let data = try JSONEncoder().encode(record)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(payload["schemaVersion"] as? Int, MoodRecord.schemaVersion)
    }

    func testRemovingRecordDeletesOrphanedPhotos() throws {
        let provider = StubTimelineProvider()
        let store = InMemoryMoodRecordStore()
        let viewModel = TodayViewModel(provider: provider, recordStore: store)
        let attachment = try MoodPhotoLibrary.storeImageData(sampleJPEGData())
        let fileURL = MoodPhotoLibrary.url(for: attachment)
        let record = MoodRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000632")!,
            mood: .happy,
            note: "拍了一张晚霞",
            createdAt: sameDay(hour: 19, minute: 20),
            isTracking: false,
            photoAttachments: [attachment]
        )

        viewModel.startMoodRecord(record)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        viewModel.removeMoodRecord(id: record.id)

        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
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

private func sampleJPEGData() -> Data {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16))
    let image = renderer.image { context in
        UIColor.systemTeal.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
    }

    return image.jpegData(compressionQuality: 0.9) ?? Data()
}
