import Foundation
import HealthKit

final class HealthKitTimelineDataProvider: TimelineDataProviding {
    let source: TimelineSource = .healthKit

    private let healthStore: HKHealthStore
    private let calendar: Calendar
    private let authorizationGate: HealthAuthorizationGate
    private let eventInferenceEngine: any EventInferring
    private var cachedAggregator: DayDataAggregator?

    init(
        healthStore: HKHealthStore = HKHealthStore(),
        calendar: Calendar = .current,
        authorizationGate: HealthAuthorizationGate = HealthAuthorizationGate(),
        eventInferenceEngine: any EventInferring = HealthKitEventInferenceEngine()
    ) {
        self.healthStore = healthStore
        self.calendar = calendar
        self.authorizationGate = authorizationGate
        self.eventInferenceEngine = eventInferenceEngine
    }

    func loadTimeline(for date: Date) async throws -> DayTimeline {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw TimelineDataError.healthDataUnavailable
        }

        try await requestAuthorizationIfNeeded()

        let rawData = await getAggregator().loadRawData(for: date)
        let entries = try await eventInferenceEngine.inferEvents(from: rawData, on: date)

        return DayTimeline(
            date: date,
            summary: makeSummary(from: rawData),
            source: source,
            stats: makeStats(from: rawData),
            entries: entries
        )
    }

    func loadRawData(for date: Date) async -> DayRawData {
        guard HKHealthStore.isHealthDataAvailable() else {
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

        return DayRawData(
            date: date,
            activitySummary: await activitySummary,
            heartRateSamples: await heartRateSamples,
            stepSamples: await stepSamples,
            sleepSamples: await sleepSamples,
            workouts: await workouts,
            activeEnergySamples: await activeEnergySamples
        )
    }

    private func requestAuthorizationIfNeeded() async throws {
        let readTypes = [
            HKObjectType.activitySummaryType(),
            HKObjectType.quantityType(forIdentifier: .heartRate),
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
            do {
                try await healthStore.requestAuthorization(toShare: [], read: Set(readTypes))
            } catch {
                throw TimelineDataError.authorizationDenied
            }
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

    private func makeSummary(from rawData: DayRawData) -> String {
        let hasContext = !rawData.hourlyWeather.isEmpty || !rawData.locationVisits.isEmpty || !rawData.photos.isEmpty
        if hasContext {
            return "这条时间线综合了 HealthKit、天气、地点和照片线索。"
        }
        return "这条时间线来自今天这台设备里的 HealthKit 数据。"
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

    private func getAggregator() async -> DayDataAggregator {
        if let cachedAggregator {
            return cachedAggregator
        }

        let locationService = await MainActor.run {
            LocationService.shared
        }

        let aggregator = DayDataAggregator(
            healthProvider: self,
            weatherService: ToDayWeatherService(),
            locationService: locationService,
            photoService: PhotoService()
        )

        cachedAggregator = aggregator
        return aggregator
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

actor HealthAuthorizationGate {
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
