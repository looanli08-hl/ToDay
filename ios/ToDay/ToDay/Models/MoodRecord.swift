import Foundation

struct MoodRecord: Identifiable {
    enum Mood: String, CaseIterable, Identifiable {
        case happy = "开心"
        case calm = "平静"
        case tired = "疲惫"
        case irritated = "烦躁"
        case focused = "专注"
        case zoning = "放空"

        var id: String { rawValue }

        var emoji: String {
            switch self {
            case .happy: return "😊"
            case .calm: return "🌿"
            case .tired: return "😴"
            case .irritated: return "😤"
            case .focused: return "🎯"
            case .zoning: return "☁️"
            }
        }

        var timelineKind: TimelineEntry.Kind {
            switch self {
            case .happy, .calm: return .mood
            case .tired, .zoning: return .pause
            case .irritated: return .mood
            case .focused: return .focus
            }
        }
    }

    let id: UUID
    let mood: Mood
    let note: String
    let createdAt: Date

    init(mood: Mood, note: String = "", createdAt: Date = Date()) {
        self.id = UUID()
        self.mood = mood
        self.note = note
        self.createdAt = createdAt
    }

    func toTimelineEntry() -> TimelineEntry {
        let detail = note.isEmpty
            ? "\(mood.emoji) \(mood.rawValue)"
            : "\(mood.emoji) \(mood.rawValue) — \(note)"

        let timeString = createdAt.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute())

        return TimelineEntry(
            title: mood.rawValue,
            detail: detail,
            timeRange: timeString,
            kind: mood.timelineKind
        )
    }
}
