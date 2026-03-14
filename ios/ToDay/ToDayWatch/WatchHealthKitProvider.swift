import Combine
import Foundation
import HealthKit

@MainActor
final class WatchHealthKitProvider: ObservableObject {
    private let healthStore: HKHealthStore
    private let calendar: Calendar
    private let authorizationGate: WatchHealthAuthorizationGate
    private var liveHeartRateQuery: HKAnchoredObjectQuery?

    @Published private(set) var latestHeartRate: Double?

    init(
        healthStore: HKHealthStore = HKHealthStore(),
        calendar: Calendar = .current,
        authorizationGate: WatchHealthAuthorizationGate = WatchHealthAuthorizationGate()
    ) {
        self.healthStore = healthStore
        self.calendar = calendar
        self.authorizationGate = authorizationGate
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }

        let readTypes = [
            HKObjectType.activitySummaryType(),
            HKObjectType.quantityType(forIdentifier: .heartRate),
            HKObjectType.quantityType(forIdentifier: .stepCount),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            HKObjectType.workoutType()
        ].compactMap { $0 }

        let statuses = readTypes.map { healthStore.authorizationStatus(for: $0) }
        if statuses.contains(.sharingDenied) {
            return false
        }

        guard statuses.contains(.notDetermined) else {
            return true
        }

        do {
            try await authorizationGate.authorizeIfNeeded { [healthStore] in
                try await healthStore.requestAuthorization(toShare: [], read: Set(readTypes))
            }
            return true
        } catch {
            return false
        }
    }

    func loadRawData(for date: Date) async -> DayRawData {
        guard await requestAuthorizationIfNeeded() else {
            return DayRawData(date: date)
        }

        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        let sleepWindowStart = calendar.date(byAdding: .hour, value: -12, to: startOfDay) ?? startOfDay

        async let heartRateSamples = fetchQuantitySamples(
            .heartRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            start: startOfDay,
            end: endOfDay
        )
        async let stepSamples = fetchQuantitySamples(
            .stepCount,
            unit: .count(),
            start: startOfDay,
            end: endOfDay
        )
        async let activeEnergySamples = fetchQuantitySamples(
            .activeEnergyBurned,
            unit: .kilocalorie(),
            start: startOfDay,
            end: endOfDay
        )
        async let sleepSamples = fetchSleepSamples(start: sleepWindowStart, end: endOfDay)
        async let workouts = fetchWorkouts(start: startOfDay, end: endOfDay)
        async let activitySummary = fetchActivitySummary(for: date)

        let heartRate = await heartRateSamples
        latestHeartRate = heartRate.last?.value

        return DayRawData(
            date: date,
            activitySummary: await activitySummary,
            heartRateSamples: heartRate,
            stepSamples: await stepSamples,
            sleepSamples: await sleepSamples,
            workouts: await workouts,
            activeEnergySamples: await activeEnergySamples
        )
    }

    func startLiveHeartRateStream() async {
        guard await requestAuthorizationIfNeeded(),
              let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return
        }

        if let liveHeartRateQuery {
            healthStore.stop(liveHeartRateQuery)
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: calendar.date(byAdding: .hour, value: -1, to: Date()),
            end: nil,
            options: .strictStartDate
        )

        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            Task { @MainActor in
                self?.consumeLiveHeartRate(samples)
            }
        }

        query.updateHandler = { [weak self] _, samples, _, _, _ in
            Task { @MainActor in
                self?.consumeLiveHeartRate(samples)
            }
        }

        liveHeartRateQuery = query
        healthStore.execute(query)
    }

    func stopLiveHeartRateStream() {
        guard let liveHeartRateQuery else { return }
        healthStore.stop(liveHeartRateQuery)
        self.liveHeartRateQuery = nil
    }

    private func consumeLiveHeartRate(_ samples: [HKSample]?) {
        guard let latestSample = samples?
            .compactMap({ $0 as? HKQuantitySample })
            .sorted(by: { $0.endDate < $1.endDate })
            .last else {
            return
        }

        let value = latestSample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        Task { @MainActor [weak self] in
            self?.latestHeartRate = value
        }
    }

    private func fetchQuantitySamples(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async -> [DateValueSample] {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            return []
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [HKSamplePredicate.quantitySample(type: quantityType, predicate: predicate)],
            sortDescriptors: [],
            limit: nil
        )

        do {
            let samples: [HKQuantitySample] = try await descriptor.result(for: healthStore)
            return samples
                .sorted { $0.startDate < $1.startDate }
                .map { sample in
                    DateValueSample(
                        startDate: sample.startDate,
                        endDate: sample.endDate,
                        value: sample.quantity.doubleValue(for: unit)
                    )
                }
        } catch {
            return []
        }
    }

    private func fetchSleepSamples(start: Date, end: Date) async -> [SleepSample] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return []
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [HKSamplePredicate.categorySample(type: sleepType, predicate: predicate)],
            sortDescriptors: [],
            limit: nil
        )

        do {
            let samples: [HKCategorySample] = try await descriptor.result(for: healthStore)
            return samples
                .sorted { $0.startDate < $1.startDate }
                .map { sample in
                    SleepSample(
                        startDate: sample.startDate,
                        endDate: sample.endDate,
                        stage: Self.sleepStage(for: sample.value)
                    )
                }
        } catch {
            return []
        }
    }

    private func fetchWorkouts(start: Date, end: Date) async -> [WorkoutSample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [HKSamplePredicate.workout(predicate)],
            sortDescriptors: [],
            limit: nil
        )

        do {
            let samples: [HKWorkout] = try await descriptor.result(for: healthStore)
            return samples
                .sorted { $0.startDate < $1.startDate }
                .map { workout in
                    WorkoutSample(
                        startDate: workout.startDate,
                        endDate: workout.endDate,
                        activityType: workout.workoutActivityType.rawValue,
                        activeEnergy: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
                        distance: workout.totalDistance?.doubleValue(for: .meter())
                    )
                }
        } catch {
            return []
        }
    }

    private func fetchActivitySummary(for date: Date) async -> ActivitySummaryData? {
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let predicate = HKQuery.predicate(forActivitySummariesBetweenStart: dayComponents, end: dayComponents)

        return await withCheckedContinuation { continuation in
            var hasResumed = false
            let query = HKActivitySummaryQuery(predicate: predicate) { _, summaries, error in
                guard !hasResumed else { return }
                hasResumed = true

                guard error == nil, let summary = summaries?.first else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(
                    returning: ActivitySummaryData(
                        activeEnergyBurned: summary.activeEnergyBurned.doubleValue(for: .kilocalorie()),
                        activeEnergyGoal: summary.activeEnergyBurnedGoal.doubleValue(for: .kilocalorie()),
                        exerciseMinutes: summary.appleExerciseTime.doubleValue(for: .minute()),
                        exerciseGoal: summary.appleExerciseTimeGoal.doubleValue(for: .minute()),
                        standHours: Int(summary.appleStandHours.doubleValue(for: .count()).rounded()),
                        standGoal: Int(summary.appleStandHoursGoal.doubleValue(for: .count()).rounded())
                    )
                )
            }

            healthStore.execute(query)
        }
    }

    private static func sleepStage(for value: Int) -> SleepStage {
        switch value {
        case HKCategoryValueSleepAnalysis.awake.rawValue:
            return .awake
        case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
            return .rem
        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
            return .deep
        case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
            return .light
        case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
            return .unknown
        default:
            return .unknown
        }
    }
}

actor WatchHealthAuthorizationGate {
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
