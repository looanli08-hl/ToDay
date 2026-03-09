import Foundation

struct DayTimeline {
    let date: Date
    let summary: String
    let source: TimelineSource
    let stats: [TimelineStat]
    let entries: [TimelineEntry]
}

enum TimelineSource: String {
    case mock
    case healthKit

    var badgeTitle: String {
        switch self {
        case .mock:
            return "Mock"
        case .healthKit:
            return "HealthKit"
        }
    }

    var helperText: String {
        switch self {
        case .mock:
            return "You are in simulator-safe mode. Build the product flow first, then swap to HealthKit on a real iPhone."
        case .healthKit:
            return "Reading from HealthKit on this device."
        }
    }
}

struct TimelineStat: Identifiable {
    let id = UUID()
    let title: String
    let value: String
}
