import CoreLocation
import Foundation

@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private let defaults: UserDefaults
    private let storageKey = "today.locationVisits"

    private override init() {
        self.defaults = .standard
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        startMonitoringIfPossible()
    }

    var currentLocation: CLLocation? {
        locationManager.location
    }

    func requestAuthorization() async -> Bool {
        let status = locationManager.authorizationStatus

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            startMonitoringIfPossible()
            return true
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            return false
        default:
            return false
        }
    }

    func fetchVisits(from startDate: Date, to endDate: Date) async -> [LocationVisit] {
        guard await requestAuthorization() else { return [] }

        return loadPersistedVisits()
            .filter { visit in
                DateInterval(start: visit.arrivalDate, end: visit.departureDate)
                    .intersection(with: DateInterval(start: startDate, end: endDate)) != nil
            }
            .sorted { $0.arrivalDate < $1.arrivalDate }
    }

    func reverseGeocode(coordinate: CoordinateValue) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return nil }
            return condensedPlaceName(from: placemark)
        } catch {
            return nil
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        startMonitoringIfPossible()
    }

    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        guard CLLocationCoordinate2DIsValid(visit.coordinate) else { return }

        let coordinate = CoordinateValue(
            latitude: visit.coordinate.latitude,
            longitude: visit.coordinate.longitude
        )
        let newVisit = LocationVisit(
            coordinate: coordinate,
            arrivalDate: visit.arrivalDate,
            departureDate: visit.departureDate
        )

        Task {
            let placeName = await reverseGeocode(coordinate: coordinate)
            let enrichedVisit = LocationVisit(
                id: newVisit.id,
                coordinate: coordinate,
                arrivalDate: newVisit.arrivalDate,
                departureDate: newVisit.departureDate,
                placeName: placeName
            )
            persistVisitIfNeeded(enrichedVisit)
        }
    }

    private func startMonitoringIfPossible() {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startMonitoringVisits()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        default:
            break
        }
    }

    private func loadPersistedVisits() -> [LocationVisit] {
        guard let data = defaults.data(forKey: storageKey),
              let visits = try? JSONDecoder().decode([LocationVisit].self, from: data) else {
            return []
        }

        return visits
    }

    private func savePersistedVisits(_ visits: [LocationVisit]) {
        guard let data = try? JSONEncoder().encode(visits) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func persistVisitIfNeeded(_ visit: LocationVisit) {
        var visits = loadPersistedVisits()

        let duplicate = visits.contains {
            $0.coordinate == visit.coordinate &&
            $0.arrivalDate == visit.arrivalDate &&
            $0.departureDate == visit.departureDate
        }

        guard !duplicate else { return }

        visits.append(visit)
        visits.sort { $0.arrivalDate < $1.arrivalDate }
        savePersistedVisits(visits)
    }

    private func condensedPlaceName(from placemark: CLPlacemark) -> String? {
        if let name = placemark.name, let locality = placemark.locality, !name.contains(locality) {
            return "\(name)·\(locality)"
        }

        return placemark.name ??
            placemark.locality ??
            placemark.subLocality ??
            placemark.administrativeArea
    }
}
