import CoreLocation
import Foundation

final class DayDataAggregator {
    let healthProvider: HealthKitTimelineDataProvider
    let weatherService: WeatherService
    let locationService: LocationService
    let photoService: PhotoService

    init(
        healthProvider: HealthKitTimelineDataProvider,
        weatherService: WeatherService,
        locationService: LocationService,
        photoService: PhotoService
    ) {
        self.healthProvider = healthProvider
        self.weatherService = weatherService
        self.locationService = locationService
        self.photoService = photoService
    }

    func loadRawData(for date: Date) async -> DayRawData {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date

        async let healthData = healthProvider.loadRawData(for: date)
        async let locationVisits = locationService.fetchVisits(from: startOfDay, to: endOfDay)
        async let photos = photoService.fetchPhotos(for: date)

        let visits = await locationVisits
        let weatherLocation = await resolvedWeatherLocation(from: visits)
        async let weather = fetchWeather(for: date, location: weatherLocation)

        let baseRawData = await healthData

        return DayRawData(
            date: date,
            activitySummary: baseRawData.activitySummary,
            hourlyWeather: await weather,
            locationVisits: visits,
            photos: await photos,
            heartRateSamples: baseRawData.heartRateSamples,
            stepSamples: baseRawData.stepSamples,
            sleepSamples: baseRawData.sleepSamples,
            workouts: baseRawData.workouts,
            activeEnergySamples: baseRawData.activeEnergySamples,
            moodRecords: baseRawData.moodRecords
        )
    }

    private func resolvedWeatherLocation(from visits: [LocationVisit]) async -> CLLocation? {
        if let coordinate = visits.last?.coordinate {
            return CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }

        return await MainActor.run {
            locationService.currentLocation
        }
    }

    private func fetchWeather(for date: Date, location: CLLocation?) async -> [HourlyWeather] {
        guard let location else { return [] }
        return (try? await weatherService.fetchHourlyWeather(for: date, location: location)) ?? []
    }
}
