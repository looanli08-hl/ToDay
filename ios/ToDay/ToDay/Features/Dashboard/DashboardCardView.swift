import SwiftUI

struct DashboardCardData: Identifiable {
    let id: String
    let icon: String
    let label: String
    let value: String
    let tint: Color
    let trend: TrendDirection?

    init(
        id: String,
        icon: String,
        label: String,
        value: String,
        tint: Color,
        trend: TrendDirection? = nil
    ) {
        self.id = id
        self.icon = icon
        self.label = label
        self.value = value
        self.tint = tint
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
        case .up:   return "升"
        case .down: return "降"
        case .flat: return "平"
        }
    }
}

struct DashboardCardView: View {
    let card: DashboardCardData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: card.icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(card.tint)

                Spacer()

                if let trend = card.trend {
                    Image(systemName: trend.iconName)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(trendColor(trend))
                }
            }

            Spacer()

            Text(card.label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(card.value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .aspectRatio(1.0, contentMode: .fit)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func trendColor(_ trend: TrendDirection) -> Color {
        switch trend {
        case .up:   return .green
        case .down: return .red
        case .flat: return .secondary
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
            trend: .up
        ))
        DashboardCardView(card: DashboardCardData(
            id: "sleep",
            icon: "moon.fill",
            label: "睡眠",
            value: "7h",
            tint: TodayTheme.sleepIndigo,
            trend: .flat
        ))
        DashboardCardView(card: DashboardCardData(
            id: "steps",
            icon: "figure.walk",
            label: "步数",
            value: "8,240",
            tint: TodayTheme.walkGreen,
            trend: .down
        ))
    }
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}
