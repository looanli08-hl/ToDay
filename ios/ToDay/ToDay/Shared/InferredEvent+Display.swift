import Foundation

extension InferredEvent {
    /// Short badge title for the event kind, used in timeline and AI prompts.
    var kindBadgeTitle: String {
        switch kind {
        case .sleep:         return "睡眠"
        case .workout:       return "运动"
        case .commute:       return "通勤"
        case .activeWalk:    return "步行"
        case .quietTime:     return "安静"
        case .userAnnotated: return "标注"
        case .mood:          return "心情"
        case .shutter:       return "快门"
        case .screenTime:    return "屏幕"
        case .spending:      return "消费"
        case .dataGap:       return "空白"
        }
    }

    /// Human-readable duration text for scroll display.
    var scrollDurationText: String {
        let minutes = Int(duration / 60)
        if minutes < 1 { return "瞬时" }
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours > 0 {
            return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
        }
        return "\(minutes)m"
    }
}
