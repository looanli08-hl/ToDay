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
}

struct DashboardCardView: View {
    let card: DashboardCardData

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: card.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(card.tint)

                Spacer()

                if let trend = card.trend {
                    Image(systemName: trend.iconName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(trendColor(trend))
                }
            }

            Spacer()

            Text(card.label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(TodayTheme.inkMuted)
                .lineLimit(1)

            Text(card.value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(TodayTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .aspectRatio(1.0, contentMode: .fit)
        .background(card.background)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(TodayTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
}
