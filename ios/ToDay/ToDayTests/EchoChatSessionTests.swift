import XCTest
import SwiftData
@testable import ToDay

final class EchoChatSessionTests: XCTestCase {
    private var container: ModelContainer!

    @MainActor
    override func setUp() {
        super.setUp()
        let schema = Schema([
            EchoChatSessionEntity.self,
            UserProfileEntity.self,
            DailySummaryEntity.self,
            ConversationMemoryEntity.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
    }

    override func tearDown() {
        container = nil
        super.tearDown()
    }

    func testCreateSession() throws {
        let context = ModelContext(container)
        let session = EchoChatSessionEntity(title: "测试会话")
        context.insert(session)
        try context.save()

        let descriptor = FetchDescriptor<EchoChatSessionEntity>()
        let sessions = try context.fetch(descriptor)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.title, "测试会话")
        XCTAssertFalse(sessions.first!.isTemporary)
    }

    func testTemporarySession() throws {
        let context = ModelContext(container)
        let session = EchoChatSessionEntity(title: "临时会话", isTemporary: true)
        context.insert(session)
        try context.save()

        let descriptor = FetchDescriptor<EchoChatSessionEntity>()
        let sessions = try context.fetch(descriptor)
        XCTAssertTrue(sessions.first!.isTemporary)
    }

    func testAddMessages() throws {
        let context = ModelContext(container)
        let session = EchoChatSessionEntity(title: "对话")
        context.insert(session)

        session.addMessage(role: .user, content: "你好")
        session.addMessage(role: .assistant, content: "你好！有什么想聊的吗？")
        try context.save()

        XCTAssertEqual(session.messages.count, 2)
        let roles = Set(session.messages.map(\.role))
        XCTAssertTrue(roles.contains(EchoChatRole.user.rawValue))
        XCTAssertTrue(roles.contains(EchoChatRole.assistant.rawValue))
    }

    func testMessageOrdering() throws {
        let context = ModelContext(container)
        let session = EchoChatSessionEntity(title: "对话")
        context.insert(session)

        session.addMessage(role: .user, content: "第一条")
        session.addMessage(role: .assistant, content: "第二条")
        session.addMessage(role: .user, content: "第三条")
        try context.save()

        let sorted = session.sortedMessages
        XCTAssertEqual(sorted.count, 3)
        XCTAssertEqual(sorted[0].content, "第一条")
        XCTAssertEqual(sorted[1].content, "第二条")
        XCTAssertEqual(sorted[2].content, "第三条")
    }

    func testClearMessages() throws {
        let context = ModelContext(container)
        let session = EchoChatSessionEntity(title: "对话")
        context.insert(session)

        session.addMessage(role: .user, content: "你好")
        session.addMessage(role: .assistant, content: "你好！")
        session.clearMessages()
        try context.save()

        XCTAssertTrue(session.messages.isEmpty)
    }

    func testToChatMessages() throws {
        let context = ModelContext(container)
        let session = EchoChatSessionEntity(title: "对话")
        context.insert(session)

        session.addMessage(role: .user, content: "你好")
        session.addMessage(role: .assistant, content: "你好！")
        try context.save()

        let chatMessages = session.toChatMessages()
        XCTAssertEqual(chatMessages.count, 2)
        XCTAssertEqual(chatMessages[0].role, .user)
        XCTAssertEqual(chatMessages[1].role, .assistant)
    }
}
