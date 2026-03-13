import Foundation
import HealthKit

/// 事件推理引擎协议
protocol EventInferring {
    /// 从一天的原始数据推理出事件列表
    func inferEvents(from rawData: DayRawData, on date: Date) async throws -> [InferredEvent]
}

/// 一天的原始 HealthKit 数据容器
struct DayRawData: Sendable {
    let date: Date
    let activitySummary: ActivitySummaryData?
    let heartRateSamples: [DateValueSample]
    let stepSamples: [DateValueSample]
    let sleepSamples: [SleepSample]
    let workouts: [WorkoutSample]
    let activeEnergySamples: [DateValueSample]
    let moodRecords: [MoodRecord]

    init(
        date: Date,
        activitySummary: ActivitySummaryData? = nil,
        heartRateSamples: [DateValueSample] = [],
        stepSamples: [DateValueSample] = [],
        sleepSamples: [SleepSample] = [],
        workouts: [WorkoutSample] = [],
        activeEnergySamples: [DateValueSample] = [],
        moodRecords: [MoodRecord] = []
    ) {
        self.date = date
        self.activitySummary = activitySummary
        self.heartRateSamples = heartRateSamples
        self.stepSamples = stepSamples
        self.sleepSamples = sleepSamples
        self.workouts = workouts
        self.activeEnergySamples = activeEnergySamples
        self.moodRecords = moodRecords
    }
}

struct ActivitySummaryData: Sendable {
    let activeEnergyBurned: Double
    let activeEnergyGoal: Double
    let exerciseMinutes: Double
    let exerciseGoal: Double
    let standHours: Int
    let standGoal: Int
}

/// 通用的 日期-数值 采样点
struct DateValueSample: Identifiable, Hashable, Sendable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let value: Double

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        value: Double
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.value = value
    }
}

/// 睡眠采样
struct SleepSample: Identifiable, Hashable, Sendable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let stage: SleepStage

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        stage: SleepStage
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.stage = stage
    }
}

enum SleepStage: String, Codable, Hashable, Sendable {
    case awake
    case rem
    case light
    case deep
    case unknown
}

struct SleepStageSegment: Codable, Hashable, Sendable {
    let start: Date
    let end: Date
    let stage: SleepStage
}

/// 运动采样
struct WorkoutSample: Identifiable, Hashable, Sendable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let activityType: UInt
    let activeEnergy: Double?
    let distance: Double?

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        activityType: UInt,
        activeEnergy: Double? = nil,
        distance: Double? = nil
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.activityType = activityType
        self.activeEnergy = activeEnergy
        self.distance = distance
    }

    var displayName: String {
        HKWorkoutActivityType(rawValue: activityType)?.todayDisplayName ?? "训练"
    }
}

private extension HKWorkoutActivityType {
    var todayDisplayName: String {
        switch self {
        case .running:
            return "跑步"
        case .walking:
            return "走路"
        case .hiking:
            return "徒步"
        case .cycling:
            return "骑行"
        case .traditionalStrengthTraining, .functionalStrengthTraining:
            return "力量训练"
        case .mindAndBody:
            return "身心训练"
        case .swimming:
            return "游泳"
        case .yoga:
            return "瑜伽"
        default:
            return "训练"
        }
    }
}
