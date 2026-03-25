import SwiftUI

enum TodayTheme {
    // MARK: - Nature Palette (Default)

    static let background = dynamicColor(light: 0xF4F7F0, dark: 0x1A1F16)
    static let card = dynamicColor(light: 0xFAFCF7, dark: 0x232820)
    static let elevatedCard = dynamicColor(light: 0xEDF2E6, dark: 0x2A3024)
    static let surface = dynamicColor(light: 0xF0F4EB, dark: 0x262C20)
    static let ink = dynamicColor(light: 0x2C3325, dark: 0xE8EDE0)
    static let inkSoft = dynamicColor(light: 0x4A5540, dark: 0xC8D0BC)
    static let inkMuted = dynamicColor(light: 0x6B7A5E, dark: 0x9BA88E)
    static let inkFaint = dynamicColor(light: 0x9BA88E, dark: 0x5A6650)
    static let border = dynamicColor(light: 0xD6DEC8, dark: 0x333D2C)
    static let accent = dynamicColor(light: 0x7C8B6F, dark: 0xA8B89A)
    static let accentSoft = dynamicColor(light: 0xECF0DE, dark: 0x2E3322)
    static let accentWarm = dynamicColor(light: 0xB5C18E, dark: 0xCBD6A4)
    static let teal = dynamicColor(light: 0x7C8B6F, dark: 0xA8B89A)
    static let tealSoft = dynamicColor(light: 0xE8EFE0, dark: 0x232B1E)
    static let rose = dynamicColor(light: 0xC4896B, dark: 0xD9A88A)
    static let roseSoft = dynamicColor(light: 0xF5E8DE, dark: 0x3A2A20)
    static let blue = dynamicColor(light: 0x7BA3C4, dark: 0x9BBDDB)
    static let blueSoft = dynamicColor(light: 0xE4EEF6, dark: 0x22303E)
    static let scrollNight = dynamicColor(light: 0x2C3325, dark: 0x1A1F16)
    static let scrollSunrise = dynamicColor(light: 0xC4896B, dark: 0xA06840)
    static let scrollGold = dynamicColor(light: 0xC4A84B, dark: 0xA08838)
    static let scrollNoon = dynamicColor(light: 0xA8B89A, dark: 0x4A5A40)
    static let scrollSunset = dynamicColor(light: 0xC4896B, dark: 0x9A6840)
    static let scrollViolet = dynamicColor(light: 0x6B7A5E, dark: 0x3A4532)
    static let workoutOrange = dynamicColor(light: 0xC4896B, dark: 0xD9A88A)
    static let walkGreen = dynamicColor(light: 0x7C8B6F, dark: 0xA8B89A)
    static let sleepIndigo = dynamicColor(light: 0x7BA3C4, dark: 0x9BBDDB)
    static let purple = dynamicColor(light: 0x8B7FA0, dark: 0xADA3BF)
    static let purpleSoft = dynamicColor(light: 0xEDE8F4, dark: 0x2D2838)
    static let orange = dynamicColor(light: 0xC4896B, dark: 0xD9A88A)
    static let orangeSoft = dynamicColor(light: 0xF5E8DE, dark: 0x3A2A20)
    static let gold = dynamicColor(light: 0xC4A84B, dark: 0xD4BA60)
    static let glass = Color.white.opacity(0.18)
}

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
        VStack(alignment: .leading, spacing: 14) {
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(TodayTheme.border.opacity(0.5), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color(red: 0.17, green: 0.20, blue: 0.15).opacity(0.06), radius: 16, x: 0, y: 4)
    }
}

struct EyebrowLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(TodayTheme.inkMuted)
            .tracking(2.4)
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
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(TodayTheme.inkSoft)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(background)
            .clipShape(Capsule())
    }

    private var background: Color {
        switch tone {
        case .accent:
            return TodayTheme.accentSoft
        case .teal:
            return TodayTheme.tealSoft
        }
    }
}

private func dynamicColor(light: UInt32, dark: UInt32) -> Color {
    Color(
        uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        }
    )
}

private extension UIColor {
    convenience init(hex: UInt32) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}
