import SwiftData
import XCTest
@testable import ToDay

final class EchoItemStoreTests: XCTestCase {
    func testSaveAndLoadPreservesFields() throws {
        let store = makeStore()
        let item = EchoItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000E01")!,
            shutterRecordID: UUID(uuidString: "00000000-0000-0000-0000-000000000801")!,
            scheduledDate: sampleDate(daysFromNow: 3),
            status: .pending,
            reminderDayOffset: 3
        )

        try store.save(item)
        let loaded = store.loadAll()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, item.id)
        XCTAssertEqual(loaded[0].shutterRecordID, item.shutterRecordID)
        XCTAssertEqual(loaded[0].status, .pending)
        XCTAssertEqual(loaded[0].reminderDayOffset, 3)
    }

    func testLoadPendingForDate() throws {
        let store = makeStore()
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        let todayItem = EchoItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000E02")!,
            shutterRecordID: UUID(uuidString: "00000000-0000-0000-0000-000000000802")!,
            scheduledDate: today,
            status: .pending,
            reminderDayOffset: 1
        )
        let tomorrowItem = EchoItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000E03")!,
            shutterRecordID: UUID(uuidString: "00000000-0000-0000-0000-000000000803")!,
            scheduledDate: tomorrow,
            status: .pending,
            reminderDayOffset: 3
        )

        try store.save(todayItem)
        try store.save(tomorrowItem)
        let pending = store.loadPending(for: today)

        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending[0].id, todayItem.id)
    }

    func testUpdateStatus() throws {
        let store = makeStore()
        var item = EchoItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000E04")!,
            shutterRecordID: UUID(uuidString: "00000000-0000-0000-0000-000000000804")!,
            scheduledDate: sampleDate(daysFromNow: 0),
            status: .pending,
            reminderDayOffset: 7
        )

        try store.save(item)
        item.status = .viewed
        try store.save(item)
        let loaded = store.loadAll()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].status, .viewed)
    }

    func testDeleteByShutterRecordID() throws {
        let store = makeStore()
        let shutterID = UUID(uuidString: "00000000-0000-0000-0000-000000000805")!
        let item1 = EchoItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000E05")!,
            shutterRecordID: shutterID,
            scheduledDate: sampleDate(daysFromNow: 1),
            status: .pending,
            reminderDayOffset: 1
        )
        let item2 = EchoItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000E06")!,
            shutterRecordID: shutterID,
            scheduledDate: sampleDate(daysFromNow: 7),
            status: .pending,
            reminderDayOffset: 7
        )

        try store.save(item1)
        try store.save(item2)
        try store.deleteAll(forShutterRecordID: shutterID)
        let loaded = store.loadAll()

        XCTAssertEqual(loaded.count, 0)
    }

    func testDeleteByID() throws {
        let store = makeStore()
        let item = EchoItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000E07")!,
            shutterRecordID: UUID(uuidString: "00000000-0000-0000-0000-000000000806")!,
            scheduledDate: sampleDate(daysFromNow: 3),
            status: .pending,
            reminderDayOffset: 3
        )

        try store.save(item)
        try store.delete(item.id)
        let loaded = store.loadAll()

        XCTAssertEqual(loaded.count, 0)
    }

    private func makeStore() -> SwiftDataEchoItemStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: EchoItemEntity.self, configurations: config)
        return SwiftDataEchoItemStore(container: container)
    }

    private func sampleDate(daysFromNow offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: Date()))!
    }
}
