import Foundation
import SwiftData

protocol EchoMessageStoring {
    func loadAll() -> [EchoMessageEntity]
    func unreadCount() -> Int
    func markAsRead(id: UUID) throws
    func save(_ entity: EchoMessageEntity) throws
    func delete(id: UUID) throws
}

struct SwiftDataEchoMessageStore: EchoMessageStoring {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func loadAll() -> [EchoMessageEntity] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<EchoMessageEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.includePendingChanges = false

        guard let entities = try? context.fetch(descriptor) else {
            return []
        }
        return entities
    }

    func unreadCount() -> Int {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<EchoMessageEntity>(
            predicate: #Predicate { $0.isRead == false }
        )
        descriptor.includePendingChanges = false

        guard let entities = try? context.fetch(descriptor) else {
            return 0
        }
        return entities.count
    }

    func markAsRead(id: UUID) throws {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<EchoMessageEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1

        guard let entity = try context.fetch(descriptor).first else { return }
        entity.isRead = true
        if context.hasChanges {
            try context.save()
        }
    }

    func save(_ entity: EchoMessageEntity) throws {
        let context = ModelContext(container)
        let entityId = entity.id
        var descriptor = FetchDescriptor<EchoMessageEntity>(
            predicate: #Predicate { $0.id == entityId }
        )
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            existing.type = entity.type
            existing.title = entity.title
            existing.preview = entity.preview
            existing.sourceDescription = entity.sourceDescription
            existing.sourceDataJSON = entity.sourceDataJSON
            existing.isRead = entity.isRead
            existing.threadId = entity.threadId
        } else {
            context.insert(entity)
        }

        if context.hasChanges {
            try context.save()
        }
    }

    func delete(id: UUID) throws {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<EchoMessageEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1

        if let entity = try context.fetch(descriptor).first {
            context.delete(entity)
            try context.save()
        }
    }
}
