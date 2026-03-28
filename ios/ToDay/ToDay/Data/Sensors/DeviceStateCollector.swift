import Foundation
import UIKit

final class DeviceStateCollector: SensorCollecting, @unchecked Sendable {
    let sensorType: SensorType = .deviceState
    let isAvailable: Bool = true

    private let store: SensorDataStore
    private var observers: [NSObjectProtocol] = []

    init(store: SensorDataStore) {
        self.store = store
    }

    func requestAuthorizationIfNeeded() async throws {}

    func collectData(for date: Date) async throws -> [SensorReading] {
        try await MainActor.run {
            try store.readings(for: date, type: .deviceState)
        }
    }

    @MainActor
    func startMonitoring() {
        stopMonitoring()
        let nc = NotificationCenter.default

        observers.append(nc.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            let state = UIDevice.current.batteryState
            switch state {
            case .charging, .full:
                self?.recordEvent(.chargingStart)
            case .unplugged:
                self?.recordEvent(.chargingStop)
            default: break
            }
        })

        observers.append(nc.addObserver(
            forName: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.recordEvent(.screenUnlock)
        })

        observers.append(nc.addObserver(
            forName: UIApplication.protectedDataWillBecomeUnavailableNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.recordEvent(.screenLock)
        })

        UIDevice.current.isBatteryMonitoringEnabled = true
    }

    @MainActor
    func stopMonitoring() {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
    }

    @MainActor
    func recordEvent(_ event: DeviceEvent) {
        let reading = SensorReading(
            sensorType: .deviceState,
            timestamp: Date(),
            payload: .deviceState(event: event)
        )
        try? store.save([reading])
    }
}
