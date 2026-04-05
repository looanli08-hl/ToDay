import SwiftUI

// MARK: - Color Tokens

enum AppColor {
    // Surfaces
    static let background = Color(light: .init(hex: 0xF7F5F0), dark: .init(hex: 0x121213))
    static let surface = Color(light: .init(hex: 0xFFFDF7), dark: .init(hex: 0x1C1C1E))
    static let surfaceElevated = Color(light: .init(hex: 0xF9F7F2), dark: .init(hex: 0x272728))

    // Accent — reserved for exactly 5 elements
    static let accent = Color(light: .init(hex: 0x5B9A8B), dark: .init(hex: 0x7CC1AF))

    // Labels — warm-tinted, never pure gray
    static let label = Color(light: .init(red: 0.12, green: 0.1, blue: 0.08, alpha: 1),
                             dark: .init(red: 0.92, green: 0.9, blue: 0.86, alpha: 1))
    static let labelSecondary = Color(light: .init(red: 0.36, green: 0.32, blue: 0.28, alpha: 1),
                                      dark: .init(red: 0.72, green: 0.68, blue: 0.62, alpha: 1))
    static let labelTertiary = Color(light: .init(red: 0.52, green: 0.48, blue: 0.42, alpha: 1),
                                     dark: .init(red: 0.56, green: 0.52, blue: 0.48, alpha: 1))
    static let labelQuaternary = Color(light: .init(red: 0.66, green: 0.62, blue: 0.56, alpha: 1),
                                       dark: .init(red: 0.42, green: 0.39, blue: 0.36, alpha: 1))

    // Semantic event colors
    static let sleep = Color(red: 0.29, green: 0.36, blue: 0.64)       // #4A5CA4
    static let workout = Color(red: 0.78, green: 0.42, blue: 0.22)     // #C76B38
    static let walk = Color(red: 0.34, green: 0.48, blue: 0.42)        // #577A6A
    static let mood = Color(red: 0.72, green: 0.44, blue: 0.44)        // #B87070
    static let shutter = Color(red: 0.74, green: 0.64, blue: 0.38)     // #BDA360
    static let screen = Color(red: 0.56, green: 0.44, blue: 0.72)      // #8F70B8
    static let commute = Color(red: 0.44, green: 0.56, blue: 0.72)     // #708FB8
    static let echo = Color(red: 0.32, green: 0.47, blue: 0.34)        // #527957

    // Timeline gradient
    static let timelineNight = Color(hex: 0xD1C7BD)
    static let timelineSunrise = Color(hex: 0xEBDECE)
    static let timelineGold = Color(hex: 0xF5EDDC)
    static let timelineNoon = Color(hex: 0xF8F2E8)
    static let timelineSunset = Color(hex: 0xF0E0D0)
    static let timelineViolet = Color(hex: 0xDBD0C6)

    // Separator
    static let separator = Color(UIColor.separator)

    // MARK: - Event Kind Color Mapping

    static func color(for kind: EventKind) -> Color {
        switch kind {
        case .sleep:         return sleep
        case .workout:       return workout
        case .commute:       return commute
        case .activeWalk:    return walk
        case .quietTime:     return labelTertiary
        case .userAnnotated: return accent
        case .mood:          return mood
        case .shutter:       return shutter
        case .screenTime:    return screen
        case .spending:      return shutter
        case .dataGap:       return labelQuaternary
        }
    }
}

// MARK: - Spacing Tokens (4pt grid)

enum AppSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Radius Tokens

enum AppRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
}

// MARK: - Shadow Modifier

enum AppShadowLevel {
    case subtle
    case elevated
}

struct AppShadow: ViewModifier {
    let level: AppShadowLevel

    private var color: Color {
        Color(red: 0.4, green: 0.3, blue: 0.2)
    }

    func body(content: Content) -> some View {
        switch level {
        case .subtle:
            content.shadow(color: color.opacity(0.06), radius: 8, x: 0, y: 2)
        case .elevated:
            content.shadow(color: color.opacity(0.10), radius: 16, x: 0, y: 4)
        }
    }
}

extension View {
    func appShadow(_ level: AppShadowLevel) -> some View {
        modifier(AppShadow(level: level))
    }
}

// MARK: - Typography

enum AppFont {
    /// 33pt regular serif italic — screen title only
    static func hero() -> Font {
        .system(size: 33, weight: .regular, design: .serif).italic()
    }

    /// 23pt regular serif italic — card titles, section headings
    static func heading() -> Font {
        .system(size: 23, weight: .regular, design: .serif).italic()
    }

    /// 15pt semibold default — event names, body text
    static func body() -> Font {
        .system(size: 15, weight: .semibold, design: .default)
    }

    /// 15pt regular default — AI summary, descriptive body
    static func bodyRegular() -> Font {
        .system(size: 15, weight: .regular, design: .default)
    }

    /// 12pt regular monospaced — timestamps, badges, duration
    static func small() -> Font {
        .system(size: 12, weight: .regular, design: .monospaced)
    }

    /// 12pt semibold monospaced — badge labels
    static func smallBold() -> Font {
        .system(size: 12, weight: .semibold, design: .monospaced)
    }
}

// MARK: - Text Style Modifiers

extension View {
    func heroStyle() -> some View {
        self.font(AppFont.hero())
            .foregroundStyle(AppColor.label)
            .lineSpacing(33 * 0.1)
    }

    func headingStyle() -> some View {
        self.font(AppFont.heading())
            .foregroundStyle(AppColor.label)
            .lineSpacing(23 * 0.15)
    }

    func bodyStyle() -> some View {
        self.font(AppFont.body())
            .foregroundStyle(AppColor.label)
            .lineSpacing(15 * 0.4)
    }

    func smallStyle() -> some View {
        self.font(AppFont.small())
            .foregroundStyle(AppColor.labelTertiary)
    }
}

// MARK: - Color Helpers

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }

    init(light: UIColor, dark: UIColor) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

extension UIColor {
    convenience init(hex: UInt, alpha: CGFloat = 1.0) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: alpha
        )
    }
}
