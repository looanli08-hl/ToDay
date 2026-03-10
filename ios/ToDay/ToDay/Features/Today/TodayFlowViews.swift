import SwiftUI

struct OverviewStat: Identifiable {
    let label: String
    let value: String
    let tint: Color
    let background: Color

    var id: String { label }
}

private struct RiverPoint: Identifiable {
    let index: Int
    let x: CGFloat
    let centerY: CGFloat
    let topY: CGFloat
    let bottomY: CGFloat
    let intensity: CGFloat
    let color: Color
    let progress: Double

    var id: Int { index }
}

struct OverviewStatCard: View {
    let stat: OverviewStat

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(stat.label)
                .font(.system(size: 11))
                .foregroundStyle(TodayTheme.inkMuted)

            Text(stat.value)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(stat.tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .frame(width: 92, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(stat.background)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(TodayTheme.border, lineWidth: 1)
        )
    }
}

struct TodayFlowSignatureView: View {
    let entries: [TimelineEntry]

    var body: some View {
        GeometryReader { proxy in
            let points = flowPoints(in: proxy.size)

            ZStack {
                flowBody(points: points)
                    .fill(flowGradient(points: points).opacity(0.45))

                flowCenterLine(points: points)
                    .stroke(flowGradient(points: points), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))

                ForEach(points.filter { $0.intensity >= 0.82 }) { point in
                    Circle()
                        .fill(point.color)
                        .frame(width: 7, height: 7)
                        .shadow(color: point.color.opacity(0.28), radius: 8, x: 0, y: 0)
                        .position(x: point.x, y: point.centerY)
                }
            }
        }
    }

    private func flowPoints(in size: CGSize) -> [RiverPoint] {
        guard !entries.isEmpty else { return [] }

        let width = max(size.width, 1)
        let centerY = size.height / 2

        return entries.enumerated().map { index, entry in
            let progress = Double(entry.moment.startMinuteOfDay) / Double(24 * 60)
            let x = width * CGFloat(progress)
            let wave = CGFloat(sin(Double(index) * 0.65) * 3.5)
            let intensity = entry.kind.flowIntensity
            let amplitude = 10 + (intensity * 20)

            return RiverPoint(
                index: index,
                x: x,
                centerY: centerY - (intensity * 10) + wave,
                topY: centerY - amplitude + wave,
                bottomY: centerY + amplitude - (wave * 0.45),
                intensity: intensity,
                color: entry.kind.flowColor,
                progress: progress
            )
        }
    }

    private func flowBody(points: [RiverPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }

        let topPoints = points.map { CGPoint(x: $0.x, y: $0.topY) }
        let bottomPoints = points.reversed().map { CGPoint(x: $0.x, y: $0.bottomY) }

        path.move(to: CGPoint(x: first.x, y: first.topY))
        addSmoothSegments(for: topPoints, to: &path)
        addSmoothSegments(for: bottomPoints, to: &path)
        path.closeSubpath()
        return path
    }

    private func flowCenterLine(points: [RiverPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        let centerPoints = points.map { CGPoint(x: $0.x, y: $0.centerY) }
        path.move(to: CGPoint(x: first.x, y: first.centerY))
        addSmoothSegments(for: centerPoints, to: &path)
        return path
    }

    private func addSmoothSegments(for points: [CGPoint], to path: inout Path) {
        guard points.count > 1 else { return }

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let midpoint = CGPoint(
                x: (previous.x + current.x) / 2,
                y: (previous.y + current.y) / 2
            )

            path.addQuadCurve(to: midpoint, control: previous)

            if index == points.count - 1 {
                path.addQuadCurve(to: current, control: midpoint)
            }
        }
    }

    private func flowGradient(points: [RiverPoint]) -> LinearGradient {
        let stops = points.map { point in
            Gradient.Stop(
                color: point.color.opacity(0.35 + (point.intensity * 0.45)),
                location: point.progress
            )
        }

        return LinearGradient(
            gradient: Gradient(stops: stops),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

struct TimelineStreamRow: View {
    let entry: TimelineEntry
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    Text(entry.moment.label)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(TodayTheme.inkMuted)
                        .frame(width: 74, alignment: .leading)

                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(entry.kind.flowBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(entry.kind.flowColor.opacity(isExpanded ? 0.24 : 0), lineWidth: 1.4)
                        )
                        .frame(width: 30, height: 30)
                        .overlay {
                            Text(entry.kind.icon)
                                .font(.system(size: 14))
                        }

                    Text(entry.title)
                        .font(.system(size: 15, weight: isExpanded ? .semibold : .regular))
                        .foregroundStyle(TodayTheme.inkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if entry.isLive {
                        Text("进行中")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(TodayTheme.teal)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(TodayTheme.tealSoft)
                            .clipShape(Capsule())
                    }

                    IntensityBar(
                        durationMinutes: entry.durationMinutes,
                        fallbackProgress: entry.kind.flowIntensity,
                        color: entry.kind.flowColor
                    )
                    .frame(width: 56)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(TodayTheme.inkMuted)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }

                if isExpanded {
                    Text(entry.detail)
                        .font(.system(size: 14))
                        .foregroundStyle(TodayTheme.inkMuted)
                        .lineSpacing(4)
                        .padding(.leading, 84)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .background(isExpanded ? entry.kind.flowBackground : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct IntensityBar: View {
    let durationMinutes: Int?
    let fallbackProgress: CGFloat
    let color: Color

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(TodayTheme.border)
                .frame(height: 3)

            Capsule()
                .fill(color)
                .frame(width: max(10, 56 * visualProgress), height: 3)
        }
    }

    private var visualProgress: CGFloat {
        guard let durationMinutes else { return max(0.18, fallbackProgress) }
        let cappedMinutes = min(max(CGFloat(durationMinutes), 5), 240)
        let normalized = sqrt(cappedMinutes / 240)
        return max(0.18, normalized)
    }
}

struct RecentDayCard: View {
    let digest: RecentDayDigest
    let locale: Locale

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(digest.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(TodayTheme.inkSoft)

                    Spacer()

                    Text(digest.date.formatted(.dateTime.month(.abbreviated).day().locale(locale)))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(TodayTheme.inkMuted)
                }

                Text(digest.detail)
                    .font(.system(size: 13))
                    .foregroundStyle(TodayTheme.inkMuted)

                if let notePreview = digest.notePreview {
                    Text("“\(notePreview)”")
                        .font(.system(size: 12))
                        .foregroundStyle(TodayTheme.inkSoft)
                        .lineLimit(1)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TodayTheme.elevatedCard.opacity(0.72))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(TodayTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var color: Color {
        switch digest.mood {
        case .happy:
            return TodayTheme.accent
        case .calm:
            return TodayTheme.teal
        case .tired:
            return TodayTheme.blue
        case .irritated:
            return TodayTheme.rose
        case .focused:
            return TodayTheme.teal
        case .zoning:
            return TodayTheme.inkFaint
        case .none:
            return TodayTheme.inkFaint
        }
    }
}

extension TimelineEntry.Kind {
    var flowColor: Color {
        switch self {
        case .sleep:
            return TodayTheme.blue
        case .move:
            return TodayTheme.rose
        case .focus:
            return TodayTheme.teal
        case .pause:
            return TodayTheme.inkFaint
        case .mood:
            return TodayTheme.accent
        }
    }

    var flowBackground: Color {
        switch self {
        case .sleep:
            return TodayTheme.blueSoft
        case .move:
            return TodayTheme.roseSoft
        case .focus:
            return TodayTheme.tealSoft
        case .pause:
            return TodayTheme.elevatedCard
        case .mood:
            return TodayTheme.accentSoft
        }
    }

    var flowIntensity: CGFloat {
        switch self {
        case .sleep:
            return 0.24
        case .move:
            return 0.68
        case .focus:
            return 0.90
        case .pause:
            return 0.20
        case .mood:
            return 0.48
        }
    }

    var icon: String {
        switch self {
        case .sleep:
            return "🌙"
        case .move:
            return "🚶"
        case .focus:
            return "⌘"
        case .pause:
            return "☁️"
        case .mood:
            return "✦"
        }
    }
}
