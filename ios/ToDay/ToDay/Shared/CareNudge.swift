import Foundation

enum CareNudgeKind: String, Codable, CaseIterable, Sendable {
    case exerciseStreak    // consecutive workout days
    case highScreenTime    // screen time above threshold
    case noShutterCheckIn  // no shutter records for days
}

struct CareNudge: Identifiable, Hashable, Sendable {
    let id: UUID
    let kind: CareNudgeKind
    let message: String
    let subtitle: String?
    let iconName: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        kind: CareNudgeKind,
        message: String,
        subtitle: String? = nil,
        iconName: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.message = message
        self.subtitle = subtitle
        self.iconName = iconName
        self.createdAt = createdAt
    }
}
