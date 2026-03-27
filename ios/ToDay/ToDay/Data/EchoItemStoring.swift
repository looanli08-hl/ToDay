import Foundation
import SwiftData

protocol EchoItemStoring {
    func loadAll() -> [EchoItem]
    func loadPending(for date: Date) -> [EchoItem]
    func loadHistory(limit: Int) -> [EchoItem]
    func save(_ item: EchoItem) throws
    func delete(_ id: UUID) throws
    func deleteAll(forShutterRecordID shutterRecordID: UUID) throws
}

struct SwiftDataEchoItemStore: EchoItemStoring {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func loadAll() -> [EchoItem] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<EchoItemEntity>(
            sortBy: [SortDescriptor(\.scheduledDate, order: .reverse)]
        )
        descriptor.includePendingChanges = false

        guard let entities = try? context.fetch(descriptor) else {
            return []
        }
        return entities.map { $0.toEchoItem() }
    }

    func loadPending(for date: Date) -> [EchoItem] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let pendingRaw = EchoStatus.pending.rawValue

        let context = ModelContext(container)
        var descriptor = FetchDescriptor<EchoItemEntity>(
            predicate: #Predicate {
                $0.scheduledDate >= startOfDay
                && $0.scheduledDate < endOfDay
                && $0.statusRawValue == pendingRaw
            },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        descriptor.includePendingChanges = false

        guard let entities = try? context.fetch(descriptor) else {
            return []
        }
        return entities.map { $0.toEchoItem() }
    }

    func loadHistory(limit: Int) -> [EchoItem] {
        let viewedRaw = EchoStatus.viewed.rawValue
        let dismissedRaw = EchoStatus.dismissed.rawValue

        let context = ModelContext(container)
        var descriptor = FetchDescriptor<EchoItemEntity>(
            predicate: #Predicate {
                $0.statusRawValue == viewedRaw || $0.statusRawValue == dismissedRaw
            },
            sortBy: [SortDescriptor(\.scheduledDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        descriptor.includePendingChanges = false

        guard let entities = try? context.fetch(descriptor) else {
            return []
        }
        return entities.map { $0.toEchoItem() }
    }

    func save(_ item: EchoItem) throws {
        let context = ModelContext(container)
        let id = item.id
        var descriptor = FetchDescriptor<EchoItemEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            existing.update(from: item)
        } else {
            context.insert(EchoItemEntity(item: item))
        }

        if context.hasChanges {
            try context.save()
        }
    }

    func delete(_ id: UUID) throws {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<EchoItemEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1

        if let entity = try context.fetch(descriptor).first {
            context.delete(entity)
            try context.save()
        }
    }

    func deleteAll(forShutterRecordID shutterRecordID: UUID) throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<EchoItemEntity>(
            predicate: #Predicate { $0.shutterRecordID == shutterRecordID }
        )

        let entities = try context.fetch(descriptor)
        for entity in entities {
            context.delete(entity)
        }
        if context.hasChanges {
            try context.save()
        }
    }
}
