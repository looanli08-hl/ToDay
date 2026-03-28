import Foundation

protocol SensorCollecting: Sendable {
    var sensorType: SensorType { get }
    var isAvailable: Bool { get }
    func collectData(for date: Date) async throws -> [SensorReading]
    func requestAuthorizationIfNeeded() async throws
}
