import Foundation
import SwiftData

@Model
final class EchoItemEntity {
    @Attribute(.unique) var id: UUID
    var shutterRecordID: UUID
    var scheduledDate: Date
    var statusRawValue: String
    var reminderDayOffset: Int
    var createdAt: Date

    init(item: EchoItem) {
        id = item.id
        shutterRecordID = item.shutterRecordID
        scheduledDate = item.scheduledDate
        statusRawValue = item.status.rawValue
        reminderDayOffset = item.reminderDayOffset
        createdAt = item.createdAt
    }

    func update(from item: EchoItem) {
        shutterRecordID = item.shutterRecordID
        scheduledDate = item.scheduledDate
        statusRawValue = item.status.rawValue
        reminderDayOffset = item.reminderDayOffset
        createdAt = item.createdAt
    }

    func toEchoItem() -> EchoItem {
        EchoItem(
            id: id,
            shutterRecordID: shutterRecordID,
            scheduledDate: scheduledDate,
            status: EchoStatus(rawValue: statusRawValue) ?? .pending,
            reminderDayOffset: reminderDayOffset,
            createdAt: createdAt
        )
    }
}
