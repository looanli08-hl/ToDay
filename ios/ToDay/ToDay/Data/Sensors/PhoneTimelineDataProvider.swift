import Foundation

/// Collects fresh sensor readings, infers events, and assembles a `DayTimeline`
/// from on-device data (motion, location, pedometer, device-state, HealthKit).
final class PhoneTimelineDataProvider: TimelineDataProviding, @unchecked Sendable {

    // MARK: - Properties

    let source: TimelineSource = .phone

    private let collectors: [any SensorCollecting]
    private let store: SensorDataStore
    private let inferenceEngine: PhoneInferenceEngine
    private let placeManager: PlaceManager

    // MARK: - Init

    init(
        collectors: [any SensorCollecting],
        store: SensorDataStore,
        inferenceEngine: PhoneInferenceEngine,
        placeManager: PlaceManager
    ) {
        self.collectors = collectors
        self.store = store
        self.inferenceEngine = inferenceEngine
        self.placeManager = placeManager
    }

    // MARK: - TimelineDataProviding

    func loadTimeline(for date: Date) async throws -> DayTimeline {
        // 1. Collect fresh readings from all available collectors (skip individual failures)
        var collectedReadings: [SensorReading] = []
        for collector in collectors {
            guard collector.isAvailable else { continue }
            do {
                let readings = try await collector.collectData(for: date)
                collectedReadings.append(contentsOf: readings)
            } catch {
                // Individual collector failure is non-fatal — continue with others
                print("[PhoneTimelineDataProvider] Collector \(collector.sensorType) failed: \(error)")
            }
        }

        // 2. Save fresh readings to store on MainActor
        let freshReadings = collectedReadings
        if !freshReadings.isEmpty {
            try await MainActor.run {
                try store.save(freshReadings)
            }
        }

        // 3. Read all stored readings for the date from store
        var allReadings = try await MainActor.run {
            try store.readings(for: date)
        }

        // 3b. Retroactive fill: if stored motion data is sparse, query sensors directly
        // This ensures timelines are populated even if background tasks didn't run
        if allReadings.filter({ $0.sensorType == .motion }).isEmpty {
            let retroReadings = try await retroactiveCollect(for: date)
            if !retroReadings.isEmpty {
                try await MainActor.run { try store.save(retroReadings) }
                allReadings = try await MainActor.run { try store.readings(for: date) }
            }
        }

        // 4. Update PlaceManager with visit data extracted from location readings
        for reading in allReadings where reading.sensorType == .location {
            if case .visit(let lat, let lon, let arrival, let departure) = reading.payload {
                let duration = (departure ?? arrival).timeIntervalSince(arrival)
                placeManager.recordVisit(
                    latitude: lat,
                    longitude: lon,
                    duration: max(duration, 0),
                    date: arrival
                )
            }
        }

        // 4b. Reclassify places (home/work/frequent) and resolve unnamed ones via geocoding
        placeManager.reclassifyPlaces()
        await placeManager.resolveUnnamedPlaces()

        // 5. Infer events from all stored readings
        let knownPlaces = placeManager.allPlaces
        let events = inferenceEngine.inferEvents(
            from: allReadings,
            on: date,
            places: knownPlaces
        )

        // 6. Build stats and summary
        let stats = buildStats(from: allReadings, events: events)
        let summary = buildSummary(events: events, date: date)

        // 7. Return DayTimeline with source: .phone
        return DayTimeline(
            date: date,
            summary: summary,
            source: .phone,
            stats: stats,
            entries: events
        )
    }

    // MARK: - Retroactive Collection

    /// Retroactively queries CoreMotion and Pedometer for historical data.
    /// iOS stores ~7 days of motion/pedometer data natively.
    private func retroactiveCollect(for date: Date) async throws -> [SensorReading] {
        var readings: [SensorReading] = []
        for collector in collectors {
            guard collector.isAvailable else { continue }
            let type = collector.sensorType
            // Only motion, pedometer, and healthKit support retroactive queries
            // Location and DeviceState are real-time event-based
            guard type == .motion || type == .pedometer || type == .healthKit else { continue }
            do {
                let data = try await collector.collectData(for: date)
                readings.append(contentsOf: data)
            } catch {
                print("[PhoneTimelineDataProvider] Retroactive \(type) failed: \(error)")
            }
        }
        return readings
    }

    // MARK: - Helpers

    private func buildStats(from readings: [SensorReading], events: [InferredEvent]) -> [TimelineStat] {
        var stats: [TimelineStat] = []

        // Step count from pedometer readings
        let totalSteps = readings
            .compactMap { r -> Int? in
                guard case .pedometer(let steps, _, _) = r.payload else { return nil }
                return steps
            }
            .reduce(0, +)

        if totalSteps > 0 {
            stats.append(TimelineStat(id: "steps", title: "步数", value: "\(totalSteps)"))
        }

        // Distance from pedometer readings (meters → km)
        let totalDistance = readings
            .compactMap { r -> Double? in
                guard case .pedometer(_, let dist, _) = r.payload else { return nil }
                return dist
            }
            .reduce(0, +)

        if totalDistance > 0 {
            let km = totalDistance / 1000
            let formatted = String(format: km >= 10 ? "%.0f" : "%.1f", km)
            stats.append(TimelineStat(id: "distance", title: "距离", value: "\(formatted) km"))
        }

        // Event count
        let eventCount = events.count
        if eventCount > 0 {
            stats.append(TimelineStat(id: "events", title: "事件", value: "\(eventCount) 个"))
        }

        return stats
    }

    private func buildSummary(events: [InferredEvent], date: Date) -> String {
        if events.isEmpty {
            return "今天还没有记录到活动，带上手机出门后会自动感知你的一天。"
        }

        let kinds = Set(events.map(\.kind))
        var parts: [String] = []

        if kinds.contains(.sleep) { parts.append("睡眠") }
        if kinds.contains(.workout) || kinds.contains(.activeWalk) { parts.append("运动") }
        if kinds.contains(.commute) { parts.append("通勤") }
        if kinds.contains(.quietTime) { parts.append("安静时光") }

        if parts.isEmpty {
            return "今天共记录了 \(events.count) 个事件。"
        }

        return "今天记录了\(parts.joined(separator: "、"))等 \(events.count) 个事件。"
    }
}
