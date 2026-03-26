import Foundation
import SwiftData

@MainActor
final class EchoMessageManager: ObservableObject {
    // MARK: - Published State

    @Published private(set) var allMessages: [EchoMessageEntity] = []
    @Published private(set) var unreadCount: Int = 0

    // MARK: - Dependencies

    private let store: any EchoMessageStoring
    private let container: ModelContainer

    init(store: any EchoMessageStoring, container: ModelContainer) {
        self.store = store
        self.container = container
        refresh()
    }

    // MARK: - Refresh

    /// Reload messages and unread count from store.
    func refresh() {
        allMessages = store.loadAll()
        unreadCount = store.unreadCount()
    }

    // MARK: - Mark As Read

    func markAsRead(id: UUID) throws {
        try store.markAsRead(id: id)
        refresh()
    }

    // MARK: - Delete

    func deleteMessage(id: UUID) throws {
        try store.delete(id: id)
        refresh()
    }

    // MARK: - Generate Message

    /// Create a new message with an associated chat thread. The thread is pre-seeded
    /// with Echo's initial message so it appears when the user opens the thread.
    ///
    /// - Parameters:
    ///   - type: Message type (dailyInsight, shutterEcho, etc.)
    ///   - title: Message title for the list
    ///   - preview: Preview text (first ~2 lines)
    ///   - sourceDescription: Human-readable source label ("来自：XXX")
    ///   - sourceData: Optional structured source data for AI context
    ///   - initialEchoMessage: Echo's first message in the thread (full version of the preview)
    /// - Returns: The saved EchoMessageEntity
    @discardableResult
    func generateMessage(
        type: EchoMessageType,
        title: String,
        preview: String,
        sourceDescription: String,
        sourceData: EchoSourceData?,
        initialEchoMessage: String
    ) throws -> EchoMessageEntity {
        // 1. Create a chat session (thread) for this message
        let context = ModelContext(container)
        let session = EchoChatSessionEntity(
            title: title
        )
        // Seed Echo's first message into the thread
        session.addMessage(role: .assistant, content: initialEchoMessage)
        context.insert(session)
        try context.save()

        // 2. Encode source data
        var sourceDataJSON: Data?
        if let sourceData {
            sourceDataJSON = try JSONEncoder().encode(sourceData)
        }

        // 3. Create and save the message entity
        let entity = EchoMessageEntity(
            type: type.rawValue,
            title: title,
            preview: preview,
            sourceDescription: sourceDescription,
            sourceDataJSON: sourceDataJSON,
            isRead: false,
            threadId: session.id
        )
        try store.save(entity)

        refresh()
        return entity
    }

    // MARK: - Free Chat

    /// Create a freeChat message — no source data, immediately marked as read.
    @discardableResult
    func createFreeChatMessage() throws -> EchoMessageEntity {
        let context = ModelContext(container)
        let session = EchoChatSessionEntity(
            title: "随便聊聊"
        )
        context.insert(session)
        try context.save()

        let entity = EchoMessageEntity(
            type: EchoMessageType.freeChat.rawValue,
            title: "随便聊聊",
            preview: "",
            sourceDescription: "",
            isRead: true,
            threadId: session.id
        )
        try store.save(entity)

        refresh()
        return entity
    }
}
