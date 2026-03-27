import SwiftData
import XCTest
@testable import ToDay

final class ShutterRecordStoreTests: XCTestCase {
    func testSaveAndLoadPreservesFields() throws {
        let store = makeStore()
        let record = ShutterRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000801")!,
            createdAt: sampleDate(hour: 14, minute: 30),
            type: .text,
            textContent: "突然想到一个好主意",
            latitude: 31.2304,
            longitude: 121.4737,
            echoConfig: EchoConfig(frequency: .high, customRemindAt: nil)
        )

        try store.save(record)
        let loaded = store.loadAll()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, record.id)
        XCTAssertEqual(loaded[0].type, .text)
        XCTAssertEqual(loaded[0].textContent, "突然想到一个好主意")
        XCTAssertEqual(loaded[0].latitude!, 31.2304, accuracy: 0.0001)
        XCTAssertEqual(loaded[0].echoConfig.frequency, .high)
    }

    func testSaveVoiceRecord() throws {
        let store = makeStore()
        let record = ShutterRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000802")!,
            createdAt: sampleDate(hour: 9, minute: 15),
            type: .voice,
            mediaFilename: "voice_001.m4a",
            voiceTranscript: "今天天气真好",
            duration: 5.2
        )

        try store.save(record)
        let loaded = store.loadAll()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].type, .voice)
        XCTAssertEqual(loaded[0].mediaFilename, "voice_001.m4a")
        XCTAssertEqual(loaded[0].voiceTranscript, "今天天气真好")
        XCTAssertEqual(loaded[0].duration!, 5.2, accuracy: 0.01)
    }

    func testDeleteRecord() throws {
        let store = makeStore()
        let record = ShutterRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000803")!,
            createdAt: sampleDate(hour: 10, minute: 0),
            type: .photo,
            mediaFilename: "photo_001.jpg"
        )

        try store.save(record)
        try store.delete(record.id)
        let loaded = store.loadAll()

        XCTAssertEqual(loaded.count, 0)
    }

    func testLoadReturnsCreatedAtDescending() throws {
        let store = makeStore()
        let older = ShutterRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000804")!,
            createdAt: sampleDate(hour: 8, minute: 0),
            type: .text,
            textContent: "早上"
        )
        let newer = ShutterRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000805")!,
            createdAt: sampleDate(hour: 12, minute: 0),
            type: .text,
            textContent: "中午"
        )

        try store.save(older)
        try store.save(newer)
        let loaded = store.loadAll()

        XCTAssertEqual(loaded.map(\.id), [newer.id, older.id])
    }

    private func makeStore() -> SwiftDataShutterRecordStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: ShutterRecordEntity.self, configurations: config)
        return SwiftDataShutterRecordStore(container: container)
    }

    private func sampleDate(hour: Int, minute: Int) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        let base = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_710_000_000))
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
    }
}
