import Foundation

final class CareNudgeEngine {
    /// Minimum consecutive workout days to trigger encouragement
    private let exerciseStreakThreshold = 3

    /// Screen time hours threshold for gentle reminder
    private let screenTimeHoursThreshold: Double = 6.0

    /// Days without shutter records to trigger check-in
    private let noShutterDaysThreshold = 3

    /// Evaluate recent data and return applicable care nudges.
    ///
    /// - Parameters:
    ///   - recentTimelines: Recent day timelines, most recent first
    ///   - shutterRecords: All available shutter records
    ///   - screenTimeHours: Today's screen time in hours (optional, used for high screen time check)
    /// - Returns: Array of CareNudge messages to show
    func evaluate(
        recentTimelines: [DayTimeline],
        shutterRecords: [ShutterRecord],
        screenTimeHours: Double? = nil
    ) -> [CareNudge] {
        var nudges: [CareNudge] = []

        if let exerciseNudge = checkExerciseStreak(timelines: recentTimelines) {
            nudges.append(exerciseNudge)
        }

        if let screenTimeNudge = checkScreenTime(hours: screenTimeHours) {
            nudges.append(screenTimeNudge)
        }

        if let shutterNudge = checkShutterActivity(records: shutterRecords) {
            nudges.append(shutterNudge)
        }

        return nudges
    }

    // MARK: - Rule: Consecutive Exercise Days

    private func checkExerciseStreak(timelines: [DayTimeline]) -> CareNudge? {
        let calendar = Calendar.current
        var consecutiveDays = 0

        // Sort by date descending (most recent first)
        let sorted = timelines.sorted { $0.date > $1.date }

        for (index, timeline) in sorted.enumerated() {
            let hasWorkout = timeline.entries.contains { $0.kind == .workout }
            if hasWorkout {
                // Check that this day is consecutive with the previous one
                if index == 0 {
                    consecutiveDays = 1
                } else {
                    let currentDay = calendar.startOfDay(for: timeline.date)
                    let previousDay = calendar.startOfDay(for: sorted[index - 1].date)
                    let daysBetween = calendar.dateComponents([.day], from: currentDay, to: previousDay).day ?? 0
                    if daysBetween == 1 {
                        consecutiveDays += 1
                    } else {
                        break
                    }
                }
            } else {
                break
            }
        }

        guard consecutiveDays >= exerciseStreakThreshold else { return nil }

        return CareNudge(
            kind: .exerciseStreak,
            message: "连续 \(consecutiveDays) 天运动了，太棒了！",
            subtitle: "坚持下去，身体会感谢你的",
            iconName: "flame.fill"
        )
    }

    // MARK: - Rule: High Screen Time

    private func checkScreenTime(hours: Double?) -> CareNudge? {
        guard let hours, hours >= screenTimeHoursThreshold else { return nil }

        let hoursInt = Int(hours)
        return CareNudge(
            kind: .highScreenTime,
            message: "今天屏幕时间已经 \(hoursInt) 小时了",
            subtitle: "站起来走走，看看窗外的风景吧",
            iconName: "iphone.gen3.slash"
        )
    }

    // MARK: - Rule: No Shutter Records

    private func checkShutterActivity(records: [ShutterRecord]) -> CareNudge? {
        let calendar = Calendar.current
        let now = Date()

        // Find the most recent shutter record
        let sorted = records.sorted { $0.createdAt > $1.createdAt }

        if let latest = sorted.first {
            let daysSince = calendar.dateComponents([.day], from: latest.createdAt, to: now).day ?? 0
            guard daysSince >= noShutterDaysThreshold else { return nil }

            return CareNudge(
                kind: .noShutterCheckIn,
                message: "已经 \(daysSince) 天没有记录了",
                subtitle: "哪怕一句话，也值得被记住",
                iconName: "camera.metering.unknown"
            )
        } else {
            // No records at all
            return CareNudge(
                kind: .noShutterCheckIn,
                message: "试试记录一下生活中的小事吧",
                subtitle: "一段文字、一张照片、一句语音，都可以",
                iconName: "camera.metering.unknown"
            )
        }
    }
}
