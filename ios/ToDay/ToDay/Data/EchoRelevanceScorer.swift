import CoreLocation
import Foundation

/// Scores historical shutter records for echo relevance based on context.
struct EchoRelevanceScorer {

    struct ScoredRecord {
        let recordId: UUID
        let title: String
        let score: Double
    }

    /// Threshold values per frequency setting.
    static func threshold(for frequency: EchoFrequency) -> Double {
        switch frequency {
        case .high:   return 0.3
        case .medium: return 0.5
        case .low:    return 0.7
        case .off:    return Double.infinity
        }
    }

    /// Minimum interval between pushes per frequency setting.
    static func minInterval(for frequency: EchoFrequency) -> TimeInterval {
        switch frequency {
        case .high:   return 15 * 60      // 15 min
        case .medium: return 60 * 60      // 1 hour
        case .low:    return 4 * 3600     // 4 hours
        case .off:    return .infinity
        }
    }

    /// Score a shutter record against the current context.
    func score(
        recordDate: Date,
        recordNote: String,
        now: Date,
        currentLocation: CLLocation?,
        recordLocation: CLLocation?
    ) -> Double {
        var total: Double = 0

        // 1. Time decay with nostalgia boost
        let daysSince = now.timeIntervalSince(recordDate) / 86400
        if daysSince < 1 {
            total += 0.1
        } else if daysSince < 7 {
            total += 0.4
        } else if daysSince < 30 {
            total += 0.3
        } else if daysSince > 180 {
            total += 0.5
        } else {
            total += 0.2
        }

        // 2. Time-of-day resonance (same hour +/-1)
        let recordHour = Calendar.current.component(.hour, from: recordDate)
        let currentHour = Calendar.current.component(.hour, from: now)
        if abs(recordHour - currentHour) <= 1 {
            total += 0.3
        }

        // 3. Location proximity
        if let current = currentLocation, let record = recordLocation {
            let distance = current.distance(from: record)
            if distance < 200 {
                total += 0.5
            } else if distance < 1000 {
                total += 0.3
            } else if distance < 5000 {
                total += 0.1
            }
        }

        // 4. Day-of-week match
        let recordWeekday = Calendar.current.component(.weekday, from: recordDate)
        let currentWeekday = Calendar.current.component(.weekday, from: now)
        if recordWeekday == currentWeekday {
            total += 0.1
        }

        return min(total, 1.0)
    }
}
