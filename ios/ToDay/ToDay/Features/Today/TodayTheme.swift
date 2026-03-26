import SwiftUI

// ╔══════════════════════════════════════════════════════════════╗
// ║                    ToDay Design Tokens                       ║
// ║                                                              ║
// ║  所有 UI 代码只引用这些 Token，不直接写具体值。                    ║
// ║  换主题 = 换这一个文件。                                       ║
// ╚══════════════════════════════════════════════════════════════╝

// MARK: - 🎨 颜色 Token

enum AppColor {
    // 背景 — Warm-tinted (subtle warm hue instead of pure gray)
    static let background = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1) // warm dark
            : UIColor(red: 0.97, green: 0.96, blue: 0.94, alpha: 1) // warm cream
    })
    static let surface = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
            : UIColor(red: 1.0, green: 0.99, blue: 0.97, alpha: 1) // warm white
    })
    static let surfaceElevated = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.15, green: 0.15, blue: 0.16, alpha: 1)
            : UIColor(red: 0.98, green: 0.97, blue: 0.95, alpha: 1)
    })

    // 文字
    static let label = Color.primary
    static let labelSecondary = Color.secondary
    static let labelTertiary = Color(UIColor.tertiaryLabel)
    static let labelQuaternary = Color(UIColor.quaternaryLabel)

    // 分隔线
    static let separator = Color(UIColor.separator)

    // 强调色
    static let accent = Color.accentColor
    static let accentSoft = Color.accentColor.opacity(0.1)

    // 功能色（每种只用于特定语义）
    static let sleep = Color(red: 0.28, green: 0.36, blue: 0.64)
    static let workout = Color(red: 0.78, green: 0.42, blue: 0.22)
    static let walk = Color(red: 0.34, green: 0.58, blue: 0.42)
    static let mood = Color(red: 0.72, green: 0.44, blue: 0.44)
    static let shutter = Color(red: 0.74, green: 0.64, blue: 0.38)
    static let screen = Color(red: 0.56, green: 0.44, blue: 0.72)
    static let commute = Color(red: 0.44, green: 0.56, blue: 0.72)
    static let echo = Color(red: 0.32, green: 0.58, blue: 0.52)

    // 功能色的浅底（用于背景 tint）
    static func soft(_ color: Color) -> Color { color.opacity(0.1) }

    // 时间轴渐变色 — 柔和暖色调，与整体 UI 协调
    static let timelineNight = Color(red: 0.22, green: 0.24, blue: 0.30)
    static let timelineSunrise = Color(red: 0.92, green: 0.82, blue: 0.72)
    static let timelineGold = Color(red: 0.96, green: 0.92, blue: 0.84)
    static let timelineNoon = Color(red: 0.94, green: 0.95, blue: 0.92)
    static let timelineSunset = Color(red: 0.94, green: 0.86, blue: 0.78)
    static let timelineViolet = Color(red: 0.36, green: 0.34, blue: 0.40)
}

// MARK: - 🔤 字体 Token

enum AppFont {
    static let largeTitle = Font.largeTitle.bold()
    static let title = Font.title2.bold()
    static let headline = Font.headline
    static let body = Font.body
    static let subheadline = Font.subheadline
    static let caption = Font.caption
    static let captionBold = Font.caption.bold()
    static let mono = Font.system(.caption2, design: .monospaced)
}

// MARK: - 📐 间距 Token（基于 4pt 网格）

enum AppSpacing {
    static let xxxs: CGFloat = 2
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - 🔘 圆角 Token

enum AppRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
}

// MARK: - 🌫️ 阴影 Token

struct AppShadow: ViewModifier {
    enum Level { case subtle, elevated }
    let level: Level

    // Warm-tinted shadow instead of neutral gray
    private static let warmShadowColor = Color(red: 0.4, green: 0.3, blue: 0.2)

    func body(content: Content) -> some View {
        switch level {
        case .subtle:
            content.shadow(color: Self.warmShadowColor.opacity(0.06), radius: 8, x: 0, y: 2)
        case .elevated:
            content.shadow(color: Self.warmShadowColor.opacity(0.10), radius: 16, x: 0, y: 4)
        }
    }
}

extension View {
    func appShadow(_ level: AppShadow.Level = .subtle) -> some View {
        modifier(AppShadow(level: level))
    }
}

// ╔══════════════════════════════════════════════════════════════╗
// ║              向后兼容层（旧代码过渡用）                         ║
// ║                                                              ║
// ║  以下保留旧的 TodayTheme 属性名，映射到新 Token。               ║
// ║  新代码请直接用 AppColor / AppFont / AppSpacing。              ║
// ║  等全部迁移完后可以删掉这整个 section。                         ║
// ╚══════════════════════════════════════════════════════════════╝

enum TodayTheme {
    // 基础色 → AppColor
    static let background = AppColor.background
    static let card = AppColor.surface
    static let elevatedCard = AppColor.surfaceElevated
    static let ink = AppColor.label
    static let inkSoft = AppColor.labelSecondary
    static let inkMuted = AppColor.labelTertiary
    static let inkFaint = AppColor.labelQuaternary
    static let border = AppColor.separator
    static let accent = AppColor.accent
    static let accentSoft = AppColor.accentSoft

    // 功能色 → AppColor
    static let teal = AppColor.echo
    static let tealSoft = AppColor.soft(AppColor.echo)
    static let rose = AppColor.mood
    static let roseSoft = AppColor.soft(AppColor.mood)
    static let blue = AppColor.commute
    static let blueSoft = AppColor.soft(AppColor.commute)
    static let purple = AppColor.screen
    static let purpleSoft = AppColor.soft(AppColor.screen)
    static let orange = AppColor.workout
    static let orangeSoft = AppColor.soft(AppColor.workout)

    // 事件色 → AppColor
    static let scrollNight = AppColor.timelineNight
    static let scrollSunrise = AppColor.timelineSunrise
    static let scrollGold = AppColor.timelineGold
    static let scrollNoon = AppColor.timelineNoon
    static let scrollSunset = AppColor.timelineSunset
    static let scrollViolet = AppColor.timelineViolet
    static let workoutOrange = AppColor.workout
    static let walkGreen = AppColor.walk
    static let sleepIndigo = AppColor.sleep

    // 其他
    static let glass = Color.white.opacity(0.18)
}

// MARK: - 📦 可复用组件

struct ContentCard<Content: View>: View {
    let background: Color
    @ViewBuilder let content: Content

    init(
        background: Color = AppColor.surface,
        @ViewBuilder content: () -> Content
    ) {
        self.background = background
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            content
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
    }
}

struct EyebrowLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(AppFont.caption)
            .foregroundStyle(AppColor.labelSecondary)
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
            .font(AppFont.caption)
            .foregroundStyle(AppColor.labelSecondary)
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
            HStack(spacing: AppSpacing.xs) {
                ForEach(items, id: \.self) { item in
                    badge(item)
                }
            }

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                ForEach(items, id: \.self) { item in
                    badge(item)
                }
            }
        }
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(AppFont.caption)
            .foregroundStyle(AppColor.labelSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tone == .accent ? AppColor.accentSoft : AppColor.soft(AppColor.echo))
            .clipShape(Capsule())
    }
}
