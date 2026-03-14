import Foundation

struct WatchEventInferenceEngine {
    private let baseEngine: any EventInferring

    init(baseEngine: any EventInferring = HealthKitEventInferenceEngine()) {
        self.baseEngine = baseEngine
    }

    func inferTimeline(from rawData: DayRawData, on date: Date) async throws -> DayTimeline {
        let entries = try await baseEngine.inferEvents(from: rawData, on: date)

        return DayTimeline(
            date: date,
            summary: makeSummary(from: rawData),
            source: .healthKit,
            stats: makeStats(from: rawData),
            entries: entries
        )
    }

    private func makeSummary(from rawData: DayRawData) -> String {
        if !rawData.workouts.isEmpty {
            return "这是 Apple Watch 本地根据心率、步数、睡眠和运动推理出的今日事件。"
        }

        if !rawData.heartRateSamples.isEmpty || !rawData.stepSamples.isEmpty || !rawData.sleepSamples.isEmpty {
            return "手机数据暂时没更新时，Apple Watch 会先用本地健康数据补上今天的主线。"
        }

        return "Apple Watch 还没有产生足够的健康数据样本。"
    }

    private func makeStats(from rawData: DayRawData) -> [TimelineStat] {
        if let activitySummary = rawData.activitySummary {
            return [
                TimelineStat(
                    title: "活动",
                    value: "\(formatWholeNumber(activitySummary.activeEnergyBurned))/\(formatWholeNumber(activitySummary.activeEnergyGoal)) kcal"
                ),
                TimelineStat(
                    title: "锻炼",
                    value: "\(formatWholeNumber(activitySummary.exerciseMinutes))/\(formatWholeNumber(activitySummary.exerciseGoal)) 分钟"
                ),
                TimelineStat(
                    title: "站立",
                    value: "\(activitySummary.standHours)/\(activitySummary.standGoal) 小时"
                )
            ]
        }

        let stepCount = rawData.stepSamples.reduce(0.0) { $0 + $1.value }
        let activeEnergy = rawData.activeEnergySamples.reduce(0.0) { $0 + $1.value }

        return [
            TimelineStat(title: "步数", value: formatWholeNumber(stepCount)),
            TimelineStat(title: "能量", value: "\(formatWholeNumber(activeEnergy)) kcal"),
            TimelineStat(title: "训练", value: "\(rawData.workouts.count)")
        ]
    }

    private func formatWholeNumber(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }
}
