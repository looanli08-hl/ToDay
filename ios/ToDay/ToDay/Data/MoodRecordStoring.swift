import Foundation
import SwiftData

protocol MoodRecordStoring {
    func loadRecords() -> [MoodRecord]
    func saveRecords(_ records: [MoodRecord]) throws
}

struct UserDefaultsMoodRecordStore: MoodRecordStoring {
    private let defaults: UserDefaults
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard, key: String = "today.manualRecords") {
        self.defaults = defaults
        self.key = key
    }

    func loadRecords() -> [MoodRecord] {
        guard let data = defaults.data(forKey: key),
              let records = try? decoder.decode([MoodRecord].self, from: data) else {
            return []
        }

        return records.sorted { $0.createdAt > $1.createdAt }
    }

    func saveRecords(_ records: [MoodRecord]) throws {
        let data = try encoder.encode(records)
        defaults.set(data, forKey: key)
    }
}

struct SwiftDataMoodRecordStore: MoodRecordStoring {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func loadRecords() -> [MoodRecord] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<MoodRecordEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.includePendingChanges = false

        guard let entities = try? context.fetch(descriptor) else {
            return []
        }

        return entities.map { $0.toMoodRecord() }
    }

    func saveRecords(_ records: [MoodRecord]) throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<MoodRecordEntity>()
        let existingEntities = try context.fetch(descriptor)
        let existingByID = Dictionary(uniqueKeysWithValues: existingEntities.map { ($0.id, $0) })
        let incomingByID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })

        for entity in existingEntities where incomingByID[entity.id] == nil {
            context.delete(entity)
        }

        for record in records {
            if let entity = existingByID[record.id] {
                entity.update(from: record)
            } else {
                context.insert(MoodRecordEntity(record: record))
            }
        }

        if context.hasChanges {
            try context.save()
        }
    }
}
