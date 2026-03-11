import Foundation
import HealthKit

final class HealthKitTimelineDataProvider: TimelineDataProviding {
    let source: TimelineSource = .healthKit

    private let healthStore = HKHealthStore()
    private let calendar = Calendar.current
    private let authorizationGate = HealthAuthorizationGate()

    func loadTimeline(for date: Date) async throws -> DayTimeline {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw TimelineDataError.healthDataUnavailable
        }

        try await requestAuthorizationIfNeeded()

        let startOfDay = calendar.startOfDay(for: date)

        async let stepCount = fetchCumulativeQuantity(.stepCount, unit: .count(), start: startOfDay, end: date)
        async let activeEnergy = fetchCumulativeQuantity(.activeEnergyBurned, unit: .kilocalorie(), start: startOfDay, end: date)
        async let sleepHours = fetchSleepHours(referenceDate: date)
        async let workouts = fetchWorkouts(start: startOfDay, end: date)

        let steps = try await stepCount
        let energy = try await activeEnergy
        let sleep = try await sleepHours
        let workoutSamples = try await workouts

        let entries = buildEntries(
            referenceDate: date,
            steps: steps,
            activeEnergy: energy,
            sleepHours: sleep,
            workouts: workoutSamples
        )

        if entries.isEmpty {
            throw TimelineDataError.noDataForToday
        }

