import CoreLocation
import Foundation

struct KnownPlace: Codable, Identifiable {
    let id: UUID
    var name: String?
    var category: PlaceCategory
    var latitude: Double
    var longitude: Double
    var radius: Double
    var visitCount: Int
    var totalDuration: TimeInterval
    var lastVisitDate: Date
    var isConfirmedByUser: Bool

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

enum PlaceCategory: String, Codable, Sendable {
    case home, work, frequent, visited
}

final class PlaceManager {
    private let defaults: UserDefaults
    private static let storageKey = "today.places.known"
    private let matchRadius: Double = 100
    private let geocoder = CLGeocoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var allPlaces: [KnownPlace] {
        get {
            guard let data = defaults.data(forKey: Self.storageKey) else { return [] }
            return (try? JSONDecoder().decode([KnownPlace].self, from: data)) ?? []
        }
        set {
            defaults.set(try? JSONEncoder().encode(newValue), forKey: Self.storageKey)
        }
    }

    func recordVisit(latitude: Double, longitude: Double, duration: TimeInterval, date: Date) {
        var places = allPlaces
        if let index = findPlaceIndex(latitude: latitude, longitude: longitude, in: places) {
            places[index].visitCount += 1
            places[index].totalDuration += duration
            places[index].lastVisitDate = date
        } else {
            places.append(KnownPlace(
                id: UUID(), name: nil, category: .visited,
                latitude: latitude, longitude: longitude,
                radius: matchRadius, visitCount: 1,
                totalDuration: duration, lastVisitDate: date,
                isConfirmedByUser: false
            ))
        }
        allPlaces = places
    }

    func findPlace(latitude: Double, longitude: Double) -> KnownPlace? {
        let target = CLLocation(latitude: latitude, longitude: longitude)
        return allPlaces.first { place in
            let loc = CLLocation(latitude: place.latitude, longitude: place.longitude)
            return target.distance(from: loc) < place.radius
        }
    }

    func namePlace(id: UUID, name: String) {
        var places = allPlaces
        if let index = places.firstIndex(where: { $0.id == id }) {
            places[index].name = name
            places[index].isConfirmedByUser = true
        }
        allPlaces = places
    }

    func reclassifyPlaces() {
        var places = allPlaces
        let candidates = places.filter { !$0.isConfirmedByUser && $0.visitCount >= 3 }

        // Home: highest total duration with >= 3 visits
        if let homeCandidate = candidates.max(by: { $0.totalDuration < $1.totalDuration }),
           let homeIdx = places.firstIndex(where: { $0.id == homeCandidate.id }) {
            places[homeIdx].category = .home
        }

        // Work: second most visited (not home)
        let homeID = places.first(where: { $0.category == .home })?.id
        let nonHome = candidates.filter { $0.id != homeID }
        if let workCandidate = nonHome.max(by: { $0.visitCount < $1.visitCount }),
           let workIdx = places.firstIndex(where: { $0.id == workCandidate.id }) {
            places[workIdx].category = .work
        }

        // Frequent: visitCount >= 3, not home/work
        for i in places.indices where places[i].visitCount >= 3 &&
            places[i].category == .visited && !places[i].isConfirmedByUser {
            places[i].category = .frequent
        }

        allPlaces = places
    }

    /// Returns a human-readable label for a place: user name > geocoded name > category label.
    func displayName(for place: KnownPlace) -> String {
        if let name = place.name { return name }
        switch place.category {
        case .home: return "家"
        case .work: return "公司"
        case .frequent: return "常去的地方"
        case .visited: return "到访地点"
        }
    }

    /// Resolves display name for coordinates: finds matching place and returns its label.
    func displayName(latitude: Double, longitude: Double) -> String? {
        guard let place = findPlace(latitude: latitude, longitude: longitude) else { return nil }
        return displayName(for: place)
    }

    /// Reverse-geocodes all unnamed places via Apple CLGeocoder.
    /// Rate-limited: processes one place per call to respect Apple's throttling.
    func resolveUnnamedPlaces() async {
        var places = allPlaces
        guard let index = places.firstIndex(where: { $0.name == nil && !$0.isConfirmedByUser }) else {
            return
        }

        let place = places[index]
        let location = CLLocation(latitude: place.latitude, longitude: place.longitude)

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                let resolvedName = Self.bestName(from: placemark)
                places[index].name = resolvedName
                allPlaces = places
            }
        } catch {
            // Geocoding failed (rate limit, network, etc.) — skip silently, retry next cycle
        }
    }

    /// Picks the most useful name from a CLPlacemark.
    /// Priority: POI name > subLocality > thoroughfare > locality.
    private static func bestName(from placemark: CLPlacemark) -> String {
        // If there's a named place (Starbucks, 北大图书馆), prefer it
        if let name = placemark.name,
           name != placemark.thoroughfare,
           name != placemark.subLocality,
           name != placemark.locality {
            return name
        }
        // Street + number
        if let street = placemark.thoroughfare {
            if let number = placemark.subThoroughfare {
                return "\(street) \(number)"
            }
            return street
        }
        // Neighborhood / district
        if let sub = placemark.subLocality { return sub }
        // City
        if let city = placemark.locality { return city }
        return "未知地点"
    }

    private func findPlaceIndex(latitude: Double, longitude: Double, in places: [KnownPlace]) -> Int? {
        let target = CLLocation(latitude: latitude, longitude: longitude)
        return places.firstIndex { place in
            let loc = CLLocation(latitude: place.latitude, longitude: place.longitude)
            return target.distance(from: loc) < place.radius
        }
    }
}
