import Foundation
import SwiftData

@Model
final class CustomMoodEntity {
    var id: UUID
    var emoji: String
    var name: String
    var sortOrder: Int
    var createdAt: Date

    init(id: UUID = UUID(), emoji: String, name: String, sortOrder: Int, createdAt: Date = Date()) {
        self.id = id
        self.emoji = emoji
        self.name = name
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}

extension CustomMoodEntity {
    static let defaults: [(emoji: String, name: String)] = [
        ("😊", "开心"),
        ("🌿", "平静"),
        ("🎯", "专注"),
        ("😴", "疲惫"),
        ("😔", "难过"),
        ("☺️", "满足"),
    ]

    static func seedDefaultsIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<CustomMoodEntity>(sortBy: [SortDescriptor(\.sortOrder)])
        guard let existing = try? context.fetch(descriptor), existing.isEmpty else { return }
        for (index, mood) in defaults.enumerated() {
            context.insert(CustomMoodEntity(emoji: mood.emoji, name: mood.name, sortOrder: index))
        }
        try? context.save()
    }
}
