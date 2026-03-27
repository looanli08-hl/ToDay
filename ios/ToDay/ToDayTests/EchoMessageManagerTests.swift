import XCTest
import SwiftData
@testable import ToDay

@MainActor
final class EchoMessageManagerTests: XCTestCase {
    private var container: ModelContainer!
    private var manager: EchoMessageManager!

    override func setUp() {
        super.setUp()
        container = try! ModelContainer(
            for: EchoMessageEntity.self,
            EchoChatSessionEntity.self,
            EchoChatMessageEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = SwiftDataEchoMessageStore(container: container)
        manager = EchoMessageManager(store: store, container: container)
    }

    override func tearDown() {
        container = nil
        manager = nil
        super.tearDown()
    }

    func testGenerateMessageCreatesEntityAndThread() throws {
        let sourceData = EchoSourceData(
            type: .todayData,
            sourceDescription: "今日数据"
        )

        let message = try manager.generateMessage(
            type: .dailyInsight,
            title: "今日洞察",
            preview: "今天运动了 45 分钟，比昨天多",
            sourceDescription: "来自：今日数据",
            sourceData: sourceData,
            initialEchoMessage: "今天运动了 45 分钟，比昨天多了不少，身体在回应你的坚持呢。"
        )

        XCTAssertEqual(message.messageType, .dailyInsight)
        XCTAssertEqual(message.isRead, false)
        XCTAssertEqual(manager.unreadCount, 1)

        // Verify thread was created with initial Echo message
        let context = ModelContext(container)
        let threadId = message.threadId
        var descriptor = FetchDescriptor<EchoChatSessionEntity>(
            predicate: #Predicate { $0.id == threadId }
        )
        descriptor.fetchLimit = 1
        let session = try context.fetch(descriptor).first
        XCTAssertNotNil(session)
        XCTAssertEqual(session?.messages.count, 1)
        XCTAssertEqual(session?.messages.first?.role, EchoChatRole.assistant.rawValue)
    }

    func testMarkAsReadUpdatesUnreadCount() throws {
        let msg = try manager.generateMessage(
            type: .shutterEcho,
            title: "快门回响",
            preview: "你 3 天前提到的创意",
            sourceDescription: "来自：3月23日快门",
            sourceData: nil,
            initialEchoMessage: "你 3 天前提到了一个创意，想聊聊后续吗？"
        )
        XCTAssertEqual(manager.unreadCount, 1)

        try manager.markAsRead(id: msg.id)
        XCTAssertEqual(manager.unreadCount, 0)
    }

    func testLoadAllReturnsMessages() throws {
        _ = try manager.generateMessage(
            type: .dailyInsight,
            title: "洞察 1",
            preview: "预览 1",
            sourceDescription: "来源 1",
            sourceData: nil,
            initialEchoMessage: "内容 1"
        )
        _ = try manager.generateMessage(
            type: .emotionCare,
            title: "关怀",
            preview: "预览 2",
            sourceDescription: "来源 2",
            sourceData: nil,
            initialEchoMessage: "内容 2"
        )

        XCTAssertEqual(manager.allMessages.count, 2)
    }

    func testCreateFreeChatMessage() throws {
        let msg = try manager.createFreeChatMessage()
        XCTAssertEqual(msg.messageType, .freeChat)
        XCTAssertEqual(msg.title, "随便聊聊")
        XCTAssertEqual(msg.isRead, true) // freeChat is immediately "read"
    }
}
