import CoreLocation
import Foundation
import WeatherKit

struct HourlyWeather: Sendable, Codable, Hashable {
    let date: Date
    let temperature: Double
    let condition: WeatherCondition
    let symbolName: String
}

enum WeatherCondition: String, Codable, Sendable {
    case clear
    case cloudy
    case rain
    case snow
    case fog
    case wind
    case thunderstorm
    case unknown
}

final class WeatherService {
    func fetchHourlyWeather(for date: Date, location: CLLocation) async throws -> [HourlyWeather] {
        let service = WeatherKit.WeatherService.shared
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

        do {
            let weather = try await service.weather(for: location)
            return weather.hourlyForecast
                .forecast
                .filter { $0.date >= dayStart && $0.date < dayEnd }
                .map { hour in
                    HourlyWeather(
                        date: hour.date,
                        temperature: hour.temperature.converted(to: .celsius).value,
                        condition: WeatherCondition(weatherKitCondition: hour.condition),
                        symbolName: hour.symbolName
                    )
                }
        } catch {
            return []
        }
    }
}

private extension WeatherCondition {
    init(weatherKitCondition: WeatherKit.WeatherCondition) {
        switch weatherKitCondition {
        case .clear, .mostlyClear, .hot:
            self = .clear
        case .cloudy, .mostlyCloudy, .partlyCloudy:
            self = .cloudy
        case .drizzle, .rain, .heavyRain, .sunShowers, .freezingDrizzle, .freezingRain:
            self = .rain
        case .snow, .blizzard, .blowingSnow, .flurries, .frigid, .hail, .heavySnow, .sleet, .sunFlurries, .wintryMix:
            self = .snow
        case .blowingDust, .foggy, .haze, .smoky:
            self = .fog
        case .breezy, .windy:
            self = .wind
        case .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms, .thunderstorms, .tropicalStorm, .hurricane:
            self = .thunderstorm
        default:
            self = .unknown
        }
    }
}
