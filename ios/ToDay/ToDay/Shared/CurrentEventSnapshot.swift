import Foundation

enum SharedAppGroup {
    static let identifier = "group.com.looanli.today"
    static let currentEventSnapshotKey = "currentEventSnapshot"
    static let dailySummaryKey = "dailySummary"
}

struct CurrentEventSnapshot: Codable, Hashable, Sendable {
    let eventName: String
    let eventKind: String
    let startDate: Date
    let durationMinutes: Int
    let iconName: String
}

struct DailySummarySnapshot: Codable, Hashable, Sendable {
    let exerciseMinutes: Int
    let moodCount: Int
    let eventCount: Int
}
