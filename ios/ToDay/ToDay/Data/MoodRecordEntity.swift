import Foundation
import SwiftData

@Model
final class MoodRecordEntity {
    @Attribute(.unique) var id: UUID
    var moodRawValue: String
    var note: String
    var createdAt: Date
    var endedAt: Date?
    var isTracking: Bool
    var captureModeRawValue: String
    var photoAttachmentsData: Data

    init(record: MoodRecord) {
        id = record.id
        moodRawValue = record.mood.rawValue
        note = record.note
        createdAt = record.createdAt
        endedAt = record.endedAt
        isTracking = record.isTracking
        captureModeRawValue = record.captureMode.rawValue
        photoAttachmentsData = Self.encodeAttachments(record.photoAttachments)
    }

    func update(from record: MoodRecord) {
        moodRawValue = record.mood.rawValue
        note = record.note
        createdAt = record.createdAt
        endedAt = record.endedAt
        isTracking = record.isTracking
        captureModeRawValue = record.captureMode.rawValue
        photoAttachmentsData = Self.encodeAttachments(record.photoAttachments)
    }

    func toMoodRecord() -> MoodRecord {
        MoodRecord(
            id: id,
            mood: MoodRecord.Mood(rawValue: moodRawValue) ?? .calm,
            note: note,
            createdAt: createdAt,
            endedAt: endedAt,
            isTracking: isTracking,
            captureMode: MoodRecord.CaptureMode(rawValue: captureModeRawValue) ?? .point,
            photoAttachments: Self.decodeAttachments(photoAttachmentsData)
        )
    }

    private static func encodeAttachments(_ attachments: [MoodPhotoAttachment]) -> Data {
        (try? JSONEncoder().encode(attachments)) ?? Data()
    }

    private static func decodeAttachments(_ data: Data) -> [MoodPhotoAttachment] {
        guard !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([MoodPhotoAttachment].self, from: data)) ?? []
    }
}
