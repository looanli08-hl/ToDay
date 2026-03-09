import Foundation
import HealthKit

struct HealthKitTimelineDataProvider: TimelineDataProviding {
    let source: TimelineSource = .healthKit

    private let healthStore = HKHealthStore()
    private let calendar = Calendar.current
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    func loadTimeline(for date: Date) async throws -> DayTimeline {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw TimelineDataError.healthDataUnavailable
        }

        try await requestAuthorization()

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
            summary: "Built from today's HealthKit samples on this device.",
            source: source,
            stats: [
                TimelineStat(title: "Steps", value: formatWholeNumber(steps)),
                TimelineStat(title: "Energy", value: "\(formatWholeNumber(energy)) kcal"),
                TimelineStat(title: "Workouts", value: "\(workoutSamples.count)")
            ],
            entries: entries
        )
    }

    private func requestAuthorization() async throws {
        let readTypes = Set([
            HKObjectType.quantityType(forIdentifier: .stepCount),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            HKObjectType.workoutType()
        ].compactMap { $0 })

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
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

        if sleepHours > 0 {
            entries.append(
                TimelineEntry(
                    title: "Sleep",
                    detail: String(format: "%.1f hours of recorded sleep before today began.", sleepHours),
                    timeRange: "Overnight",
                    kind: .sleep
                )
            )
        }

        if steps > 0 || activeEnergy > 0 {
            entries.append(
                TimelineEntry(
                    title: "Activity",
                    detail: "\(formatWholeNumber(steps)) steps and \(formatWholeNumber(activeEnergy)) kcal so far today.",
                    timeRange: "Today",
                    kind: .move
                )
            )
        }

        for workout in workouts {
            let minutes = Int(workout.duration / 60)
            let activity = workout.workoutActivityType.displayName
            let timeRange = "\(timeFormatter.string(from: workout.startDate)) - \(timeFormatter.string(from: workout.endDate))"

            entries.append(
                TimelineEntry(
                    title: activity,
                    detail: "\(minutes) min workout recorded in HealthKit.",
                    timeRange: timeRange,
                    kind: .move
                )
            )
        }

        if entries.isEmpty && calendar.isDate(referenceDate, inSameDayAs: Date()) {
            entries.append(
                TimelineEntry(
                    title: "Waiting for data",
                    detail: "HealthKit is connected, but there are no visible samples for this day yet.",
                    timeRange: "Today",
                    kind: .pause
                )
            )
        }

        return entries
    }

    private func formatWholeNumber(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }

    private static let sleepValues: Set<Int> = [
        HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
        HKCategoryValueSleepAnalysis.asleepCore.rawValue,
        HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
        HKCategoryValueSleepAnalysis.asleepREM.rawValue
    ]
}

private extension HKWorkoutActivityType {
    var displayName: String {
        switch self {
        case .walking:
            return "Walk"
        case .running:
            return "Run"
        case .cycling:
            return "Cycle"
        case .traditionalStrengthTraining:
            return "Strength"
        case .functionalStrengthTraining:
            return "Functional Strength"
        case .mindAndBody:
            return "Mind and Body"
        case .yoga:
            return "Yoga"
        case .hiking:
            return "Hike"
        default:
            return "Workout"
        }
    }
}
