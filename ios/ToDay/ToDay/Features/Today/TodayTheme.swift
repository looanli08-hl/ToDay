import SwiftUI

enum TodayTheme {
    static let background = dynamicColor(light: 0xFAFAF8, dark: 0x111412)
    static let card = dynamicColor(light: 0xFFFFFF, dark: 0x1A1E1B)
    static let elevatedCard = dynamicColor(light: 0xF3EFE7, dark: 0x202622)
    static let ink = dynamicColor(light: 0x1A1A1A, dark: 0xF4F2ED)
    static let inkSoft = dynamicColor(light: 0x3D3D3D, dark: 0xD8D3CC)
    static let inkMuted = dynamicColor(light: 0x8A8A8A, dark: 0xA9A49C)
    static let inkFaint = dynamicColor(light: 0xB8B8B8, dark: 0x6A6F6A)
    static let border = dynamicColor(light: 0xE2E0DC, dark: 0x313731)
    static let accent = dynamicColor(light: 0xC59661, dark: 0xD9B27E)
    static let accentSoft = dynamicColor(light: 0xF5E9D8, dark: 0x3A2E20)
    static let teal = dynamicColor(light: 0x5B9A8B, dark: 0x7CC1AF)
    static let tealSoft = dynamicColor(light: 0xE4F2EE, dark: 0x20352F)
    static let rose = dynamicColor(light: 0xC97B7B, dark: 0xD89898)
    static let roseSoft = dynamicColor(light: 0xF7E7E7, dark: 0x392526)
    static let blue = dynamicColor(light: 0x7B9CC9, dark: 0x9AB7DD)
    static let blueSoft = dynamicColor(light: 0xE8EFF9, dark: 0x223043)
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
                .stroke(TodayTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
