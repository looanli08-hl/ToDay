import Foundation
import SwiftData

// MARK: - Error

enum SensorDataStoreError: Error {
    case invalidSensorType(String)
}

// MARK: - Entity

@Model
final class SensorReadingEntity {
    @Attribute(.unique) var readingID: UUID
    var sensorType: String
    var timestamp: Date
    var endTimestamp: Date?
    var dateKey: String
    var payloadData: Data

    init(from reading: SensorReading) {
        readingID = reading.id
        sensorType = reading.sensorType.rawValue
        timestamp = reading.timestamp
        endTimestamp = reading.endTimestamp
        dateKey = Self.makeDateKey(from: reading.timestamp)
        payloadData = (try? JSONEncoder().encode(reading.payload)) ?? Data()
    }

    func toReading() throws -> SensorReading {
        guard let type = SensorType(rawValue: sensorType) else {
            throw SensorDataStoreError.invalidSensorType(sensorType)
        }
        let payload = try JSONDecoder().decode(SensorPayload.self, from: payloadData)
        return SensorReading(
            id: readingID,
            sensorType: type,
            timestamp: timestamp,
            endTimestamp: endTimestamp,
            payload: payload
        )
    }

    private static func makeDateKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}

// MARK: - Store

final class SensorDataStore: Sendable {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    @MainActor
    func save(_ readings: [SensorReading]) throws {
        let context = container.mainContext
        for reading in readings {
            let id = reading.id
            let descriptor = FetchDescriptor<SensorReadingEntity>(
                predicate: #Predicate { $0.readingID == id }
            )
            let existing = try context.fetch(descriptor)
            if existing.isEmpty {
                let entity = SensorReadingEntity(from: reading)
                context.insert(entity)
            }
            // Already exists — skip (deduplication)
        }
        try context.save()
    }

    @MainActor
    func readings(for date: Date, type: SensorType? = nil) throws -> [SensorReading] {
        let key = dateKey(from: date)
        let descriptor: FetchDescriptor<SensorReadingEntity>
        if let type {
            let rawType = type.rawValue
            descriptor = FetchDescriptor<SensorReadingEntity>(
                predicate: #Predicate { $0.dateKey == key && $0.sensorType == rawType },
                sortBy: [SortDescriptor(\.timestamp)]
            )
        } else {
            descriptor = FetchDescriptor<SensorReadingEntity>(
                predicate: #Predicate { $0.dateKey == key },
                sortBy: [SortDescriptor(\.timestamp)]
            )
        }
        let entities = try container.mainContext.fetch(descriptor)
        return try entities.map { try $0.toReading() }
    }

    @MainActor
    func purge(olderThan days: Int) throws {
        let context = container.mainContext
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<SensorReadingEntity>(
            predicate: #Predicate { $0.timestamp < cutoff }
        )
        let entities = try context.fetch(descriptor)
        for entity in entities {
            context.delete(entity)
        }
        try context.save()
    }

    private func dateKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Calendar.current.startOfDay(for: date))
    }
}
