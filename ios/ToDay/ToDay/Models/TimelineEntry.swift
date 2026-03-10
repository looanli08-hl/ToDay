import Foundation

struct TimelineMoment: Hashable {
    let label: String
    let startMinuteOfDay: Int
    let endMinuteOfDay: Int?

    static func point(at minute: Int) -> TimelineMoment {
        TimelineMoment(
            label: Self.format(minute: minute),
            startMinuteOfDay: minute,
            endMinuteOfDay: nil
        )
    }

    static func range(startMinuteOfDay: Int, endMinuteOfDay: Int) -> TimelineMoment {
        TimelineMoment(
            label: "\(Self.format(minute: startMinuteOfDay)) - \(Self.format(minute: endMinuteOfDay))",
            startMinuteOfDay: startMinuteOfDay,
            endMinuteOfDay: endMinuteOfDay
        )
    }

    static let overnight = TimelineMoment(
        label: "昨夜",
        startMinuteOfDay: 0,
        endMinuteOfDay: nil
    )

    static let daytime = TimelineMoment(
        label: "今天",
        startMinuteOfDay: 12 * 60,
        endMinuteOfDay: nil
    )

    private static func format(minute: Int) -> String {
        let normalized = max(0, min(minute, 24 * 60 - 1))
        let hour = normalized / 60
        let minuteValue = normalized % 60
        return String(format: "%02d:%02d", hour, minuteValue)
    }
}

struct TimelineEntry: Identifiable, Hashable {
    enum Kind: String, Hashable {
        case sleep
        case move
        case focus
        case pause
        case mood
    }

    let id: String
    let title: String
    let detail: String
    let moment: TimelineMoment
    let kind: Kind
}

extension TimelineEntry {
    static let previewData: [TimelineEntry] = [
        TimelineEntry(
            id: "preview-sleep",
            title: "睡眠",
            detail: "昨晚大约睡了 7 小时 18 分，醒来后的状态比较平稳。",
            moment: .range(startMinuteOfDay: 12, endMinuteOfDay: 450),
            kind: .sleep
        ),
        TimelineEntry(
            id: "preview-move",
            title: "移动",
            detail: "早上通勤走了不少路，整段出门节奏比较流动。",
            moment: .range(startMinuteOfDay: 490, endMinuteOfDay: 545),
            kind: .move
        ),
        TimelineEntry(
            id: "preview-focus",
            title: "专注",
            detail: "上午有一段较完整的专注时间，干扰明显变少。",
            moment: .range(startMinuteOfDay: 600, endMinuteOfDay: 700),
            kind: .focus
        ),
        TimelineEntry(
            id: "preview-pause",
            title: "停顿",
            detail: "下午整体动作不多，还没有补手动记录。",
            moment: .range(startMinuteOfDay: 1000, endMinuteOfDay: 1090),
            kind: .pause
        )
    ]
}
