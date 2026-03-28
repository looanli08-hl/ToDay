import Foundation
import HealthKit

final class HealthKitCollector: SensorCollecting, @unchecked Sendable {
    let sensorType: SensorType = .healthKit
    private let healthStore = HKHealthStore()
    private let authGate = HealthAuthorizationGate()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorizationIfNeeded() async throws {
        guard isAvailable else { return }
        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKCategoryType(.sleepAnalysis),
            HKWorkoutType.workoutType(),
        ]
        try await authGate.authorizeIfNeeded {
            try await self.healthStore.requestAuthorization(toShare: [], read: readTypes)
        }
    }

    func collectData(for date: Date) async throws -> [SensorReading] {
        guard isAvailable else { return [] }
        try await requestAuthorizationIfNeeded()
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!

        var readings: [SensorReading] = []

        // Heart rate samples
        let hrSamples = try await queryQuantitySamples(type: .heartRate, start: start, end: end)
        for sample in hrSamples {
            let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            readings.append(SensorReading(
                sensorType: .healthKit, timestamp: sample.startDate,
                endTimestamp: sample.endDate,
                payload: .healthKit(metric: "heartRate", value: bpm)
            ))
        }

        // Sleep samples
        let sleepSamples = try await queryCategorySamples(type: .sleepAnalysis, start: start, end: end)
        for sample in sleepSamples {
            readings.append(SensorReading(
                sensorType: .healthKit, timestamp: sample.startDate,
                endTimestamp: sample.endDate,
                payload: .healthKit(metric: "sleep.\(sample.value)", value: Double(sample.value))
            ))
        }

        return readings
    }

    private func queryQuantitySamples(type: HKQuantityTypeIdentifier, start: Date, end: Date) async throws -> [HKQuantitySample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(type), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        return try await descriptor.result(for: healthStore)
    }

    private func queryCategorySamples(type: HKCategoryTypeIdentifier, start: Date, end: Date) async throws -> [HKCategorySample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(type), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        return try await descriptor.result(for: healthStore)
    }
}
