import SwiftUI

struct EventCardView: View {
    let event: InferredEvent

    var body: some View {
        Group {
            if event.kind == .mood {
                moodMarker
            } else {
                eventCard
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(event.resolvedName)
        .accessibilityValue(event.scrollDurationText)
    }

    private var eventCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(event.kindBadgeTitle)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(event.secondaryTextColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(event.badgeBackground)
                        .clipShape(Capsule())

                    Text(event.resolvedName)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(event.primaryTextColor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                }

                Spacer(minLength: 4)

                if let weather = event.associatedMetrics?.weather {
                    VStack(alignment: .trailing, spacing: 4) {
                        Image(systemName: weather.symbolName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(event.primaryTextColor)

                        Text("\(Int(weather.temperature.rounded()))°")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(event.secondaryTextColor)
                    }
                }
            }

            if event.kind == .sleep,
               let sleepStages = event.associatedMetrics?.sleepStages,
               !sleepStages.isEmpty {
                SleepStageRibbon(segments: sleepStages)
                    .frame(height: 8)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 6) {
                Text(event.scrollDurationText)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(event.primaryTextColor)

                if let subtitle = event.cardSubtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(event.secondaryTextColor)
                        .lineLimit(2)
                }

                if let locationName = event.associatedMetrics?.location?.placeName {
                    Text(locationName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(event.secondaryTextColor)
                        .lineLimit(1)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(event.cardFill)
            .overlay {
                if event.kind == .quietTime {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            }
    }

    @ViewBuilder
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(
                style: StrokeStyle(
                    lineWidth: event.isBlankCandidate ? 1.4 : 1,
                    dash: event.isBlankCandidate ? [7, 5] : []
                )
            )
            .foregroundStyle(event.isBlankCandidate ? TodayTheme.inkFaint : event.cardStroke)
            .overlay(alignment: .bottomTrailing) {
                if event.isBlankCandidate {
                    Text("点击记录")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(TodayTheme.inkSoft)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(TodayTheme.card.opacity(0.76))
                        .clipShape(Capsule())
                        .padding(10)
                }
            }
    }

    private var moodMarker: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(event.cardStroke)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.8), lineWidth: 2)
                )
                .overlay {
                    Text(event.moodEmoji)
                        .font(.system(size: 13))
                }

            if event.endDate > event.startDate {
                Capsule()
                    .fill(event.cardStroke.opacity(0.32))
                    .frame(height: 8)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(event.cardStroke)
                            .frame(width: max(20, CGFloat(event.scrollCanvasDurationMinutes) * ScrollCanvasMetrics.moodPointsPerMinute))
                    }
            }
        }
    }
}

private struct SleepStageRibbon: View {
    let segments: [SleepStageSegment]

    var body: some View {
        GeometryReader { proxy in
            let totalDuration = max(segments.reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) }, 1)

            HStack(spacing: 2) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(color(for: segment.stage))
                        .frame(
                            width: max(
                                6,
                                proxy.size.width * (segment.end.timeIntervalSince(segment.start) / totalDuration)
                            )
                        )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func color(for stage: SleepStage) -> Color {
        switch stage {
        case .deep:
            return TodayTheme.scrollNight
        case .light:
            return TodayTheme.sleepIndigo
        case .rem:
            return TodayTheme.scrollSunrise
        case .awake:
            return TodayTheme.scrollGold
        case .unknown:
            return TodayTheme.inkFaint
        }
    }
}

extension InferredEvent {
    var scrollCanvasDurationMinutes: Int {
        max(Int(max(endDate.timeIntervalSince(startDate), 60) / 60), 1)
    }

    var scrollDurationText: String {
        let minutes = scrollCanvasDurationMinutes
        if minutes >= 60 {
            let hours = minutes / 60
            let remainder = minutes % 60
            if remainder == 0 {
                return "\(hours)h"
            }
            return "\(hours)h\(remainder)min"
        }
        return "\(minutes)min"
    }

    var cardHeight: CGFloat {
        let baseHeight: CGFloat
        switch kind {
        case .workout:
            baseHeight = 120
        case .commute, .activeWalk:
            baseHeight = 92
        case .sleep:
            baseHeight = 72
        case .quietTime:
            baseHeight = 64
        case .userAnnotated:
            baseHeight = 88
        case .mood:
            baseHeight = endDate > startDate ? 28 : 24
        }

        guard kind != .mood, let averageHeartRate = associatedMetrics?.averageHeartRate else {
            return baseHeight
        }

        let adjustment = max(min((averageHeartRate - 72) * 0.6, 20), -12)
        return max(56, baseHeight + adjustment)
    }

