import SwiftData
import XCTest
@testable import ToDay

@MainActor
final class SpendingManagerTests: XCTestCase {
    func testAddRecordAppearsInRecords() {
        let manager = makeManager()
        let record = SpendingRecord(amount: 35.5, category: .food, note: "午餐")

        manager.addRecord(record)

        XCTAssertEqual(manager.records.count, 1)
        XCTAssertEqual(manager.records[0].amount, 35.5, accuracy: 0.01)
        XCTAssertEqual(manager.records[0].category, .food)
    }

    func testRecordsForDate() {
        let manager = makeManager()
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let todayRecord = SpendingRecord(amount: 20, category: .food, createdAt: today)
        let yesterdayRecord = SpendingRecord(amount: 50, category: .shopping, createdAt: yesterday)

        manager.addRecord(todayRecord)
        manager.addRecord(yesterdayRecord)

        let todayRecords = manager.records(on: today)
        XCTAssertEqual(todayRecords.count, 1)
        XCTAssertEqual(todayRecords[0].category, .food)
    }

    func testRemoveRecord() {
        let manager = makeManager()
        let record = SpendingRecord(amount: 100, category: .entertainment)

        manager.addRecord(record)
        manager.removeRecord(id: record.id)

        XCTAssertEqual(manager.records.count, 0)
    }

    func testTodayTotal() {
        let manager = makeManager()
        let today = Date()

        manager.addRecord(SpendingRecord(amount: 35, category: .food, createdAt: today))
        manager.addRecord(SpendingRecord(amount: 15, category: .transport, createdAt: today))

        let total = manager.todayTotal(on: today)
        XCTAssertEqual(total, 50, accuracy: 0.01)
    }

    func testReloadFromStore() {
        let store = makeStore()
        let record = SpendingRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000B01")!,
            amount: 42,
            category: .daily
        )
        try! store.save(record)

        let manager = SpendingManager(recordStore: store)

        XCTAssertEqual(manager.records.count, 1)
        XCTAssertEqual(manager.records[0].id, record.id)
    }

    private func makeStore() -> SwiftDataSpendingRecordStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: SpendingRecordEntity.self, configurations: config)
        return SwiftDataSpendingRecordStore(container: container)
    }

    private func makeManager() -> SpendingManager {
        SpendingManager(recordStore: makeStore())
    }
}
