import SwiftUI

struct DashboardCardData: Identifiable {
    let id: String
    let icon: String
    let label: String
    let value: String
    let tint: Color
    let background: Color
    let trend: TrendDirection?

    init(
        id: String,
        icon: String,
        label: String,
        value: String,
        tint: Color,
        background: Color,
        trend: TrendDirection? = nil
    ) {
        self.id = id
        self.icon = icon
        self.label = label
        self.value = value
        self.tint = tint
        self.background = background
        self.trend = trend
    }
}

enum TrendDirection {
    case up
    case down
    case flat

    var iconName: String {
        switch self {
        case .up:   return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .flat: return "arrow.right"
        }
    }

    var label: String {
        switch self {
        case .up:   return "UP"
        case .down: return "DOWN"
        case .flat: return "SAME"
        }
    }
}

struct DashboardCardView: View {
    let card: DashboardCardData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Icon in tinted circle
                Image(systemName: card.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(card.tint)
                    .frame(width: 30, height: 30)
                    .background(card.tint.opacity(0.12))
                    .clipShape(Circle())

                Spacer()

                // Pill-shaped trend indicator
                if let trend = card.trend {
                    HStack(spacing: 3) {
                        Image(systemName: trend.iconName)
                            .font(.system(size: 9, weight: .bold))

                        Text(trend.label)
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.5)
                    }
                    .foregroundStyle(trendColor(trend))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(trendColor(trend).opacity(0.1))
                    .clipShape(Capsule())
                }
            }

            Spacer()

            // Label: small uppercase with letter spacing
            Text(card.label.uppercased())
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(TodayTheme.inkMuted)
                .tracking(1.2)
                .lineLimit(1)

            // Value: larger and bolder
            Text(card.value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(TodayTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .aspectRatio(1.0, contentMode: .fit)
        .background(card.background)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(TodayTheme.border.opacity(0.5), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color(red: 0.17, green: 0.20, blue: 0.15).opacity(0.06), radius: 16, x: 0, y: 4)
    }

    private func trendColor(_ trend: TrendDirection) -> Color {
        switch trend {
        case .up:   return TodayTheme.teal
        case .down: return TodayTheme.rose
        case .flat: return TodayTheme.inkMuted
        }
    }
}

#Preview {
    LazyVGrid(columns: [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ], spacing: 12) {
        DashboardCardView(card: DashboardCardData(
            id: "workout",
            icon: "figure.run",
            label: "运动",
            value: "46m",
            tint: TodayTheme.orange,
            background: TodayTheme.orangeSoft,
            trend: .up
        ))
        DashboardCardView(card: DashboardCardData(
            id: "sleep",
            icon: "moon.fill",
            label: "睡眠",
            value: "7h",
            tint: TodayTheme.sleepIndigo,
            background: TodayTheme.blueSoft,
            trend: .flat
        ))
        DashboardCardView(card: DashboardCardData(
            id: "steps",
            icon: "figure.walk",
            label: "步数",
            value: "8,240",
            tint: TodayTheme.walkGreen,
            background: TodayTheme.tealSoft,
            trend: .down
        ))
    }
    .padding()
    .background(TodayTheme.background)
}
