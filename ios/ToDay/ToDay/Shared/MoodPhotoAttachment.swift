import Foundation

struct MoodPhotoAttachment: Identifiable, Codable, Hashable {
    let id: UUID
    let filename: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        filename: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.filename = filename
        self.createdAt = createdAt
    }
}
