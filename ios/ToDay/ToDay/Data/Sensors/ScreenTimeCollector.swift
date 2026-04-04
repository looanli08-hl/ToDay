import Foundation

/// Reads screen time summary data written by the ToDayScreenTimeReport extension
/// via shared App Group UserDefaults.
final class ScreenTimeCollector: SensorCollecting, @unchecked Sendable {
    let sensorType: SensorType = .deviceState  // Reuse deviceState type for screen time

    private let sharedDefaults = UserDefaults(suiteName: SharedAppGroup.identifier)

    var isAvailable: Bool {
        // Available if we have shared summary data
        sharedDefaults?.data(forKey: "today.screenTime.summary") != nil
    }

    func requestAuthorizationIfNeeded() async throws {
        // Authorization handled by FamilyControls in settings
    }

    func collectData(for date: Date) async throws -> [SensorReading] {
        guard let data = sharedDefaults?.data(forKey: "today.screenTime.summary"),
              let summary = try? JSONDecoder().decode(ScreenTimeSummary.self, from: data) else {
            return []
        }

        // Only use data from the requested date
        let calendar = Calendar.current
        guard calendar.isDate(summary.date, inSameDayAs: date) else {
            return []
        }

        // Create one reading per category
        var readings: [SensorReading] = []
        let startOfDay = calendar.startOfDay(for: date)

        for (index, category) in summary.categories.enumerated() {
            guard category.duration > 60 else { continue } // Skip < 1 min
            // Spread categories across the day for timeline display
            let startTime = startOfDay.addingTimeInterval(Double(index) * 3600 + 8 * 3600) // Start from 8 AM
            let endTime = startTime.addingTimeInterval(category.duration)

            readings.append(SensorReading(
                sensorType: .deviceState,
                timestamp: startTime,
                endTimestamp: endTime,
                payload: .healthKit(metric: "screenTime.\(category.name)", value: category.duration)
            ))
        }

        return readings
    }
}

// MARK: - Shared Data Models
// Duplicated from the ToDayScreenTimeReport extension since extension code
// is not accessible from the main app target. These must stay in sync with
// the definitions in TotalActivityReport.swift.

struct ScreenTimeSummary: Codable {
    let date: Date
    let totalDuration: TimeInterval
    let categories: [ScreenTimeCategoryUsage]
}

struct ScreenTimeCategoryUsage: Codable, Identifiable {
    var id: String { name }
    let name: String
    let duration: TimeInterval

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
