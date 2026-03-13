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
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(event.cardFill)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(event.kindBadgeTitle)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(event.cardFill)

                    Text(event.resolvedName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(TodayTheme.ink)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(event.scrollDurationText)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(TodayTheme.inkMuted)
                }

                if let detailLine = event.compactDetailLine {
                    Text(detailLine)
                        .font(.system(size: 13))
                        .foregroundStyle(TodayTheme.inkMuted)
                        .lineLimit(1)
                }

                if event.kind == .sleep,
                   let sleepStages = event.associatedMetrics?.sleepStages,
                   !sleepStages.isEmpty {
                    SleepStageRibbon(segments: sleepStages)
                        .frame(height: 6)
                }
            }
            .padding(.leading, 12)
        }
        .padding(.vertical, 12)
        .padding(.trailing, 14)
        .background(TodayTheme.card.opacity(event.isBlankCandidate ? 0.62 : 0.82))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(cardBorder)
    }

    @ViewBuilder
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(
                style: StrokeStyle(
                    lineWidth: event.isBlankCandidate ? 1 : 0.5,
                    dash: event.isBlankCandidate ? [7, 5] : []
                )
            )
            .foregroundStyle(
                event.isBlankCandidate
                    ? TodayTheme.border.opacity(0.35)
                    : TodayTheme.border.opacity(0.5)
            )
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
        HStack(spacing: 8) {
            Circle()
                .fill(event.cardStroke)
                .frame(width: 20, height: 20)
                .overlay {
                    Text(event.moodEmoji)
                        .font(.system(size: 11))
                }

            Text(event.resolvedName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(TodayTheme.ink)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(event.moodTimeText)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(TodayTheme.inkMuted)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(TodayTheme.card.opacity(0.6))
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(TodayTheme.border.opacity(0.5), lineWidth: 0.5)
        )
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

    var compactDetailLine: String? {
        let parts = [
            cardSubtitle,
            associatedMetrics?.location?.placeName,
            associatedMetrics?.weather?.compactDetailText
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var moodTimeText: String {
        startDate.formatted(.dateTime.hour().minute().locale(Locale(identifier: "zh_CN")))
    }
}

private extension HourlyWeather {
    var compactDetailText: String {
        "\(Int(temperature.rounded()))° \(localizedConditionText)"
    }

    private var localizedConditionText: String {
        switch condition {
        case .clear:
            return "晴"
        case .cloudy:
            return "多云"
        case .rain:
            return "雨"
        case .snow:
            return "雪"
        case .fog:
            return "雾"
        case .wind:
            return "风"
        case .thunderstorm:
            return "雷暴"
        case .unknown:
            return "未知"
        }
    }
}
