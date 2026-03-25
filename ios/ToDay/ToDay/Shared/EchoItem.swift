import Foundation

enum EchoStatus: String, Codable, CaseIterable, Sendable {
    case pending   // scheduled, not yet shown
    case viewed    // user has seen it
    case dismissed // user explicitly dismissed
    case snoozed   // user chose to see later
}

struct EchoItem: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let shutterRecordID: UUID
    let scheduledDate: Date
    var status: EchoStatus
    let reminderDayOffset: Int   // 1, 3, 7, or 30
    let createdAt: Date

    init(
        id: UUID = UUID(),
        shutterRecordID: UUID,
        scheduledDate: Date,
        status: EchoStatus = .pending,
        reminderDayOffset: Int,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.shutterRecordID = shutterRecordID
        self.scheduledDate = scheduledDate
        self.status = status
        self.reminderDayOffset = reminderDayOffset
        self.createdAt = createdAt
    }

    /// Human-readable label for how long ago the original record was captured
    var offsetLabel: String {
        switch reminderDayOffset {
        case 1:  return "1 天前"
        case 3:  return "3 天前"
        case 7:  return "1 周前"
        case 30: return "1 个月前"
        default: return "\(reminderDayOffset) 天前"
        }
    }
}