    var cardFill: Color {
        switch kind {
        case .sleep:
            return TodayTheme.sleepIndigo.opacity(0.78)
        case .workout:
            if associatedMetrics?.workoutType?.contains("骑") == true {
                return TodayTheme.blue.opacity(0.86)
            }
            if associatedMetrics?.workoutType?.contains("跑") == true {
                return TodayTheme.workoutOrange.opacity(0.9)
            }
            return TodayTheme.rose.opacity(0.88)
        case .commute, .activeWalk:
            return TodayTheme.walkGreen.opacity(0.86)
        case .quietTime:
            return TodayTheme.glass
        case .userAnnotated:
            return TodayTheme.teal.opacity(0.82)
        case .mood:
            return TodayTheme.accent
        }
    }

    var cardStroke: Color {
        switch kind {
        case .sleep:
            return TodayTheme.sleepIndigo
        case .workout:
            if associatedMetrics?.workoutType?.contains("骑") == true {
                return TodayTheme.blue
            }
            if associatedMetrics?.workoutType?.contains("跑") == true {
                return TodayTheme.workoutOrange
            }
            return TodayTheme.rose
        case .commute, .activeWalk:
            return TodayTheme.walkGreen
        case .quietTime:
            return TodayTheme.inkFaint
        case .userAnnotated:
            return TodayTheme.teal
        case .mood:
            return TodayTheme.accent
        }
    }

    var isBlankCandidate: Bool {
        kind == .quietTime || confidence <= .low
    }

    var primaryTextColor: Color {
        switch kind {
        case .sleep, .workout, .commute, .activeWalk, .userAnnotated:
            return Color.white
        case .quietTime:
            return TodayTheme.ink
        case .mood:
            return TodayTheme.ink
        }
    }

    var secondaryTextColor: Color {
        switch kind {
        case .sleep, .workout, .commute, .activeWalk, .userAnnotated:
            return Color.white.opacity(0.78)
        case .quietTime:
            return TodayTheme.inkMuted
        case .mood:
            return TodayTheme.inkMuted
        }
    }

    var badgeBackground: Color {
        switch kind {
        case .sleep, .workout, .commute, .activeWalk, .userAnnotated:
            return Color.white.opacity(0.14)
        case .quietTime:
            return TodayTheme.card.opacity(0.7)
        case .mood:
            return TodayTheme.accentSoft
        }
    }

    var kindBadgeTitle: String {
        switch kind {
        case .sleep:
            return "SLEEP"
        case .workout:
            return associatedMetrics?.workoutType?.uppercased() ?? "WORKOUT"
        case .commute:
            return "COMMUTE"
        case .activeWalk:
            return "WALK"
        case .quietTime:
            return "BLANK"
        case .userAnnotated:
            return "MARKED"
        case .mood:
            return "MOOD"
        }
    }

    var cardSubtitle: String? {
        if let subtitle, !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return subtitle
        }

        var parts: [String] = []

        if let distance = associatedMetrics?.distance, distance > 0 {
            if distance >= 1000 {
                parts.append(String(format: "%.1fkm", distance / 1000))
            } else {
                parts.append("\(Int(distance.rounded()))m")
            }
        }

        if let activeEnergy = associatedMetrics?.activeEnergy, activeEnergy > 0 {
            parts.append("\(Int(activeEnergy.rounded()))kcal")
        }

        if let stepCount = associatedMetrics?.stepCount, stepCount > 0, kind != .workout {
            parts.append("\(stepCount)步")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var moodEmoji: String {
        if resolvedName.contains("开心") { return "😊" }
        if resolvedName.contains("平静") { return "🌿" }
        if resolvedName.contains("专注") { return "🎯" }
        if resolvedName.contains("感恩") { return "🙏" }
        if resolvedName.contains("兴奋") { return "🤩" }
        if resolvedName.contains("疲惫") { return "😴" }
        if resolvedName.contains("焦虑") { return "😰" }
        if resolvedName.contains("难过") { return "😔" }
        if resolvedName.contains("烦躁") { return "😤" }
        if resolvedName.contains("无聊") { return "🥱" }
        if resolvedName.contains("困倦") { return "😪" }
        if resolvedName.contains("满足") { return "☺️" }
        return "✦"
    }
}
