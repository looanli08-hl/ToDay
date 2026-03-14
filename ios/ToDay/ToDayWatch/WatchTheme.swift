import SwiftUI

enum WatchTheme {
    static let background = Color.black
    static let surface = Color(red: 0.11, green: 0.11, blue: 0.13)
    static let elevated = Color(red: 0.17, green: 0.17, blue: 0.20)
    static let elevatedSoft = Color(red: 0.21, green: 0.21, blue: 0.25)
    static let accent = Color(red: 0.81, green: 0.70, blue: 0.55)
    static let accentSoft = Color(red: 0.34, green: 0.30, blue: 0.24)
    static let teal = Color(red: 0.42, green: 0.73, blue: 0.65)
    static let tealSoft = Color(red: 0.19, green: 0.29, blue: 0.27)
    static let rose = Color(red: 0.86, green: 0.45, blue: 0.52)
    static let indigo = Color(red: 0.33, green: 0.40, blue: 0.74)
    static let text = Color.white
    static let textMuted = Color.white.opacity(0.68)
    static let textFaint = Color.white.opacity(0.42)
    static let border = Color.white.opacity(0.10)
    static let borderStrong = Color.white.opacity(0.18)

    static func eventCardBackground(for eventKind: String) -> LinearGradient {
        let colors: [Color]

        switch eventKind {
        case "sleep":
            colors = [Color(red: 0.13, green: 0.16, blue: 0.28), Color(red: 0.07, green: 0.10, blue: 0.19)]
        case "workout":
            colors = [Color(red: 0.86, green: 0.45, blue: 0.26), Color(red: 0.63, green: 0.24, blue: 0.16)]
        case "commute", "activeWalk":
            colors = [Color(red: 0.30, green: 0.55, blue: 0.36), Color(red: 0.16, green: 0.27, blue: 0.19)]
        case "quietTime":
            colors = [Color(red: 0.18, green: 0.18, blue: 0.20), Color(red: 0.09, green: 0.09, blue: 0.11)]
        case "mood":
            colors = [accentSoft, Color(red: 0.20, green: 0.16, blue: 0.13)]
        default:
            colors = [tealSoft, Color(red: 0.12, green: 0.19, blue: 0.18)]
        }

        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func eventGlow(for eventKind: String) -> Color {
        eventAccent(for: eventKind).opacity(0.26)
    }

    static func moodAccent(for mood: MoodRecord.Mood) -> Color {
        switch mood {
        case .happy:
            return Color(red: 0.96, green: 0.73, blue: 0.29)
        case .calm:
            return teal
        case .focused:
            return accent
        case .grateful:
            return Color(red: 0.86, green: 0.67, blue: 0.42)
        case .excited:
            return rose
        case .tired, .sleepy:
            return indigo
        case .anxious:
            return Color(red: 0.63, green: 0.56, blue: 0.89)
        case .sad:
            return Color(red: 0.41, green: 0.58, blue: 0.83)
        case .irritated:
            return Color(red: 0.88, green: 0.40, blue: 0.33)
        case .bored:
            return Color(red: 0.58, green: 0.58, blue: 0.62)
        case .satisfied:
            return Color(red: 0.78, green: 0.74, blue: 0.49)
        }
    }

    static func moodCardBackground(for mood: MoodRecord.Mood) -> LinearGradient {
        let accentColor = moodAccent(for: mood)
        return LinearGradient(
            colors: [accentColor.opacity(0.46), accentColor.opacity(0.18), surface],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func badgeText(for eventKind: String) -> String {
        switch eventKind {
        case "sleep":
            return "SLEEP"
        case "workout":
            return "WORKOUT"
        case "commute":
            return "COMMUTE"
        case "activeWalk":
            return "WALK"
        case "quietTime":
            return "BLANK"
        case "userAnnotated":
            return "NOTED"
        case "mood":
            return "MOOD"
        case "session":
            return "SESSION"
        default:
            return "LIVE"
        }
    }

    static func badgeFill(for eventKind: String) -> Color {
        switch eventKind {
        case "sleep":
            return Color.white.opacity(0.12)
        case "workout":
            return Color.white.opacity(0.18)
        case "commute", "activeWalk":
            return Color.white.opacity(0.14)
        case "quietTime":
            return Color.white.opacity(0.10)
        case "mood":
            return accent.opacity(0.26)
        default:
            return teal.opacity(0.28)
        }
    }

    static func eventAccent(for eventKind: String) -> Color {
        switch eventKind {
        case "sleep":
            return indigo
        case "workout":
            return Color(red: 0.92, green: 0.52, blue: 0.32)
        case "commute", "activeWalk":
            return teal
        case "quietTime":
            return Color.white.opacity(0.28)
        case "mood":
            return accent
        case "userAnnotated":
            return rose
        case "session":
            return accent
        default:
            return teal
        }
    }

    static func sourceFill(for source: WatchViewModel.TimelineDataSource) -> Color {
        switch source {
        case .phone:
            return teal
        case .local:
            return indigo
        case .sessionFallback:
            return accent
        case .waiting:
            return Color.white.opacity(0.14)
        }
    }

    static func sourceBackground(for source: WatchViewModel.TimelineDataSource) -> Color {
        sourceFill(for: source).opacity(0.18)
    }

    static func sourceIcon(for source: WatchViewModel.TimelineDataSource) -> String {
        switch source {
        case .phone:
            return "iphone"
        case .local:
            return "applewatch"
        case .sessionFallback:
            return "bolt.fill"
        case .waiting:
            return "hourglass"
        }
    }
}
