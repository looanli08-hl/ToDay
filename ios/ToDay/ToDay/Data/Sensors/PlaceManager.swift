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

    private func findPlaceIndex(latitude: Double, longitude: Double, in places: [KnownPlace]) -> Int? {
        let target = CLLocation(latitude: latitude, longitude: longitude)
        return places.firstIndex { place in
            let loc = CLLocation(latitude: place.latitude, longitude: place.longitude)
            return target.distance(from: loc) < place.radius
        }
    }
}
