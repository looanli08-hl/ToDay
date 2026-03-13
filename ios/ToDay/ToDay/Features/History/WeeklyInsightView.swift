import Charts
import SwiftUI

struct WeeklyInsightView: View {
    let timelines: [DayTimeline]

    private var currentWeek: [DayTimeline] {
        Array(timelines.suffix(7))
    }

    private var previousWeek: [DayTimeline] {
        Array(timelines.dropLast(min(7, timelines.count)).suffix(7))
    }

    var body: some View {
        ContentCard(background: TodayTheme.tealSoft.opacity(0.68)) {
            EyebrowLabel("WEEKLY INSIGHT")

            Text("一周洞察")
                .font(.system(size: 23, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(TodayTheme.ink)

            Text("把最近 7 天的推进、睡眠和情绪压成一个可回看的横截面。")
                .font(.system(size: 14))
                .foregroundStyle(TodayTheme.inkMuted)
                .lineSpacing(4)

            HStack(spacing: 10) {
                highlightCard(title: "本周运动", value: durationText(totalActiveMinutes(in: currentWeek)))
                highlightCard(title: "平均睡眠", value: sleepAverageText)
            }

            Chart(activityComparison) { item in
                BarMark(
                    x: .value("周期", item.label),
                    y: .value("分钟", item.minutes)
                )
                .foregroundStyle(item.label == "本周" ? TodayTheme.teal : TodayTheme.teal.opacity(0.35))
                .cornerRadius(8)
            }
            .frame(height: 160)
            .chartYAxis {
                AxisMarks(position: .leading)
            }

            if !moodDistribution.isEmpty {
                Chart(moodDistribution) { item in
                    BarMark(
                        x: .value("情绪", item.label),
                        y: .value("次数", item.count)
                    )
                    .foregroundStyle(item.color)
                    .cornerRadius(6)
                }
                .frame(height: 180)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }

            HStack(spacing: 10) {
                spotlightCard(
                    title: "最活跃的一天",
                    value: mostActiveDay?.title ?? "暂无",
                    detail: mostActiveDay?.detail ?? "等更多片段"
                )
                spotlightCard(
                    title: "最安静的一天",
                    value: quietestDay?.title ?? "暂无",
                    detail: quietestDay?.detail ?? "等更多片段"
                )
            }
        }
    }

    private var activityComparison: [WeeklyActivityComparison] {
        [
            .init(label: "上周", minutes: totalActiveMinutes(in: previousWeek)),
            .init(label: "本周", minutes: totalActiveMinutes(in: currentWeek))
        ]
    }

    private var moodDistribution: [WeeklyMoodCount] {
        let moodEvents = currentWeek
            .flatMap(\.entries)
            .filter { $0.kind == .mood }

        let counts = moodEvents.reduce(into: [MoodRecord.Mood: Int]()) { partialResult, event in
            if let mood = MoodRecord.Mood(storedValue: event.resolvedName) {
                partialResult[mood, default: 0] += 1
            }
        }

        return counts
            .map { WeeklyMoodCount(mood: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    private var sleepAverageText: String {
        let hours = averageSleepHours(in: currentWeek)
        guard hours > 0 else { return "暂无" }
        if hours >= 10 {
            return String(format: "%.1f h", hours)
        }
        return String(format: "%.1f h", hours)
    }

    private var mostActiveDay: WeeklyDaySpotlight? {
        currentWeek
            .map { timeline in
                WeeklyDaySpotlight(
                    date: timeline.date,
                    value: totalActiveMinutes(in: [timeline]),
                    detailValue: durationText(totalActiveMinutes(in: [timeline]))
                )
            }
            .max(by: { $0.value < $1.value })
    }

    private var quietestDay: WeeklyDaySpotlight? {
        currentWeek
            .map { timeline in
                WeeklyDaySpotlight(
                    date: timeline.date,
                    value: totalQuietMinutes(in: timeline),
                    detailValue: durationText(totalQuietMinutes(in: timeline))
                )
            }
            .max(by: { $0.value < $1.value })
    }

    private func totalActiveMinutes(in timelines: [DayTimeline]) -> Double {
        timelines.reduce(0) { partial, timeline in
            partial + timeline.entries.reduce(0) { subtotal, event in
                switch event.kind {
                case .workout, .activeWalk, .commute, .userAnnotated:
                    return subtotal + max(event.duration / 60, 1)
                default:
                    return subtotal
                }
            }
        }
    }

    private func totalQuietMinutes(in timeline: DayTimeline) -> Double {
        timeline.entries.reduce(0) { partial, event in
            guard event.kind == .quietTime else { return partial }
            return partial + max(event.duration / 60, 1)
        }
    }

    private func averageSleepHours(in timelines: [DayTimeline]) -> Double {
        let sleepDurations = timelines.map { timeline in
            timeline.entries
                .filter { $0.kind == .sleep }
                .reduce(0.0) { $0 + $1.duration / 3600 }
        }
        let validDurations = sleepDurations.filter { $0 > 0 }
        guard !validDurations.isEmpty else { return 0 }
        return validDurations.reduce(0, +) / Double(validDurations.count)
    }

    private func durationText(_ minutes: Double) -> String {
        let roundedMinutes = max(Int(minutes.rounded()), 0)
        let hours = roundedMinutes / 60
        let remainder = roundedMinutes % 60

        if hours > 0 {
            return remainder == 0 ? "\(hours)h" : "\(hours)h\(remainder)m"
        }
        return "\(roundedMinutes)m"
    }

    private func highlightCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(TodayTheme.inkMuted)

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(TodayTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TodayTheme.card.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func spotlightCard(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(TodayTheme.inkMuted)

            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(TodayTheme.inkSoft)

            Text(detail)
                .font(.system(size: 13))
                .foregroundStyle(TodayTheme.inkMuted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TodayTheme.card.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct WeeklyActivityComparison: Identifiable {
    let label: String
    let minutes: Double

    var id: String { label }
}

private struct WeeklyMoodCount: Identifiable {
    let mood: MoodRecord.Mood
    let count: Int

    var id: String { mood.rawValue }
    var label: String { mood.rawValue }
    var color: Color {
        switch mood {
        case .happy:
            return TodayTheme.accent
        case .calm:
            return TodayTheme.teal
        case .focused:
            return TodayTheme.teal
        case .grateful:
            return TodayTheme.scrollGold
        case .excited:
            return TodayTheme.workoutOrange
        case .tired:
            return TodayTheme.blue
        case .anxious:
            return TodayTheme.scrollViolet
        case .sad:
            return TodayTheme.sleepIndigo
        case .irritated:
            return TodayTheme.rose
        case .bored:
            return TodayTheme.inkFaint
        case .sleepy:
            return TodayTheme.blueSoft
        case .satisfied:
            return TodayTheme.scrollSunrise
        }
    }
}

private struct WeeklyDaySpotlight {
    let date: Date
    let value: Double
    let detailValue: String

    var title: String {
        date.formatted(.dateTime.month(.abbreviated).day().weekday(.abbreviated).locale(Locale(identifier: "zh_CN")))
    }

    var detail: String {
        detailValue
    }
}
