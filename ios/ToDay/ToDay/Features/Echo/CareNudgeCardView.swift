import SwiftUI

struct CareNudgeCardView: View {
    let nudge: CareNudge

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: nudge.iconName)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(nudge.message)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                if let subtitle = nudge.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
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
}
