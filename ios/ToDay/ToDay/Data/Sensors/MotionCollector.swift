import CoreMotion
import Foundation

final class MotionCollector: SensorCollecting, @unchecked Sendable {
    let sensorType: SensorType = .motion
    private let activityManager = CMMotionActivityManager()

    var isAvailable: Bool {
        CMMotionActivityManager.isActivityAvailable()
    }

    func requestAuthorizationIfNeeded() async throws {
        // CoreMotion authorization is triggered on first query
    }

    func collectData(for date: Date) async throws -> [SensorReading] {
        guard isAvailable else { return [] }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!

        return try await withCheckedThrowingContinuation { continuation in
            activityManager.queryActivityStarting(from: start, to: end, to: .main) { activities, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let readings = (activities ?? []).map { activity -> SensorReading in
                    let motionActivity = Self.mapActivity(
                        stationary: activity.stationary,
                        walking: activity.walking,
                        running: activity.running,
                        automotive: activity.automotive,
                        cycling: activity.cycling
                    )
                    let confidence = Self.mapConfidence(activity.confidence.rawValue)
                    return SensorReading(
                        sensorType: .motion,
                        timestamp: activity.startDate,
                        payload: .motion(activity: motionActivity, confidence: confidence)
                    )
                }
                continuation.resume(returning: readings)
            }
        }
    }

    static func mapActivity(stationary: Bool, walking: Bool, running: Bool,
                            automotive: Bool, cycling: Bool) -> MotionActivity {
        if running { return .running }
        if cycling { return .cycling }
        if automotive { return .automotive }
        if walking { return .walking }
        if stationary { return .stationary }
        return .unknown
    }

    static func mapConfidence(_ raw: Int) -> MotionConfidence {
        switch raw {
        case 2: return .high
        case 1: return .medium
        default: return .low
        }
    }
}
