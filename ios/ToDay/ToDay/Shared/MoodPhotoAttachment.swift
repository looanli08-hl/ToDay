import Foundation

struct MoodPhotoAttachment: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let filename: String
    let createdAt: Date

    init(id: UUID = UUID(), filename: String, createdAt: Date = Date()) {
        self.id = id
        self.filename = filename
        self.createdAt = createdAt
    }
}

// MARK: - Photo Library Helper

enum MoodPhotoLibrary {
    private static var photosDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MoodPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func url(for attachment: MoodPhotoAttachment) -> URL {
        photosDirectory.appendingPathComponent(attachment.filename)
    }

    static func deletePhotos(for attachments: [MoodPhotoAttachment]) {
        let fm = FileManager.default
        for attachment in attachments {
            let fileURL = url(for: attachment)
            try? fm.removeItem(at: fileURL)
        }
    }
}
