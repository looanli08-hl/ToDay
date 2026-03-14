import Foundation

enum SharedAppGroup {
    static let identifier = "group.com.looanli.today"
    static let currentEventSnapshotKey = "currentEventSnapshot"
    static let watchTimelineSnapshotKey = "watchTimelineSnapshot"
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

struct WatchTimelineSnapshot: Codable, Hashable, Sendable {
    let date: Date
    let summary: String
    let sourceRawValue: String
    let generatedAt: Date
    let events: [WatchTimelineEventSnapshot]
}

struct WatchTimelineEventSnapshot: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let kindRawValue: String
    let startDate: Date
    let endDate: Date
    let displayName: String
    let userAnnotation: String?
    let confidenceRawValue: Int
    let isLive: Bool

    var resolvedName: String {
        userAnnotation ?? displayName
    }

    init(event: InferredEvent) {
        id = event.id
        kindRawValue = event.kind.rawValue
        startDate = event.startDate
        endDate = event.endDate
        displayName = event.displayName
        userAnnotation = event.userAnnotation
        confidenceRawValue = event.confidence.rawValue
        isLive = event.isLive
    }
}
