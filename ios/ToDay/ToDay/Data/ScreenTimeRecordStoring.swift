import Foundation
import SwiftData

protocol ScreenTimeRecordStoring {
    func loadAll() -> [ScreenTimeRecord]
    func loadForDateKey(_ dateKey: String) -> ScreenTimeRecord?
    func save(_ record: ScreenTimeRecord) throws
    func delete(_ id: UUID) throws
}

struct SwiftDataScreenTimeRecordStore: ScreenTimeRecordStoring {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func loadAll() -> [ScreenTimeRecord] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<ScreenTimeRecordEntity>(
            sortBy: [SortDescriptor(\.dateKey, order: .reverse)]
        )
        descriptor.includePendingChanges = false

        guard let entities = try? context.fetch(descriptor) else {
            return []
        }
        return entities.map { $0.toScreenTimeRecord() }
    }

    func loadForDateKey(_ dateKey: String) -> ScreenTimeRecord? {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<ScreenTimeRecordEntity>(
            predicate: #Predicate { $0.dateKey == dateKey }
        )
        descriptor.fetchLimit = 1
        descriptor.includePendingChanges = false

        return try? context.fetch(descriptor).first?.toScreenTimeRecord()
    }

    func save(_ record: ScreenTimeRecord) throws {
        let context = ModelContext(container)
        let id = record.id
        var descriptor = FetchDescriptor<ScreenTimeRecordEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            existing.update(from: record)
        } else {
            // Also check by dateKey to avoid duplicates for the same day
            let dateKey = record.dateKey
            var dateDescriptor = FetchDescriptor<ScreenTimeRecordEntity>(
                predicate: #Predicate { $0.dateKey == dateKey }
            )
            dateDescriptor.fetchLimit = 1

            if let existingDay = try context.fetch(dateDescriptor).first {
                existingDay.update(from: record)
            } else {
                context.insert(ScreenTimeRecordEntity(record: record))
            }
        }

        if context.hasChanges {
            try context.save()
        }
    }

    func delete(_ id: UUID) throws {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<ScreenTimeRecordEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1

        if let entity = try context.fetch(descriptor).first {
            context.delete(entity)
            try context.save()
        }
    }
}
