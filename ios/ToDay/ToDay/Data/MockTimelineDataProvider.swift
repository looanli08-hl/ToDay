import Foundation

struct MockTimelineDataProvider: TimelineDataProviding {
    let source: TimelineSource = .mock

    func loadTimeline(for date: Date) async throws -> DayTimeline {
        DayTimeline(
            date: date,
            summary: "A simulator-safe version of today. Use this to shape the product before you have a real device.",
            source: source,
            stats: [
                TimelineStat(title: "Records", value: "4"),
                TimelineStat(title: "Notes", value: "1"),
                TimelineStat(title: "Mode", value: "Local")
            ],
            entries: TimelineEntry.previewData
        )
    }
}
