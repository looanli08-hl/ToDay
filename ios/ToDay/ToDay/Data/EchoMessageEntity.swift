import Foundation
import SwiftData

@Model
final class EchoMessageEntity {
    @Attribute(.unique) var id: UUID
    /// Raw value of EchoMessageType
    var type: String
    /// Message title
    var title: String
    /// Content preview (first ~2 lines)
    var preview: String
    /// Human-readable source label, e.g. "来自：今日数据"
    var sourceDescription: String
    /// JSON-encoded EchoSourceData for passing to AI context
    var sourceDataJSON: Data?
    /// When this message was created
    var createdAt: Date
    /// Whether the user has opened this message
    var isRead: Bool
    /// ID of the associated EchoChatSessionEntity for the conversation thread
    var threadId: UUID

    init(
        id: UUID = UUID(),
        type: String,
        title: String,
        preview: String,
        sourceDescription: String,
        sourceDataJSON: Data? = nil,
        isRead: Bool = false,
        threadId: UUID,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.preview = preview
        self.sourceDescription = sourceDescription
        self.sourceDataJSON = sourceDataJSON
        self.isRead = isRead
        self.threadId = threadId
        self.createdAt = createdAt
    }

    // MARK: - Convenience

    /// Decoded message type enum.
    var messageType: EchoMessageType {
        EchoMessageType(rawValue: type) ?? .freeChat
    }

    /// Decoded source data (nil if sourceDataJSON is nil or corrupt).
    var sourceData: EchoSourceData? {
        guard let data = sourceDataJSON else { return nil }
        return try? JSONDecoder().decode(EchoSourceData.self, from: data)
    }
}
