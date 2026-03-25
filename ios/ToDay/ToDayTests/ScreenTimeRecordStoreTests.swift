import SwiftData
import XCTest
@testable import ToDay

final class ScreenTimeRecordStoreTests: XCTestCase {
    func testSaveAndLoadPreservesFields() throws {
        let store = makeStore()
        let record = ScreenTimeRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000A01")!,
            dateKey: "2026-03-25",
            totalScreenTime: 5400,
            appUsages: [
                AppUsage(appName: "Xcode", category: "开发", duration: 3600),
                AppUsage(appName: "Safari", category: "浏览", duration: 1800)
            ],
            pickupCount: 42
        )

        try store.save(record)
        let loaded = store.loadAll()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, record.id)
        XCTAssertEqual(loaded[0].dateKey, "2026-03-25")
        XCTAssertEqual(loaded[0].totalScreenTime, 5400, accuracy: 0.1)
        XCTAssertEqual(loaded[0].appUsages.count, 2)
        XCTAssertEqual(loaded[0].appUsages[0].appName, "Xcode")
        XCTAssertEqual(loaded[0].pickupCount, 42)
    }

    func testLoadForDateKey() throws {
        let store = makeStore()
        let record1 = ScreenTimeRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000A02")!,
            dateKey: "2026-03-24",
            totalScreenTime: 7200
        )
        let record2 = ScreenTimeRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000A03")!,
            dateKey: "2026-03-25",
            totalScreenTime: 3600
        )

        try store.save(record1)
        try store.save(record2)

        let found = store.loadForDateKey("2026-03-25")
        XCTAssertNotNil(found)
        XCTAssertEqual(found!.totalScreenTime, 3600, accuracy: 0.1)

        let notFound = store.loadForDateKey("2026-03-26")
        XCTAssertNil(notFound)
    }

    func testDeleteRecord() throws {
        let store = makeStore()
        let record = ScreenTimeRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000A04")!,
            dateKey: "2026-03-25",
            totalScreenTime: 3600
        )

        try store.save(record)
        try store.delete(record.id)
        let loaded = store.loadAll()

        XCTAssertEqual(loaded.count, 0)
    }

    func testSaveSameDateKeyUpdatesExisting() throws {
        let store = makeStore()
        let record1 = ScreenTimeRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000A05")!,
            dateKey: "2026-03-25",
            totalScreenTime: 3600,
            pickupCount: 20
        )
        let record2 = ScreenTimeRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000A06")!,
            dateKey: "2026-03-25",
            totalScreenTime: 7200,
            pickupCount: 45
        )

        try store.save(record1)
        try store.save(record2)

        let loaded = store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].totalScreenTime, 7200, accuracy: 0.1)
        XCTAssertEqual(loaded[0].pickupCount, 45)
    }

    func testToInferredEvent() {
        let record = ScreenTimeRecord(
            dateKey: "2026-03-25",
            totalScreenTime: 9000,
            appUsages: [
                AppUsage(appName: "Safari", category: "浏览", duration: 3600),
                AppUsage(appName: "Xcode", category: "开发", duration: 5400)
            ],
            pickupCount: 30
        )

        let event = record.toInferredEvent()
        XCTAssertEqual(event.kind, .screenTime)
        XCTAssertEqual(event.displayName, "屏幕时间 2h 30m")
        XCTAssertEqual(event.confidence, .medium)
        XCTAssertNotNil(event.subtitle)
    }

    private func makeStore() -> SwiftDataScreenTimeRecordStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: ScreenTimeRecordEntity.self, configurations: config)
        return SwiftDataScreenTimeRecordStore(container: container)
    }
}
