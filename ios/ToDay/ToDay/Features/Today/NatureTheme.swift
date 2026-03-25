import SwiftUI

/// Original nature-inspired color palette preserved as a reference.
/// The active theme is defined in TodayTheme.swift.
enum NatureTheme {
    // MARK: - Core Palette

    static let background = natureDynamic(light: 0xF4F7F0, dark: 0x1A1F16)
    static let card = natureDynamic(light: 0xFAFCF7, dark: 0x232820)
    static let elevatedCard = natureDynamic(light: 0xEDF2E6, dark: 0x2A3024)
    static let ink = natureDynamic(light: 0x2C3325, dark: 0xE8EDE0)
    static let inkSoft = natureDynamic(light: 0x4A5540, dark: 0xC8D0BC)
    static let inkMuted = natureDynamic(light: 0x6B7A5E, dark: 0x9BA88E)
    static let inkFaint = natureDynamic(light: 0x9BA88E, dark: 0x5A6650)
    static let border = natureDynamic(light: 0xD6DEC8, dark: 0x333D2C)
    static let accent = natureDynamic(light: 0xB5C18E, dark: 0xCBD6A4)
    static let accentSoft = natureDynamic(light: 0xECF0DE, dark: 0x2E3322)
    static let teal = natureDynamic(light: 0x7C8B6F, dark: 0xA8B89A)
    static let tealSoft = natureDynamic(light: 0xE8EFE0, dark: 0x232B1E)
    static let rose = natureDynamic(light: 0xC4896B, dark: 0xD9A88A)
    static let roseSoft = natureDynamic(light: 0xF5E8DE, dark: 0x3A2A20)
    static let blue = natureDynamic(light: 0x7BA3C4, dark: 0x9BBDDB)
    static let blueSoft = natureDynamic(light: 0xE4EEF6, dark: 0x22303E)
    static let scrollNight = natureDynamic(light: 0x2C3325, dark: 0x1A1F16)
    static let scrollSunrise = natureDynamic(light: 0xC4896B, dark: 0xA06840)
    static let scrollGold = natureDynamic(light: 0xC4A84B, dark: 0xA08838)
    static let scrollNoon = natureDynamic(light: 0xA8B89A, dark: 0x4A5A40)
    static let scrollSunset = natureDynamic(light: 0xC4896B, dark: 0x9A6840)
    static let scrollViolet = natureDynamic(light: 0x6B7A5E, dark: 0x3A4532)
    static let workoutOrange = natureDynamic(light: 0xC4896B, dark: 0xD9A88A)
    static let walkGreen = natureDynamic(light: 0x7C8B6F, dark: 0xA8B89A)
    static let sleepIndigo = natureDynamic(light: 0x7BA3C4, dark: 0x9BBDDB)
    static let purple = natureDynamic(light: 0x8B7FA0, dark: 0xADA3BF)
    static let purpleSoft = natureDynamic(light: 0xEDE8F4, dark: 0x2D2838)
    static let orange = natureDynamic(light: 0xC4896B, dark: 0xD9A88A)
    static let orangeSoft = natureDynamic(light: 0xF5E8DE, dark: 0x3A2A20)
    static let glass = Color.white.opacity(0.18)
}

private func natureDynamic(light: UInt32, dark: UInt32) -> Color {
    Color(
        uiColor: UIColor { traits in
            UIColor(hex_nature: traits.userInterfaceStyle == .dark ? dark : light)
        }
    )
}

private extension UIColor {
    convenience init(hex_nature: UInt32) {
        let red = CGFloat((hex_nature >> 16) & 0xFF) / 255
        let green = CGFloat((hex_nature >> 8) & 0xFF) / 255
        let blue = CGFloat(hex_nature & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}
