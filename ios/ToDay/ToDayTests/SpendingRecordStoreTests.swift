import SwiftData
import XCTest
@testable import ToDay

final class SpendingRecordStoreTests: XCTestCase {
    func testSaveAndLoadPreservesFields() throws {
        let store = makeStore()
        let record = SpendingRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000901")!,
            amount: 35.5,
            category: .food,
            note: "午餐",
            createdAt: sampleDate(hour: 12, minute: 15),
            latitude: 31.2304,
            longitude: 121.4737
        )

        try store.save(record)
        let loaded = store.loadAll()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, record.id)
        XCTAssertEqual(loaded[0].amount, 35.5, accuracy: 0.01)
        XCTAssertEqual(loaded[0].category, .food)
        XCTAssertEqual(loaded[0].note, "午餐")
        XCTAssertEqual(loaded[0].latitude!, 31.2304, accuracy: 0.0001)
    }

    func testDeleteRecord() throws {
        let store = makeStore()
        let record = SpendingRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000902")!,
            amount: 15.0,
            category: .transport,
            createdAt: sampleDate(hour: 8, minute: 30)
        )

        try store.save(record)
        try store.delete(record.id)
        let loaded = store.loadAll()

        XCTAssertEqual(loaded.count, 0)
    }

    func testLoadReturnsCreatedAtDescending() throws {
        let store = makeStore()
        let older = SpendingRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000903")!,
            amount: 20.0,
            category: .food,
            createdAt: sampleDate(hour: 8, minute: 0)
        )
        let newer = SpendingRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000904")!,
            amount: 50.0,
            category: .shopping,
            createdAt: sampleDate(hour: 15, minute: 0)
        )

        try store.save(older)
        try store.save(newer)
        let loaded = store.loadAll()

        XCTAssertEqual(loaded.map(\.id), [newer.id, older.id])
    }

    private func makeStore() -> SwiftDataSpendingRecordStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: SpendingRecordEntity.self, configurations: config)
        return SwiftDataSpendingRecordStore(container: container)
    }

    private func sampleDate(hour: Int, minute: Int) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        let base = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_710_000_000))
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
    }
}
