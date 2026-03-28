import Foundation

// MARK: - Sensor Type

enum SensorType: String, Codable, Sendable {
    case motion
    case location
    case pedometer
    case deviceState
    case healthKit
}

// MARK: - Sensor Reading

struct SensorReading: Codable, Identifiable, Sendable {
    let id: UUID
    let sensorType: SensorType
    let timestamp: Date
    let endTimestamp: Date?
    let payload: SensorPayload

    init(id: UUID = UUID(), sensorType: SensorType, timestamp: Date,
         endTimestamp: Date? = nil, payload: SensorPayload) {
        self.id = id
        self.sensorType = sensorType
        self.timestamp = timestamp
        self.endTimestamp = endTimestamp
        self.payload = payload
    }
}

// MARK: - Sensor Payload

enum SensorPayload: Codable, Sendable {
    case motion(activity: MotionActivity, confidence: MotionConfidence)
    case location(latitude: Double, longitude: Double, horizontalAccuracy: Double)
    case visit(latitude: Double, longitude: Double, arrivalDate: Date, departureDate: Date?)
    case pedometer(steps: Int, distance: Double?, floorsAscended: Int?)
    case deviceState(event: DeviceEvent)
    case healthKit(metric: String, value: Double)
}

// MARK: - Motion Types

enum MotionActivity: String, Codable, Sendable, CaseIterable {
    case stationary, walking, running, automotive, cycling, unknown
}

enum MotionConfidence: String, Codable, Sendable, Comparable {
    case low, medium, high

    static func < (lhs: Self, rhs: Self) -> Bool {
        let order: [MotionConfidence] = [.low, .medium, .high]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

// MARK: - Device Events

enum DeviceEvent: String, Codable, Sendable, CaseIterable {
    case screenUnlock, screenLock, chargingStart, chargingStop
}
