import CoreLocation
import Foundation

final class LocationCollector: NSObject, SensorCollecting, CLLocationManagerDelegate, @unchecked Sendable {
    let sensorType: SensorType = .location
    private let store: SensorDataStore
    private let locationManager = CLLocationManager()

    var isAvailable: Bool {
        CLLocationManager.significantLocationChangeMonitoringAvailable()
    }

    init(store: SensorDataStore) {
        self.store = store
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestAuthorizationIfNeeded() async throws {
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestAlwaysAuthorization()
        }
    }

    func collectData(for date: Date) async throws -> [SensorReading] {
        try await MainActor.run {
            try store.readings(for: date, type: .location)
        }
    }

    func startMonitoring() {
        // Re-register immediately if already authorized.
        // This handles the kill-and-relaunch case where iOS fires a significant
        // location change, re-launches the app, and the delegate callback will
        // NOT fire again — we must call the monitoring APIs directly at startup.
        if locationManager.authorizationStatus == .authorizedAlways {
            locationManager.startMonitoringVisits()
            locationManager.startMonitoringSignificantLocationChanges()
        }
    }

    // MARK: - Recording

    @MainActor
    func recordVisit(latitude: Double, longitude: Double, arrivalDate: Date, departureDate: Date?) {
        let reading = SensorReading(
            sensorType: .location,
            timestamp: arrivalDate,
            endTimestamp: departureDate,
            payload: .visit(
                latitude: latitude, longitude: longitude,
                arrivalDate: arrivalDate, departureDate: departureDate
            )
        )
        try? store.save([reading])
    }

    @MainActor
    func recordLocationUpdate(latitude: Double, longitude: Double, accuracy: Double) {
        let reading = SensorReading(
            sensorType: .location,
            timestamp: Date(),
            payload: .location(latitude: latitude, longitude: longitude, horizontalAccuracy: accuracy)
        )
        try? store.save([reading])
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        let dep = visit.departureDate == Date.distantFuture ? nil : visit.departureDate
        Task { @MainActor in
            recordVisit(
                latitude: visit.coordinate.latitude,
                longitude: visit.coordinate.longitude,
                arrivalDate: visit.arrivalDate,
                departureDate: dep
            )
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            recordLocationUpdate(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                accuracy: location.horizontalAccuracy
            )
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways:
            // Fresh authorization upgrade — start background monitoring immediately.
            manager.startMonitoringVisits()
            manager.startMonitoringSignificantLocationChanges()
        case .authorizedWhenInUse:
            // Background significant location changes and visits require Always.
            // Stop any active monitoring — foreground-only access cannot power the timeline.
            manager.stopMonitoringVisits()
            manager.stopMonitoringSignificantLocationChanges()
        default:
            break
        }
    }
}
