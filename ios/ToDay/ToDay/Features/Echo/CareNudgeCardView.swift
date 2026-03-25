import SwiftUI

struct CareNudgeCardView: View {
    let nudge: CareNudge

    var body: some View {
        ContentCard(background: cardBackground) {
            HStack(spacing: 14) {
                Image(systemName: nudge.iconName)
                    .font(.system(size: 22))
                    .foregroundStyle(iconColor)
                    .frame(width: 40, height: 40)
                    .background(iconBackground)
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