        return DayTimeline(
            date: date,
            summary: "这条时间线来自今天这台设备里的 HealthKit 数据。",
            source: source,
            stats: [
                TimelineStat(title: "步数", value: formatWholeNumber(steps)),
                TimelineStat(title: "能量", value: "\(formatWholeNumber(energy)) kcal"),
                TimelineStat(title: "训练", value: "\(workoutSamples.count)")
            ],
            entries: entries
        )
    }

    private func requestAuthorizationIfNeeded() async throws {
        let readTypes = [
            HKObjectType.quantityType(forIdentifier: .stepCount),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            HKObjectType.workoutType()
        ].compactMap { $0 }

        let authorizationStatuses = readTypes.map { healthStore.authorizationStatus(for: $0) }

        if authorizationStatuses.contains(.sharingDenied) {
            throw TimelineDataError.healthDataUnavailable
        }

        guard authorizationStatuses.contains(.notDetermined) else {
            return
        }

        try await authorizationGate.authorizeIfNeeded { [healthStore] in
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                healthStore.requestAuthorization(toShare: [], read: Set(readTypes)) { success, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    if success {
                        continuation.resume(returning: ())
                    } else {
                        continuation.resume(throwing: TimelineDataError.authorizationDenied)
                    }
                }
            }
        }
    }

    private func fetchCumulativeQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async throws -> Double {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            return 0
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error {
                    continuation.resume(throwing: TimelineDataError.queryFailed(error.localizedDescription))
                    return
                }

                let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }

            healthStore.execute(query)
        }
    }

    private func fetchSleepHours(referenceDate: Date) async throws -> Double {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return 0
        }

        let startOfDay = calendar.startOfDay(for: referenceDate)
        let intervalStart = calendar.date(byAdding: .hour, value: -12, to: startOfDay) ?? startOfDay
        let predicate = HKQuery.predicateForSamples(withStart: intervalStart, end: referenceDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: TimelineDataError.queryFailed(error.localizedDescription))
                    return
                }

                let totalSleep = (samples as? [HKCategorySample] ?? [])
                    .filter { Self.sleepValues.contains($0.value) }
                    .reduce(0.0) { total, sample in
                        total + sample.endDate.timeIntervalSince(sample.startDate)
                    }

                continuation.resume(returning: totalSleep / 3600)
            }

            healthStore.execute(query)
        }
    }

    private func fetchWorkouts(start: Date, end: Date) async throws -> [HKWorkout] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let sortDescriptors = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: sortDescriptors
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: TimelineDataError.queryFailed(error.localizedDescription))
                    return
                }

                continuation.resume(returning: samples as? [HKWorkout] ?? [])
            }

            healthStore.execute(query)
        }
    }

    private func buildEntries(
        referenceDate: Date,
        steps: Double,
        activeEnergy: Double,
        sleepHours: Double,
        workouts: [HKWorkout]
    ) -> [TimelineEntry] {
        var entries: [TimelineEntry] = []
        let dayStamp = Int(calendar.startOfDay(for: referenceDate).timeIntervalSince1970)

        if sleepHours > 0 {
            entries.append(
                TimelineEntry(
                    id: "healthkit-sleep-\(dayStamp)",
                    title: "睡眠",
                    detail: String(format: "今天开始前大约记录了 %.1f 小时睡眠。", sleepHours),
                    moment: .overnight,
                    kind: .sleep,
                    durationMinutes: Int(sleepHours * 60)
                )
            )
        }

        if steps > 0 || activeEnergy > 0 {
            entries.append(
                TimelineEntry(
                    id: "healthkit-activity-\(dayStamp)",
                    title: "活动",
                    detail: "今天目前累计 \(formatWholeNumber(steps)) 步，消耗 \(formatWholeNumber(activeEnergy)) kcal。",
                    moment: .daytime,
                    kind: .move
                )
            )
        }

        for workout in workouts {
            let minutes = Int(workout.duration / 60)
            let activity = workout.workoutActivityType.displayName
            let startMinute = minuteOfDay(for: workout.startDate)
            let endMinute = minuteOfDay(for: workout.endDate)

            entries.append(
                TimelineEntry(
                    id: "healthkit-workout-\(Int(workout.startDate.timeIntervalSince1970))-\(Int(workout.endDate.timeIntervalSince1970))-\(activity)",
                    title: activity,
                    detail: "HealthKit 记录了 \(minutes) 分钟训练。",
                    moment: .range(startMinuteOfDay: startMinute, endMinuteOfDay: endMinute),
                    kind: .move,
                    durationMinutes: minutes
                )
            )
        }

        if entries.isEmpty && calendar.isDate(referenceDate, inSameDayAs: Date()) {
            entries.append(
                TimelineEntry(
                    id: "healthkit-empty-\(dayStamp)",
                    title: "等待数据",
                    detail: "HealthKit 已连接，但今天还没有可见样本。",
                    moment: .daytime,
                    kind: .pause
                )
            )
        }

        return entries
    }

    private func formatWholeNumber(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }

    private func minuteOfDay(for date: Date) -> Int {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return (hour * 60) + minute
    }

    private static let sleepValues: Set<Int> = [
        HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
        HKCategoryValueSleepAnalysis.asleepCore.rawValue,
        HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
        HKCategoryValueSleepAnalysis.asleepREM.rawValue
    ]
}

private actor HealthAuthorizationGate {
    private enum State {
        case idle
        case inFlight(Task<Void, Error>)
        case authorized
    }

    private var state: State = .idle

    func authorizeIfNeeded(_ operation: @escaping @Sendable () async throws -> Void) async throws {
        switch state {
        case .authorized:
            return
        case let .inFlight(task):
            try await task.value
        case .idle:
            let task = Task {
                try await operation()
            }
            state = .inFlight(task)

            do {
                try await task.value
                state = .authorized
            } catch {
                state = .idle
                throw error
            }
        }
    }
}

private extension HKWorkoutActivityType {
    var displayName: String {
        switch self {
        case .walking:
            return "步行"
        case .running:
            return "跑步"
        case .cycling:
            return "骑行"
        case .traditionalStrengthTraining:
            return "力量"
        case .functionalStrengthTraining:
            return "功能力量"
        case .mindAndBody:
            return "身心"
        case .yoga:
            return "瑜伽"
        case .hiking:
            return "徒步"
        default:
            return "训练"
        }
    }
}
