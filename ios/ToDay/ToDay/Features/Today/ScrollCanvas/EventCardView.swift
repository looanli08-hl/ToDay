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
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(event.scrollDurationText)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(UIColor.tertiaryLabel))
                }

                if let detailLine = event.compactDetailLine {
                    Text(detailLine)
                        .font(.system(size: 13))
                        .foregroundStyle(Color(UIColor.tertiaryLabel))
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
        .background(Color(UIColor.secondarySystemGroupedBackground).opacity(event.isBlankCandidate ? 0.62 : 0.82))
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
                    ? Color(UIColor.separator).opacity(0.35)
                    : Color(UIColor.separator).opacity(0.5)
            )
            .overlay(alignment: .bottomTrailing) {
                if event.isBlankCandidate {
                    Text("点击记录")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(UIColor.secondarySystemGroupedBackground).opacity(0.76))
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
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(event.moodTimeText)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(UIColor.tertiaryLabel))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color(UIColor.secondarySystemGroupedBackground).opacity(0.6))
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color(UIColor.separator).opacity(0.5), lineWidth: 0.5)
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
            return Color(UIColor.quaternaryLabel)
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
                return "\(hours) 小时"
            }
            return "\(hours) 小时 \(remainder) 分钟"
        }
        return "\(minutes) 分钟"
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
            return Color.accentColor
        case .shutter:
            return TodayTheme.scrollGold.opacity(0.86)
        case .screenTime:
            return TodayTheme.glass
        case .spending:
            return TodayTheme.teal.opacity(0.82)
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
            return Color(UIColor.quaternaryLabel)
        case .userAnnotated:
            return TodayTheme.teal
        case .mood:
            return Color.accentColor
        case .shutter:
            return TodayTheme.scrollGold
        case .screenTime:
            return Color(UIColor.quaternaryLabel)
        case .spending:
            return TodayTheme.teal
        }
    }

    var isBlankCandidate: Bool {
        kind == .quietTime || confidence <= .low
    }

    var kindBadgeTitle: String {
        switch kind {
        case .sleep:
            return "睡眠"
        case .workout:
            return associatedMetrics?.workoutType ?? "运动"
        case .commute:
            return "通勤"
        case .activeWalk:
            return "步行"
        case .quietTime:
            return "留白"
        case .userAnnotated:
            return "标注"
        case .mood:
            return "心情"
        case .shutter:
            return "快门"
        case .screenTime:
            return "屏幕"
        case .spending:
            return "消费"
        }
    }

    var cardSubtitle: String? {
        if let subtitle, !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return subtitle
        }

        var parts: [String] = []

        if let distance = associatedMetrics?.distance, distance > 0 {
            if distance >= 1000 {
                parts.append(String(format: "%.1f 公里", distance / 1000))
            } else {
                parts.append("\(Int(distance.rounded())) 米")
            }
        }

        if let activeEnergy = associatedMetrics?.activeEnergy, activeEnergy > 0 {
            parts.append("\(Int(activeEnergy.rounded())) 千卡")
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
        var parts = [
            cardSubtitle,
            associatedMetrics?.location?.placeName,
            associatedMetrics?.weather?.compactDetailText
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

        // Add workout intensity badge
        if let intensity = associatedMetrics?.workoutIntensity {
            parts.insert(intensity.label, at: 0)
        }

        // Add sleep quality score
        if let score = associatedMetrics?.sleepQualityScore {
            parts.insert("质量 \(score)分", at: 0)
        }

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
