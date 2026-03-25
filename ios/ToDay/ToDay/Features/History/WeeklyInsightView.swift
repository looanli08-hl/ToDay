import Charts
import SwiftUI

struct WeeklyInsightView: View {
    let timelines: [DayTimeline]
    private let calendar = Calendar.current

    private var currentWeek: [DayTimeline] {
        currentWeekDates.compactMap { timelineLookup[$0] }
    }

    private var previousWeek: [DayTimeline] {
        previousWeekDates.compactMap { timelineLookup[$0] }
    }

    private var timelineLookup: [Date: DayTimeline] {
        Dictionary(uniqueKeysWithValues: timelines.map { (calendar.startOfDay(for: $0.date), $0) })
    }

    private var referenceDate: Date {
        calendar.startOfDay(for: timelines.last?.date ?? Date())
    }

    private var currentWeekDates: [Date] {
        (-6...0).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: referenceDate)
        }
    }

    private var previousWeekDates: [Date] {
        (-13 ... -7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: referenceDate)
        }
    }

    var body: some View {
        ContentCard(background: TodayTheme.tealSoft.opacity(0.68)) {
            EyebrowLabel("一周洞察")

            Text(summaryText)
                .font(.system(size: 15))
                .foregroundStyle(.primary)
                .lineSpacing(5)

            HStack(spacing: 12) {
                trendCard(
                    title: "运动趋势",
                    metricText: durationText(totalActiveMinutes(in: currentWeek)),
                    entries: movementTrend
                )
                trendCard(
                    title: "睡眠趋势",
                    metricText: averageSleepLabel,
                    entries: sleepTrend
                )
            }
            .frame(height: 140)

            moodHeatBand

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

    private var summaryText: String {
        guard hasEnoughData else {
            return "这周的数据还在积累中，戴着手表过完几天就能看到完整洞察。"
        }

        let thisWeekMovement = totalActiveMinutes(in: currentWeek)
        let lastWeekMovement = totalActiveMinutes(in: previousWeek)
        let difference = thisWeekMovement - lastWeekMovement
        let comparisonText: String

        if lastWeekMovement == 0 {
            comparisonText = "这是你开始积累画卷的第一周。"
        } else if difference > 0 {
            comparisonText = "比上周多了 \(durationText(difference))。"
        } else if difference < 0 {
            comparisonText = "比上周少了 \(durationText(abs(difference)))。"
        } else {
            comparisonText = "和上周基本持平。"
        }

        let averageSleep = averageSleepHours(in: currentWeek)
        let averageSleepText = averageSleep > 0 ? String(format: "%.1f", averageSleep) : "0.0"
        let sleepLowlightText: String
        if let sleepLowlight = leastSleepDay {
            sleepLowlightText = "周\(sleepLowlight.weekdayLabel)睡得最少（\(String(format: "%.1f", sleepLowlight.hours)) 小时）。"
        } else {
            sleepLowlightText = "睡眠数据还不够完整。"
        }

        return "这周你运动了 \(durationText(thisWeekMovement))，\(comparisonText) 平均每晚睡 \(averageSleepText) 小时，\(sleepLowlightText)"
    }

    private var hasEnoughData: Bool {
        currentWeek.count >= 3
    }

    private var averageSleepLabel: String {
        let hours = averageSleepHours(in: currentWeek)
        guard hours > 0 else { return "暂无" }
        return String(format: "%.1f 小时", hours)
    }

    private var movementTrend: [WeeklyTrendPoint] {
        currentWeekDates.map { date in
            WeeklyTrendPoint(
                date: date,
                label: weekdayLabel(for: date),
                value: timelineLookup[date].map { totalActiveMinutes(in: [$0]) } ?? 0
            )
        }
    }

    private var sleepTrend: [WeeklyTrendPoint] {
        currentWeekDates.map { date in
            WeeklyTrendPoint(
                date: date,
                label: weekdayLabel(for: date),
                value: timelineLookup[date].map(sleepHours(in:)) ?? 0
            )
        }
    }

    private var moodSummaries: [WeeklyMoodSummary] {
        currentWeekDates.map { date in
            let moods = (timelineLookup[date]?.entries ?? []).compactMap { event -> MoodRecord.Mood? in
                guard event.kind == .mood else { return nil }
                return MoodRecord.Mood(storedValue: event.resolvedName)
            }
            let counts = moods.reduce(into: [MoodRecord.Mood: Int]()) { partialResult, mood in
                partialResult[mood, default: 0] += 1
            }
            let dominantMood = counts.max { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key.rawValue > rhs.key.rawValue
                }
                return lhs.value < rhs.value
            }?.key

            return WeeklyMoodSummary(
                date: date,
                weekdayLabel: weekdayLabel(for: date),
                mood: dominantMood
            )
        }
    }

    private var moodHeatBand: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("情绪热力带")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(UIColor.tertiaryLabel))

            HStack(spacing: 10) {
                ForEach(moodSummaries) { summary in
                    VStack(spacing: 8) {
                        Group {
                            if let mood = summary.mood {
                                Text(mood.emoji)
                                    .font(.system(size: 18))
                                    .frame(width: 38, height: 38)
                                    .background(moodColor(for: mood))
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .stroke(Color(UIColor.separator), lineWidth: 1.2)
                                    .frame(width: 38, height: 38)
                                    .overlay {
                                        Text("—")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(Color(UIColor.quaternaryLabel))
                                    }
                            }
                        }

                        Text(summary.weekdayLabel)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color(UIColor.tertiaryLabel))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemGroupedBackground).opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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

    private var leastSleepDay: WeeklySleepLowlight? {
        currentWeek
            .map { WeeklySleepLowlight(date: $0.date, hours: sleepHours(in: $0)) }
            .filter { $0.hours > 0 }
            .min { $0.hours < $1.hours }
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
        let sleepDurations = timelines.map(sleepHours(in:))
        let validDurations = sleepDurations.filter { $0 > 0 }
        guard !validDurations.isEmpty else { return 0 }
        return validDurations.reduce(0, +) / Double(validDurations.count)
    }

    private func sleepHours(in timeline: DayTimeline) -> Double {
        timeline.entries
            .filter { $0.kind == .sleep }
            .reduce(0.0) { $0 + $1.duration / 3600 }
    }

    private func durationText(_ minutes: Double) -> String {
        let roundedMinutes = max(Int(minutes.rounded()), 0)
        let hours = roundedMinutes / 60
        let remainder = roundedMinutes % 60

        if hours > 0 {
            return remainder == 0 ? "\(hours) 小时" : "\(hours) 小时 \(remainder) 分钟"
        }
        return "\(roundedMinutes) 分钟"
    }

    private func weekdayLabel(for date: Date) -> String {
        let weekday = Calendar.current.component(.weekday, from: date)
        switch weekday {
        case 1: return "日"
        case 2: return "一"
        case 3: return "二"
        case 4: return "三"
        case 5: return "四"
        case 6: return "五"
        default: return "六"
        }
    }

    private func trendCard(title: String, metricText: String, entries: [WeeklyTrendPoint]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(UIColor.tertiaryLabel))

                Spacer()

                Text(metricText)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Chart(entries) { entry in
                AreaMark(
                    x: .value("星期", entry.label),
                    y: .value("值", entry.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: title == "运动趋势"
                            ? [TodayTheme.tealSoft.opacity(0.9), TodayTheme.teal.opacity(0.14)]
                            : [TodayTheme.blueSoft.opacity(0.9), TodayTheme.sleepIndigo.opacity(0.14)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("星期", entry.label),
                    y: .value("值", entry.value)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                .foregroundStyle(title == "运动趋势" ? TodayTheme.teal : TodayTheme.sleepIndigo)
            }
            .chartXAxis {
                AxisMarks(values: entries.map(\.label)) { value in
                    AxisValueLabel()
                }
            }
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground).opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func spotlightCard(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(UIColor.tertiaryLabel))

            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(detail)
                .font(.system(size: 13))
                .foregroundStyle(Color(UIColor.tertiaryLabel))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground).opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func moodColor(for mood: MoodRecord.Mood) -> Color {
        switch mood {
        case .happy:
            return Color.accentColor
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
            return Color(UIColor.quaternaryLabel)
        case .sleepy:
            return TodayTheme.blueSoft
        case .satisfied:
            return TodayTheme.scrollSunrise
        }
    }
}

private struct WeeklyTrendPoint: Identifiable {
    let date: Date
    let label: String
    let value: Double

    var id: Date { date }
}

private struct WeeklyMoodSummary: Identifiable {
    let date: Date
    let weekdayLabel: String
    let mood: MoodRecord.Mood?

    var id: Date { date }
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

private struct WeeklySleepLowlight {
    let date: Date
    let hours: Double

    var weekdayLabel: String {
        switch Calendar.current.component(.weekday, from: date) {
        case 1: return "日"
        case 2: return "一"
        case 3: return "二"
        case 4: return "三"
        case 5: return "四"
        case 6: return "五"
        default: return "六"
        }
    }
}
