import Foundation

struct MockTimelineDataProvider: TimelineDataProviding {
    let source: TimelineSource = .mock

    func loadTimeline(for date: Date) async throws -> DayTimeline {
        DayTimeline(
            date: date,
            summary: "这是一个适合在模拟器里推进产品形态的今天，用来先验证记录、回看和总结体验。",
            source: source,
            stats: [
                TimelineStat(title: "模式", value: "本地"),
                TimelineStat(title: "阶段", value: "验证中"),
                TimelineStat(title: "下一步", value: "总结")
            ],
            entries: TimelineEntry.previewData
        )
    }
}
