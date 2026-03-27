import SwiftData
import XCTest
@testable import ToDay

@MainActor
final class EchoEngineTests: XCTestCase {
    func testScheduleCreatesEchoItemsForMediumFrequency() async throws {
        let (engine, echoStore, _) = makeEngine()
        let record = makeShutterRecord(echoFrequency: .medium)

        await engine.scheduleEchoes(for: record)

        let items = echoStore.loadAll()
        // medium frequency = 3, 7, 30 day offsets
        XCTAssertEqual(items.count, 3)
        let offsets = Set(items.map(\.reminderDayOffset))
        XCTAssertEqual(offsets, [3, 7, 30])
    }

    func testScheduleCreatesEchoItemsForHighFrequency() async throws {
        let (engine, echoStore, _) = makeEngine()
        let record = makeShutterRecord(echoFrequency: .high)

        await engine.scheduleEchoes(for: record)

        let items = echoStore.loadAll()
        // high frequency = 1, 3, 7, 30 day offsets
        XCTAssertEqual(items.count, 4)
        let offsets = Set(items.map(\.reminderDayOffset))
        XCTAssertEqual(offsets, [1, 3, 7, 30])
    }

    func testScheduleCreatesNoItemsForOffFrequency() async throws {
        let (engine, echoStore, _) = makeEngine()
        let record = makeShutterRecord(echoFrequency: .off)

        await engine.scheduleEchoes(for: record)

        let items = echoStore.loadAll()
        XCTAssertEqual(items.count, 0)
    }

    func testCancelRemovesAllEchoItemsForRecord() async throws {
        let (engine, echoStore, _) = makeEngine()
        let record = makeShutterRecord(echoFrequency: .medium)

        await engine.scheduleEchoes(for: record)
        XCTAssertEqual(echoStore.loadAll().count, 3)

        await engine.cancelEchoes(forShutterRecordID: record.id)

        let items = echoStore.loadAll()
        XCTAssertEqual(items.count, 0)
    }

    func testScheduledDatesAreCorrect() async throws {
        let (engine, echoStore, _) = makeEngine()
        let createdAt = Date()
        let record = ShutterRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000901")!,
            createdAt: createdAt,
            type: .text,
            textContent: "Test",
            echoConfig: EchoConfig(frequency: .low)
        )

        await engine.scheduleEchoes(for: record)

        let items = echoStore.loadAll().sorted { $0.reminderDayOffset < $1.reminderDayOffset }
        let calendar = Calendar.current
        // low = 7, 30
        XCTAssertEqual(items.count, 2)
        XCTAssert(calendar.isDate(
            items[0].scheduledDate,
            inSameDayAs: calendar.date(byAdding: .day, value: 7, to: createdAt)!
        ))
        XCTAssert(calendar.isDate(
            items[1].scheduledDate,
            inSameDayAs: calendar.date(byAdding: .day, value: 30, to: createdAt)!
        ))
    }

    func testTodayEchoesReturnsPendingForToday() async throws {
        let (engine, echoStore, _) = makeEngine()
        let today = Calendar.current.startOfDay(for: Date())
        let shutterID = UUID(uuidString: "00000000-0000-0000-0000-000000000902")!

        let todayItem = EchoItem(
            shutterRecordID: shutterID,
            scheduledDate: today,
            status: .pending,
            reminderDayOffset: 3
        )
        try echoStore.save(todayItem)

        let pending = await engine.todayEchoes()
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending[0].shutterRecordID, shutterID)
    }

    func testMarkAsViewedUpdatesStatus() async throws {
        let (engine, echoStore, _) = makeEngine()
        let item = EchoItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000E10")!,
            shutterRecordID: UUID(uuidString: "00000000-0000-0000-0000-000000000903")!,
            scheduledDate: Calendar.current.startOfDay(for: Date()),
            status: .pending,
            reminderDayOffset: 1
        )
        try echoStore.save(item)

        await engine.markAsViewed(echoID: item.id)

        let loaded = echoStore.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].status, .viewed)
    }

    func testDismissUpdatesStatus() async throws {
        let (engine, echoStore, _) = makeEngine()
        let item = EchoItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000E11")!,
            shutterRecordID: UUID(uuidString: "00000000-0000-0000-0000-000000000904")!,
            scheduledDate: Calendar.current.startOfDay(for: Date()),
            status: .pending,
            reminderDayOffset: 7
        )
        try echoStore.save(item)

        await engine.dismiss(echoID: item.id)

        let loaded = echoStore.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].status, .dismissed)
    }

    func testSnoozeReschedulesToTomorrow() async throws {
        let (engine, echoStore, _) = makeEngine()
        let today = Calendar.current.startOfDay(for: Date())
        let item = EchoItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000E12")!,
            shutterRecordID: UUID(uuidString: "00000000-0000-0000-0000-000000000905")!,
            scheduledDate: today,
            status: .pending,
            reminderDayOffset: 3
        )
        try echoStore.save(item)

        await engine.snooze(echoID: item.id)

        let loaded = echoStore.loadAll()
        // Should have snoozed original + new pending item for tomorrow = 2 items
        XCTAssertEqual(loaded.count, 2)
        let snoozedItem = loaded.first { $0.id == item.id }
        XCTAssertEqual(snoozedItem?.status, .snoozed)
        // Should have a new pending item for tomorrow
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let tomorrowPending = echoStore.loadPending(for: tomorrow)
        XCTAssertEqual(tomorrowPending.count, 1)
    }

    // MARK: - Helpers

    private func makeEngine() -> (EchoEngine, SwiftDataEchoItemStore, MockNotificationCenter) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: EchoItemEntity.self, configurations: config)
        let echoStore = SwiftDataEchoItemStore(container: container)
        let mockNotifications = MockNotificationCenter()
        let engine = EchoEngine(
            echoStore: echoStore,
            notificationScheduler: mockNotifications
        )
        return (engine, echoStore, mockNotifications)
    }

    private func makeShutterRecord(echoFrequency: EchoFrequency) -> ShutterRecord {
        ShutterRecord(
            type: .text,
            textContent: "Test record",
            echoConfig: EchoConfig(frequency: echoFrequency)
        )
    }
}

/// Mock notification center for testing — does not actually post notifications
final class MockNotificationCenter: EchoNotificationScheduling {
    private(set) var scheduledIdentifiers: [String] = []
    private(set) var removedIdentifiers: [String] = []

    func scheduleEchoNotification(identifier: String, title: String, body: String, triggerDate: Date) {
        scheduledIdentifiers.append(identifier)
    }

    func removeNotifications(identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
    }
}
