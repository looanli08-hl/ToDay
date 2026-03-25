import SwiftUI

enum TodayTheme {
    // MARK: - Core Colors (System)
    static let background = Color(UIColor.systemGroupedBackground)
    static let card = Color(UIColor.secondarySystemGroupedBackground)
    static let elevatedCard = Color(UIColor.tertiarySystemGroupedBackground)
    static let ink = Color.primary
    static let inkSoft = Color.secondary
    static let inkMuted = Color(UIColor.tertiaryLabel)
    static let inkFaint = Color(UIColor.quaternaryLabel)
    static let border = Color(UIColor.separator)
    static let accent = Color.accentColor
    static let accentSoft = Color.accentColor.opacity(0.12)

    // MARK: - Semantic Colors (Muted, refined)
    static let teal = Color(red: 0.32, green: 0.58, blue: 0.52)
    static let tealSoft = teal.opacity(0.10)
    static let rose = Color(red: 0.72, green: 0.44, blue: 0.44)
    static let roseSoft = rose.opacity(0.10)
    static let blue = Color(red: 0.44, green: 0.56, blue: 0.72)
    static let blueSoft = blue.opacity(0.10)
    static let purple = Color(red: 0.56, green: 0.44, blue: 0.72)
    static let purpleSoft = purple.opacity(0.10)
    static let orange = Color(red: 0.78, green: 0.52, blue: 0.30)
    static let orangeSoft = orange.opacity(0.10)

    // MARK: - Event-Specific Colors (Muted)
    static let scrollNight = Color(red: 0.14, green: 0.18, blue: 0.34)
    static let scrollSunrise = Color(red: 0.76, green: 0.50, blue: 0.32)
    static let scrollGold = Color(red: 0.84, green: 0.76, blue: 0.50)
    static let scrollNoon = Color(red: 0.68, green: 0.82, blue: 0.92)
    static let scrollSunset = Color(red: 0.80, green: 0.58, blue: 0.38)
    static let scrollViolet = Color(red: 0.34, green: 0.26, blue: 0.44)
    static let workoutOrange = Color(red: 0.78, green: 0.42, blue: 0.22)
    static let walkGreen = Color(red: 0.34, green: 0.58, blue: 0.42)
    static let sleepIndigo = Color(red: 0.28, green: 0.36, blue: 0.64)

    // MARK: - Utility
    static let glass = Color.white.opacity(0.18)
}

// MARK: - Reusable Components

struct ContentCard<Content: View>: View {
    let background: Color
    @ViewBuilder let content: Content

    init(
        background: Color = TodayTheme.card,
        @ViewBuilder content: () -> Content
    ) {
        self.background = background
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct EyebrowLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

struct SectionHeader: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

struct FlexibleBadgeRow: View {
    enum Tone {
        case accent
        case teal
    }

    let items: [String]
    let tone: Tone

    var body: some View {
        ViewThatFits(in: .vertical) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    badge(item)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    badge(item)
                }
            }
        }
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(badgeBackground)
            .clipShape(Capsule())
    }

    private var badgeBackground: Color {
        switch tone {
        case .accent:
            return TodayTheme.accentSoft
        case .teal:
            return TodayTheme.tealSoft
        }
    }
}
