import Foundation

struct DayTimeline {
    let date: Date
    let summary: String
    let source: TimelineSource
    let stats: [TimelineStat]
    let entries: [InferredEvent]
}

enum TimelineSource: String {
    case mock
    case healthKit

    var badgeTitle: String {
        switch self {
        case .mock:
            return "模拟"
        case .healthKit:
            return "HealthKit"
        }
    }

    var helperText: String {
        switch self {
        case .mock:
            return "当前是模拟模式，适合先把记录、回看和付费路径做顺。"
        case .healthKit:
            return "正在读取这台设备上的 HealthKit 数据。"
        }
    }
}

struct TimelineStat: Identifiable {
    let id: String
    let title: String
    let value: String

    init(id: String? = nil, title: String, value: String) {
        self.id = id ?? title
        self.title = title
        self.value = value
    }
}
