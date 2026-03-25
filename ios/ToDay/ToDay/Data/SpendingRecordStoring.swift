import Foundation
import SwiftData

protocol SpendingRecordStoring {
    func loadAll() -> [SpendingRecord]
    func loadForDate(_ date: Date) -> [SpendingRecord]
    func save(_ record: SpendingRecord) throws
    func delete(_ id: UUID) throws
}

struct SwiftDataSpendingRecordStore: SpendingRecordStoring {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func loadAll() -> [SpendingRecord] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<SpendingRecordEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.includePendingChanges = false

        guard let entities = try? context.fetch(descriptor) else {
            return []
        }
        return entities.map { $0.toSpendingRecord() }
    }

    func loadForDate(_ date: Date) -> [SpendingRecord] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let context = ModelContext(container)
        var descriptor = FetchDescriptor<SpendingRecordEntity>(
            predicate: #Predicate { $0.createdAt >= startOfDay && $0.createdAt < endOfDay },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.includePendingChanges = false

        guard let entities = try? context.fetch(descriptor) else {
            return []
        }
        return entities.map { $0.toSpendingRecord() }
    }

    func save(_ record: SpendingRecord) throws {
        let context = ModelContext(container)
        let id = record.id
        var descriptor = FetchDescriptor<SpendingRecordEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            existing.update(from: record)
        } else {
            context.insert(SpendingRecordEntity(record: record))
        }

        if context.hasChanges {
            try context.save()
        }
    }

    func delete(_ id: UUID) throws {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<SpendingRecordEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1

        if let entity = try context.fetch(descriptor).first {
            context.delete(entity)
            try context.save()
        }
    }
}
