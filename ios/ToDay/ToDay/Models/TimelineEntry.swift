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
    var startMinuteOfDay: Int {
        if let minute = Self.firstMinuteMatch(in: timeRange) {
            return minute
        }

        switch timeRange {
        case let value where value.contains("昨夜"):
            return 0
        case let value where value.contains("今天"):
            return 12 * 60
        default:
            return 12 * 60
        }
    }

    static let previewData: [TimelineEntry] = [
        TimelineEntry(
            title: "睡眠",
            detail: "昨晚大约睡了 7 小时 18 分，醒来后的状态比较平稳。",
            timeRange: "00:12 - 07:30",
            kind: .sleep
        ),
        TimelineEntry(
            title: "移动",
            detail: "早上通勤走了不少路，整段出门节奏比较流动。",
            timeRange: "08:10 - 09:05",
            kind: .move
        ),
        TimelineEntry(
            title: "专注",
            detail: "上午有一段较完整的专注时间，干扰明显变少。",
            timeRange: "10:00 - 11:40",
            kind: .focus
        ),
        TimelineEntry(
            title: "停顿",
            detail: "下午整体动作不多，还没有补手动记录。",
            timeRange: "16:40 - 18:10",
            kind: .pause
        )
    ]

    private static func firstMinuteMatch(in text: String) -> Int? {
        let candidates = text.split(whereSeparator: { !$0.isNumber && $0 != ":" })

        for candidate in candidates {
            let pieces = candidate.split(separator: ":")
            guard pieces.count == 2,
                  let hour = Int(pieces[0]),
                  let minute = Int(pieces[1]) else {
                continue
            }

            return (hour * 60) + minute
        }

        return nil
    }
}
