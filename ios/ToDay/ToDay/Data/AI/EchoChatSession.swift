import Foundation
import SwiftData

// MARK: - Chat Message Entity (child of session)

@Model
final class EchoChatMessageEntity {
    @Attribute(.unique) var id: UUID
    /// Role: "user", "assistant", "system"
    var role: String
    /// Message text content
    var content: String
    /// Timestamp for ordering
    var createdAt: Date
    /// Parent session
    var session: EchoChatSessionEntity?

    init(
        id: UUID = UUID(),
        role: String,
        content: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

// MARK: - Chat Session Entity

@Model
final class EchoChatSessionEntity {
    @Attribute(.unique) var id: UUID
    /// Display title (auto-generated or user-set)
    var title: String
    /// When this session was created
    var createdAt: Date
    /// When last message was sent
    var lastActiveAt: Date
    /// Whether this is a temporary (non-memory) session
    var isTemporary: Bool
    /// Messages in this session
    @Relationship(deleteRule: .cascade, inverse: \EchoChatMessageEntity.session)
    var messages: [EchoChatMessageEntity]

    init(
        id: UUID = UUID(),
        title: String = "",
        createdAt: Date = Date(),
        lastActiveAt: Date = Date(),
        isTemporary: Bool = false,
        messages: [EchoChatMessageEntity] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.lastActiveAt = lastActiveAt
        self.isTemporary = isTemporary
        self.messages = messages
    }

    // MARK: - Convenience

    /// Add a message to this session.
    func addMessage(role: EchoChatRole, content: String) {
        let entity = EchoChatMessageEntity(
            role: role.rawValue,
            content: content
        )
        entity.session = self
        messages.append(entity)
        lastActiveAt = Date()
    }

    /// Messages sorted by creation time (oldest first).
    var sortedMessages: [EchoChatMessageEntity] {
        messages.sorted { $0.createdAt < $1.createdAt }
    }

    /// Clear all messages from this session.
    func clearMessages() {
        messages.removeAll()
    }

    /// Convert stored messages to `EchoChatMessage` array for AI calls.
    func toChatMessages() -> [EchoChatMessage] {
        sortedMessages.compactMap { entity in
            guard let role = EchoChatRole(rawValue: entity.role) else { return nil }
            return EchoChatMessage(
                id: entity.id,
                role: role,
                content: entity.content,
                createdAt: entity.createdAt
            )
        }
    }
}
