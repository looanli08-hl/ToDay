import CoreMotion
import Foundation

final class PedometerCollector: SensorCollecting, @unchecked Sendable {
    let sensorType: SensorType = .pedometer
    private let pedometer = CMPedometer()

    var isAvailable: Bool {
        CMPedometer.isStepCountingAvailable()
    }

    func requestAuthorizationIfNeeded() async throws {}

    func collectData(for date: Date) async throws -> [SensorReading] {
        guard isAvailable else { return [] }
        var readings: [SensorReading] = []
        for segment in Self.hourSegments(for: date) {
            if let reading = try? await querySegment(start: segment.start, end: segment.end) {
                readings.append(reading)
            }
        }
        return readings
    }

    private func querySegment(start: Date, end: Date) async throws -> SensorReading? {
        try await withCheckedThrowingContinuation { continuation in
            pedometer.queryPedometerData(from: start, to: end) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let data, data.numberOfSteps.intValue > 0 else {
                    continuation.resume(returning: nil)
                    return
                }
                let reading = SensorReading(
                    sensorType: .pedometer,
                    timestamp: start,
                    endTimestamp: end,
                    payload: .pedometer(
                        steps: data.numberOfSteps.intValue,
                        distance: data.distance?.doubleValue,
                        floorsAscended: data.floorsAscended?.intValue
                    )
                )
                continuation.resume(returning: reading)
            }
        }
    }

    static func hourSegments(for date: Date) -> [(start: Date, end: Date)] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        return (0..<24).map { hour in
            let start = dayStart.addingTimeInterval(Double(hour) * 3600)
            let end = start.addingTimeInterval(3600)
            return (start, end)
        }
    }
}
