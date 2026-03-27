import Foundation
import SwiftData

protocol ShutterRecordStoring {
    func loadAll() -> [ShutterRecord]
    func loadForDate(_ date: Date) -> [ShutterRecord]
    func save(_ record: ShutterRecord) throws
    func delete(_ id: UUID) throws
}

struct SwiftDataShutterRecordStore: ShutterRecordStoring {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func loadAll() -> [ShutterRecord] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<ShutterRecordEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.includePendingChanges = false

        guard let entities = try? context.fetch(descriptor) else {
            return []
        }
        return entities.map { $0.toShutterRecord() }
    }

    func loadForDate(_ date: Date) -> [ShutterRecord] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let context = ModelContext(container)
        var descriptor = FetchDescriptor<ShutterRecordEntity>(
            predicate: #Predicate { $0.createdAt >= startOfDay && $0.createdAt < endOfDay },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.includePendingChanges = false

        guard let entities = try? context.fetch(descriptor) else {
            return []
        }
        return entities.map { $0.toShutterRecord() }
    }

    func save(_ record: ShutterRecord) throws {
        let context = ModelContext(container)
        let id = record.id
        var descriptor = FetchDescriptor<ShutterRecordEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            existing.update(from: record)
        } else {
            context.insert(ShutterRecordEntity(record: record))
        }

        if context.hasChanges {
            try context.save()
        }
    }

    func delete(_ id: UUID) throws {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<ShutterRecordEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1

        if let entity = try context.fetch(descriptor).first {
            context.delete(entity)
            try context.save()
        }
    }
}
