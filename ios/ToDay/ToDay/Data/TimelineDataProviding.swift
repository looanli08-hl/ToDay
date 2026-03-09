import Foundation

protocol TimelineDataProviding {
    var source: TimelineSource { get }
    func loadTimeline(for date: Date) async throws -> DayTimeline
}

enum TimelineDataError: LocalizedError {
    case healthDataUnavailable
    case authorizationDenied
    case noDataForToday
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            return "Health data is not available on this device. Keep using mock mode until you can test on a real iPhone."
        case .authorizationDenied:
            return "Health data access was denied. You can still continue building with mock data."
        case .noDataForToday:
            return "No health samples were found for today yet."
        case let .queryFailed(message):
            return "HealthKit query failed: \(message)"
        }
    }
}
