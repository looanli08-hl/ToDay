import SwiftUI

struct CareNudgeCardView: View {
    let nudge: CareNudge

    var body: some View {
        ContentCard(background: cardBackground) {
            HStack(spacing: 14) {
                Image(systemName: nudge.iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 44, height: 44)
                    .background(iconColor.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(nudge.message)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(TodayTheme.ink)

                    if let subtitle = nudge.subtitle {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(TodayTheme.inkMuted)
                    }
                }

                Spacer()
            }
        }
        .shadow(color: TodayTheme.ink.opacity(0.06), radius: 16, x: 0, y: 4)
    }

    private var cardBackground: Color {
        switch nudge.kind {
        case .exerciseStreak:
            return TodayTheme.tealSoft
        case .highScreenTime:
            return TodayTheme.orangeSoft
        case .noShutterCheckIn:
            return TodayTheme.purpleSoft
        }
    }

    private var iconColor: Color {
        switch nudge.kind {
        case .exerciseStreak:
            return TodayTheme.teal
        case .highScreenTime:
            return TodayTheme.orange
        case .noShutterCheckIn:
            return TodayTheme.purple
        }
    }

    private var iconBackground: Color {
        switch nudge.kind {
        case .exerciseStreak:
            return TodayTheme.teal.opacity(0.15)
        case .highScreenTime:
            return TodayTheme.orange.opacity(0.15)
        case .noShutterCheckIn:
            return TodayTheme.purple.opacity(0.15)
        }
    }
}
