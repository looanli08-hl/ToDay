import SwiftData
import XCTest
@testable import ToDay

final class SwiftDataMoodRecordStoreTests: XCTestCase {
    func testSaveAndLoadSingleRecordPreservesFields() throws {
        let container = try makeInMemoryContainer()
        let store = SwiftDataMoodRecordStore(container: container)
        let record = MoodRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000701")!,
            mood: .happy,
            note: "晨跑之后",
            createdAt: sampleDate(hour: 8, minute: 15),
            endedAt: sampleDate(hour: 8, minute: 15),
            isTracking: false,
            captureMode: .point,
            photoAttachments: [
                MoodPhotoAttachment(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000711")!,
                    filename: "run.jpg",
                    createdAt: sampleDate(hour: 8, minute: 16)
                )
            ]
        )

        try store.saveRecords([record])
        let loaded = store.loadRecords()

        XCTAssertEqual(loaded.count, 1)
        assertMoodRecord(loaded[0], matches: record)
    }

    func testLoadRecordsReturnsCreatedAtDescending() throws {
        let container = try makeInMemoryContainer()
        let store = SwiftDataMoodRecordStore(container: container)
        let older = MoodRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000702")!,
            mood: .calm,
            note: "早餐",
            createdAt: sampleDate(hour: 8, minute: 30),
            isTracking: false
        )
        let newer = MoodRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000703")!,
            mood: .focused,
            note: "进入工作",
            createdAt: sampleDate(hour: 9, minute: 45),
            isTracking: false
        )

        try store.saveRecords([older, newer])
        let loaded = store.loadRecords()

        XCTAssertEqual(loaded.map(\.id), [newer.id, older.id])
    }

    func testSaveRecordsUpdatesExistingRecordWithSameID() throws {
        let container = try makeInMemoryContainer()
        let store = SwiftDataMoodRecordStore(container: container)
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000704")!
        let original = MoodRecord(
            id: id,
            mood: .tired,
            note: "午后发困",
            createdAt: sampleDate(hour: 14, minute: 10),
            isTracking: false
        )
        let updated = MoodRecord(
            id: id,
            mood: .focused,
            note: "喝完咖啡恢复",
            createdAt: sampleDate(hour: 14, minute: 10),
            endedAt: sampleDate(hour: 14, minute: 55),
            isTracking: false,
            captureMode: .session
        )

        try store.saveRecords([original])
        try store.saveRecords([updated])
        let loaded = store.loadRecords()

        XCTAssertEqual(loaded.count, 1)
        assertMoodRecord(loaded[0], matches: updated)
    }

    func testSaveRecordsDeletesMissingRecords() throws {
        let container = try makeInMemoryContainer()
        let store = SwiftDataMoodRecordStore(container: container)
        let first = MoodRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000705")!,
            mood: .happy,
            note: "出门",
            createdAt: sampleDate(hour: 10, minute: 0),
            isTracking: false
        )
        let second = MoodRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000706")!,
            mood: .calm,
            note: "午餐",
            createdAt: sampleDate(hour: 12, minute: 0),
            isTracking: false
        )

        try store.saveRecords([first, second])
        try store.saveRecords([second])
        let loaded = store.loadRecords()

        XCTAssertEqual(loaded.count, 1)
        assertMoodRecord(loaded[0], matches: second)
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: MoodRecordEntity.self, configurations: configuration)
    }

    private func sampleDate(hour: Int, minute: Int) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        let base = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_710_000_000))
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
    }

    private func assertMoodRecord(_ lhs: MoodRecord, matches rhs: MoodRecord) {
        XCTAssertEqual(lhs.id, rhs.id)
        XCTAssertEqual(lhs.mood, rhs.mood)
        XCTAssertEqual(lhs.note, rhs.note)
        XCTAssertEqual(lhs.createdAt, rhs.createdAt)
        XCTAssertEqual(lhs.endedAt, rhs.endedAt)
        XCTAssertEqual(lhs.isTracking, rhs.isTracking)
        XCTAssertEqual(lhs.captureMode, rhs.captureMode)
        XCTAssertEqual(lhs.photoAttachments, rhs.photoAttachments)
    }
}
