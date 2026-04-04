import Foundation
import SwiftUI

struct DashboardViewModel {
    let timeline: DayTimeline?

    // MARK: - Card Data

    var cards: [DashboardCardData] {
        [
            workoutCard,
            sleepCard,
            screenTimeCard,
            spendingCard,
            stepsCard,
            shutterCard
        ]
    }

    // MARK: - Timeline Preview

    /// Returns the last few events in reverse chronological order, capped at 5.
    var timelinePreview: [InferredEvent] {
        guard let timeline else { return [] }
        return Array(
            timeline.entries
                .sorted { $0.startDate > $1.startDate }
                .prefix(5)
        )
    }

    // MARK: - Insight Text

    var insightText: String {
        guard let timeline else {
            return "今天的数据还在路上，稍后再看看。"
        }

        var parts: [String] = []

        let workoutMinutes = totalWorkoutMinutes
        if workoutMinutes > 0 {
            parts.append("今日运动 \(workoutMinutes) 分钟")
        }

        let sleepHours = totalSleepHours
        if sleepHours > 0 {
            parts.append("睡眠 \(sleepHours) 小时")
        }

        let steps = totalSteps
        if steps > 0 {
            parts.append("步行 \(formatNumber(steps)) 步")
        }

        let spending = totalSpending
        if spending > 0 {
            parts.append("消费 ¥\(Int(spending))")
        }

        let shutters = shutterCount
        if shutters > 0 {
            parts.append("快门 \(shutters) 条")
        }

        if parts.isEmpty {
            return "今天还没有可展示的维度数据，带着手机出门活动一下吧。"
        }

        let entryCount = timeline.entries.count
        let summaryPrefix = "已记录 \(entryCount) 个片段："
        return summaryPrefix + parts.joined(separator: "，") + "。"
    }

    // MARK: - Date Header

    var dateText: String {
        Self.dateHeaderFormatter.string(from: timeline?.date ?? Date())
    }

    // MARK: - Individual Cards

    private var workoutCard: DashboardCardData {
        let minutes = totalWorkoutMinutes
        let value = minutes > 0 ? "\(minutes) 分钟" : "--"
        return DashboardCardData(
            id: "workout",
            icon: "figure.run",
            label: "运动",
            value: value,
            tint: TodayTheme.orange
        )
    }

    private var sleepCard: DashboardCardData {
        let hours = totalSleepHours
        let value = hours > 0 ? "\(hours) 小时" : "--"
        return DashboardCardData(
            id: "sleep",
            icon: "moon.fill",
            label: "睡眠",
            value: value,
            tint: TodayTheme.sleepIndigo
        )
    }

    private var screenTimeCard: DashboardCardData {
        // Try real DeviceActivity data from shared UserDefaults first
        if let data = UserDefaults(suiteName: SharedAppGroup.identifier)?.data(forKey: "today.screenTime.summary"),
           let summary = try? JSONDecoder().decode(ScreenTimeSummary.self, from: data),
           Calendar.current.isDateInToday(summary.date),
           summary.totalDuration > 0 {
            let hours = Int(summary.totalDuration) / 3600
            let minutes = (Int(summary.totalDuration) % 3600) / 60
            let value = hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
            return DashboardCardData(
                id: "screenTime",
                icon: "iphone",
                label: "屏幕时间",
                value: value,
                tint: TodayTheme.purple
            )
        }

        // Fallback to existing logic
        let screenTimeStat = timeline?.stats.first { $0.title == "屏幕时间" }
        let value = screenTimeStat?.value ?? screenTimeFromEntries ?? "--"
        return DashboardCardData(
            id: "screenTime",
            icon: "iphone",
            label: "屏幕时间",
            value: value,
            tint: TodayTheme.purple
        )
    }

    private var spendingCard: DashboardCardData {
        let total = totalSpending
        let value = total > 0 ? "¥\(Int(total))" : "--"
        return DashboardCardData(
            id: "spending",
            icon: "yensign.circle.fill",
            label: "消费",
            value: value,
            tint: TodayTheme.rose
        )
    }

    private var stepsCard: DashboardCardData {
        let steps = totalSteps
        let value = steps > 0 ? formatNumber(steps) : "--"
        return DashboardCardData(
            id: "steps",
            icon: "figure.walk",
            label: "步数",
            value: value,
            tint: TodayTheme.walkGreen
        )
    }

    private var shutterCard: DashboardCardData {
        let count = shutterCount
        let value = count > 0 ? "\(count) 条" : "--"
        return DashboardCardData(
            id: "shutter",
            icon: "camera.fill",
            label: "快门",
            value: value,
            tint: Color.accentColor
        )
    }

    // MARK: - Data Extraction

    private var totalWorkoutMinutes: Int {
        guard let entries = timeline?.entries else { return 0 }
        let workoutEntries = entries.filter { $0.kind == .workout }
        let totalSeconds = workoutEntries.reduce(0.0) { $0 + $1.duration }
        return Int(totalSeconds / 60)
    }

    private var totalSleepHours: Int {
        guard let entries = timeline?.entries else { return 0 }
        let sleepEntries = entries.filter { $0.kind == .sleep }
        let totalSeconds = sleepEntries.reduce(0.0) { $0 + $1.duration }
        return Int(totalSeconds / 3600)
    }

    private var totalSteps: Int {
        // First try stats from PhoneTimelineDataProvider (pedometer-based)
        if let stepStat = timeline?.stats.first(where: { $0.id == "steps" }),
           let steps = Int(stepStat.value) {
            return steps
        }
        // Fallback to entry-level metrics (HealthKit-based)
        guard let entries = timeline?.entries else { return 0 }
        return entries.compactMap { $0.associatedMetrics?.stepCount }.reduce(0, +)
    }

    private var totalSpending: Double {
        guard let entries = timeline?.entries else { return 0 }
        let spendingEntries = entries.filter { $0.kind == .spending }
        return spendingEntries.reduce(0.0) { total, event in
            // Parse amount from displayName (format: "餐饮 ¥35")
            let name = event.displayName
            if let range = name.range(of: "¥") {
                let amountStr = name[range.upperBound...]
                    .trimmingCharacters(in: .whitespaces)
                    .components(separatedBy: CharacterSet.decimalDigits.inverted)
                    .joined()
                return total + (Double(amountStr) ?? 0)
            }
            return total
        }
    }

    private var shutterCount: Int {
        guard let entries = timeline?.entries else { return 0 }
        return entries.filter { $0.kind == .shutter }.count
    }

    private var screenTimeFromEntries: String? {
        guard let entries = timeline?.entries else { return nil }
        let screenTimeEntries = entries.filter { $0.kind == .screenTime }
        guard !screenTimeEntries.isEmpty else { return nil }
        let totalSeconds = screenTimeEntries.reduce(0.0) { $0 + $1.duration }
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    // MARK: - Formatting

    private func formatNumber(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static let dateHeaderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 EEEE"
        return formatter
    }()
}
