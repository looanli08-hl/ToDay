import Foundation

// MARK: - Message Type

enum EchoMessageType: String, Codable, CaseIterable, Sendable {
    case dailyInsight   // 每日洞察
    case shutterEcho    // 快门回响
    case thoughtOrg     // 想法整理
    case emotionCare    // 情绪关怀
    case todoReminder   // 待办提醒
    case mirrorUpdate   // 镜子更新
    case freeChat       // 自由对话

    var icon: String {
        switch self {
        case .dailyInsight:  return "🌿"
        case .shutterEcho:   return "🌟"
        case .thoughtOrg:    return "💭"
        case .emotionCare:   return "🤗"
        case .todoReminder:  return "⏰"
        case .mirrorUpdate:  return "🪞"
        case .freeChat:      return "✨"
        }
    }

    var defaultTitle: String {
        switch self {
        case .dailyInsight:  return "今日洞察"
        case .shutterEcho:   return "快门回响"
        case .thoughtOrg:    return "想法整理"
        case .emotionCare:   return "Echo 想跟你说"
        case .todoReminder:  return "待办提醒"
        case .mirrorUpdate:  return "我对你有了新的了解"
        case .freeChat:      return "随便聊聊"
        }
    }
}

// MARK: - Source Type

enum EchoSourceType: String, Codable, Sendable {
    case shutterRecord   // 关联快门记录
    case dateRange       // 关联时间段
    case moodTrend       // 近期心情趋势
    case userProfile     // 用户画像
    case todayData       // 今日数据
}

// MARK: - Source Data

struct EchoSourceData: Codable, Hashable, Sendable {
    let type: EchoSourceType
    let shutterRecordIDs: [UUID]?
    let dateRangeStart: Date?
    let dateRangeEnd: Date?
    let sourceDescription: String

    init(
        type: EchoSourceType,
        shutterRecordIDs: [UUID]? = nil,
        dateRangeStart: Date? = nil,
        dateRangeEnd: Date? = nil,
        sourceDescription: String
    ) {
        self.type = type
        self.shutterRecordIDs = shutterRecordIDs
        self.dateRangeStart = dateRangeStart
        self.dateRangeEnd = dateRangeEnd
        self.sourceDescription = sourceDescription
    }
}
