import XCTest
import SwiftData
@testable import ToDay

final class EchoMessageStoreTests: XCTestCase {
    private var container: ModelContainer!
    private var store: SwiftDataEchoMessageStore!

    @MainActor
    override func setUp() {
        super.setUp()
        container = try! ModelContainer(
            for: EchoMessageEntity.self,
            EchoChatSessionEntity.self,
            EchoChatMessageEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        store = SwiftDataEchoMessageStore(container: container)
    }

    override func tearDown() {
        container = nil
        store = nil
        super.tearDown()
    }

    func testSaveAndLoadMessage() throws {
        let sourceData = EchoSourceData(
            type: .todayData,
            sourceDescription: "今日数据"
        )
        let sourceJSON = try JSONEncoder().encode(sourceData)

        let entity = EchoMessageEntity(
            type: EchoMessageType.dailyInsight.rawValue,
            title: "今日洞察",
            preview: "今天运动了 45 分钟",
            sourceDescription: "来自：今日数据",
            sourceDataJSON: sourceJSON,
            isRead: false,
            threadId: UUID()
        )

        try store.save(entity)

        let loaded = store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.title, "今日洞察")
        XCTAssertEqual(loaded.first?.isRead, false)
    }

    func testUnreadCount() throws {
        let threadId1 = UUID()
        let threadId2 = UUID()

        let msg1 = EchoMessageEntity(
            type: EchoMessageType.dailyInsight.rawValue,
            title: "洞察 1",
            preview: "预览 1",
            sourceDescription: "来自：今日数据",
            isRead: false,
            threadId: threadId1
        )
        let msg2 = EchoMessageEntity(
            type: EchoMessageType.shutterEcho.rawValue,
            title: "快门回响",
            preview: "预览 2",
            sourceDescription: "来自：3月23日快门",
            isRead: true,
            threadId: threadId2
        )

        try store.save(msg1)
        try store.save(msg2)

        XCTAssertEqual(store.unreadCount(), 1)
    }

    func testMarkAsRead() throws {
        let entity = EchoMessageEntity(
            type: EchoMessageType.emotionCare.rawValue,
            title: "情绪关怀",
            preview: "最近有点累",
            sourceDescription: "来自：近期心情趋势",
            isRead: false,
            threadId: UUID()
        )
        try store.save(entity)

        try store.markAsRead(id: entity.id)

        let loaded = store.loadAll()
        XCTAssertEqual(loaded.first?.isRead, true)
        XCTAssertEqual(store.unreadCount(), 0)
    }

    func testDeleteMessage() throws {
        let entity = EchoMessageEntity(
            type: EchoMessageType.freeChat.rawValue,
            title: "随便聊聊",
            preview: "",
            sourceDescription: "",
            isRead: false,
            threadId: UUID()
        )
        try store.save(entity)
        XCTAssertEqual(store.loadAll().count, 1)

        try store.delete(id: entity.id)
        XCTAssertEqual(store.loadAll().count, 0)
    }

    func testLoadAllSortedByCreatedAtDescending() throws {
        let older = EchoMessageEntity(
            type: EchoMessageType.dailyInsight.rawValue,
            title: "旧消息",
            preview: "",
            sourceDescription: "",
            isRead: false,
            threadId: UUID(),
            createdAt: Date().addingTimeInterval(-3600)
        )
        let newer = EchoMessageEntity(
            type: EchoMessageType.shutterEcho.rawValue,
            title: "新消息",
            preview: "",
            sourceDescription: "",
            isRead: false,
            threadId: UUID(),
            createdAt: Date()
        )

        try store.save(older)
        try store.save(newer)

        let loaded = store.loadAll()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded.first?.title, "新消息")
    }
}
