import Foundation

struct TimelineEntry: Identifiable {
    enum Kind: String {
        case sleep
        case move
        case focus
        case pause
        case mood
    }

    let id = UUID()
    let title: String
    let detail: String
    let timeRange: String
    let kind: Kind
}

extension TimelineEntry {
    static let previewData: [TimelineEntry] = [
        TimelineEntry(
            title: "Sleep",
            detail: "7h 18m asleep, wake-up felt steady.",
            timeRange: "00:12 - 07:30",
            kind: .sleep
        ),
        TimelineEntry(
            title: "Move",
            detail: "Walked to the subway and stayed active through the commute.",
            timeRange: "08:10 - 09:05",
            kind: .move
        ),
        TimelineEntry(
            title: "Focus",
            detail: "A quieter block with fewer interruptions.",
            timeRange: "10:00 - 11:40",
            kind: .focus
        ),
        TimelineEntry(
            title: "Pause",
            detail: "Low movement, no manual notes yet.",
            timeRange: "16:40 - 18:10",
            kind: .pause
        )
    ]
}
