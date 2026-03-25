import Foundation

struct AppUsage: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let appName: String
    let category: String
    let duration: TimeInterval

    init(
        id: UUID = UUID(),
        appName: String,
        category: String,
        duration: TimeInterval
    ) {
        self.id = id
        self.appName = appName
        self.category = category
        self.duration = duration
    }

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

struct ScreenTimeRecord: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let dateKey: String
    let totalScreenTime: TimeInterval
    let appUsages: [AppUsage]
    let pickupCount: Int

    init(
        id: UUID = UUID(),
        dateKey: String,
        totalScreenTime: TimeInterval,
        appUsages: [AppUsage] = [],
        pickupCount: Int = 0
    ) {
        self.id = id
        self.dateKey = dateKey
        self.totalScreenTime = totalScreenTime
        self.appUsages = appUsages
        self.pickupCount = pickupCount
    }

    var formattedTotalTime: String {
        let hours = Int(totalScreenTime) / 3600
        let minutes = (Int(totalScreenTime) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    func toInferredEvent() -> InferredEvent {
        let displayName = "屏幕时间 \(formattedTotalTime)"
        let topApps = appUsages
            .sorted { $0.duration > $1.duration }
            .prefix(3)
            .map { "\($0.appName) \($0.formattedDuration)" }
        let subtitle: String? = topApps.isEmpty ? nil : topApps.joined(separator: "、")

        // Use noon of the day as start, span the total screen time as duration
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let baseDate = dateFormatter.date(from: dateKey) ?? Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: baseDate)
        let noon = calendar.date(byAdding: .hour, value: 12, to: startOfDay) ?? startOfDay

        return InferredEvent(
            id: id,
            kind: .screenTime,
            startDate: noon,
            endDate: noon,
            confidence: .medium,
            displayName: displayName,
            subtitle: subtitle
        )
    }
}
