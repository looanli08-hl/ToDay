import SwiftData
import XCTest
@testable import ToDay

final class ShutterManagerTests: XCTestCase {
    @MainActor
    func testSaveTextRecord() {
        let manager = makeManager()
        let record = ShutterRecord(type: .text, textContent: "突然想到一个好主意")

        manager.save(record)

        XCTAssertEqual(manager.records.count, 1)
        XCTAssertEqual(manager.records[0].textContent, "突然想到一个好主意")
        XCTAssertEqual(manager.records[0].type, .text)
    }

    @MainActor
    func testSaveVoiceRecord() {
        let manager = makeManager()
        let record = ShutterRecord(
            type: .voice,
            mediaFilename: "voice_001.m4a",
            voiceTranscript: nil,
            duration: 5.2
        )

        manager.save(record)

        XCTAssertEqual(manager.records.count, 1)
        XCTAssertEqual(manager.records[0].type, .voice)
        XCTAssertEqual(manager.records[0].duration!, 5.2, accuracy: 0.01)
    }

    @MainActor
    func testRecordsForDateFiltersCorrectly() {
        let manager = makeManager()
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        let todayRecord = ShutterRecord(createdAt: today, type: .text, textContent: "今天")
        let yesterdayRecord = ShutterRecord(createdAt: yesterday, type: .text, textContent: "昨天")

        manager.save(todayRecord)
        manager.save(yesterdayRecord)

        let todayRecords = manager.records(on: today)
        XCTAssertEqual(todayRecords.count, 1)
        XCTAssertEqual(todayRecords[0].textContent, "今天")
    }

    @MainActor
    func testDeleteRecord() {
        let manager = makeManager()
        let record = ShutterRecord(type: .text, textContent: "要删除的")

        manager.save(record)
        XCTAssertEqual(manager.records.count, 1)

        manager.delete(id: record.id)
        XCTAssertEqual(manager.records.count, 0)
    }

    @MainActor
    func testDeleteRecordCleansUpMediaFile() {
        let manager = makeManager()
        let filename = "test_delete_\(UUID().uuidString).jpg"
        let url = ShutterMediaLibrary.fileURL(for: filename)
        try? FileManager.default.createDirectory(
            at: ShutterMediaLibrary.baseDirectoryURL,
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: url.path, contents: Data(repeating: 0xFF, count: 64))

        let record = ShutterRecord(type: .photo, mediaFilename: filename)
        manager.save(record)
        manager.delete(id: record.id)

        XCTAssertFalse(ShutterMediaLibrary.fileExists(filename: filename))
    }

    @MainActor
    func testRecordsReturnedNewestFirst() {
        let manager = makeManager()
        let earlier = ShutterRecord(
            createdAt: Date().addingTimeInterval(-3600),
            type: .text,
            textContent: "早"
        )
        let later = ShutterRecord(
            createdAt: Date(),
            type: .text,
            textContent: "晚"
        )

        manager.save(earlier)
        manager.save(later)

        XCTAssertEqual(manager.records[0].textContent, "晚")
        XCTAssertEqual(manager.records[1].textContent, "早")
    }

    @MainActor
    func testReloadFromStore() {
        let store = makeStore()
        let manager = ShutterManager(recordStore: store)

        let record = ShutterRecord(type: .text, textContent: "外部保存")
        try? store.save(record)

        XCTAssertEqual(manager.records.count, 0)
        manager.reloadFromStore()
        XCTAssertEqual(manager.records.count, 1)
    }

    @MainActor
    func testToInferredEventsConvertsAll() {
        let manager = makeManager()
        manager.save(ShutterRecord(type: .text, textContent: "文字"))
        manager.save(ShutterRecord(type: .photo, mediaFilename: "photo.jpg"))

        let events = manager.inferredEvents(on: Date())
        XCTAssertEqual(events.count, 2)
        XCTAssertTrue(events.allSatisfy { $0.kind == .shutter })
    }

    @MainActor
    private func makeStore() -> SwiftDataShutterRecordStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: ShutterRecordEntity.self, configurations: config)
        return SwiftDataShutterRecordStore(container: container)
    }

    @MainActor
    private func makeManager() -> ShutterManager {
        ShutterManager(recordStore: makeStore())
    }
}
