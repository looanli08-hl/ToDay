import Foundation
import SwiftData

/// Manages CRUD operations for Echo's four-layer memory system.
///
/// - Layer 1: User Profile (long-term, updated weekly)
/// - Layer 2: Daily Summary (short-term, updated daily)
/// - Layer 3: Today Data (real-time, sourced from existing data stores — not persisted here)
/// - Layer 4: Conversation Memory (updated after each conversation)
final class EchoMemoryManager: @unchecked Sendable {

    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    // MARK: - Layer 1: User Profile

    func loadUserProfile() -> UserProfileEntity? {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<UserProfileEntity>(
            sortBy: [SortDescriptor(\.lastUpdatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        descriptor.includePendingChanges = false
        return try? context.fetch(descriptor).first
    }

    /// Save or update the user profile. Increments generation count on update.
    func saveUserProfile(text: String, sourceSummaryIDs: [UUID]) throws {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<UserProfileEntity>(
            sortBy: [SortDescriptor(\.lastUpdatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            existing.profileText = text
            existing.lastUpdatedAt = Date()
            existing.generationCount += 1
            existing.sourceSummaryIDs = sourceSummaryIDs
        } else {
            let entity = UserProfileEntity(
                profileText: text,
                lastUpdatedAt: Date(),
                generationCount: 1,
                sourceSummaryIDs: sourceSummaryIDs
            )
            context.insert(entity)
        }

        if context.hasChanges {
            try context.save()
        }
    }

    // MARK: - Layer 2: Daily Summary

    func loadRecentSummaries(days: Int) -> [DailySummaryEntity] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<DailySummaryEntity>(
            sortBy: [SortDescriptor(\.dateKey, order: .reverse)]
        )
        descriptor.fetchLimit = days
        descriptor.includePendingChanges = false
        return (try? context.fetch(descriptor)) ?? []
    }

    func loadSummary(forDateKey dateKey: String) -> DailySummaryEntity? {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<DailySummaryEntity>(
            predicate: #Predicate { $0.dateKey == dateKey }
        )
        descriptor.fetchLimit = 1
        descriptor.includePendingChanges = false
        return try? context.fetch(descriptor).first
    }

    /// Save or upsert a daily summary. If one already exists for the dateKey, it is updated.
    func saveDailySummary(
        dateKey: String,
        summaryText: String,
        moodTrend: String? = nil,
        highlights: [String] = [],
        isEmotionTriggered: Bool = false
    ) throws {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<DailySummaryEntity>(
            predicate: #Predicate { $0.dateKey == dateKey }
        )
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            existing.summaryText = summaryText
            existing.moodTrend = moodTrend
            existing.highlights = highlights
            existing.createdAt = Date()
            existing.isEmotionTriggered = isEmotionTriggered
        } else {
            let entity = DailySummaryEntity(
                dateKey: dateKey,
                summaryText: summaryText,
                moodTrend: moodTrend,
                highlights: highlights,
                isEmotionTriggered: isEmotionTriggered
            )
            context.insert(entity)
        }

        if context.hasChanges {
            try context.save()
        }
    }

    // MARK: - Layer 4: Conversation Memory

    func loadConversationMemory() -> ConversationMemoryEntity? {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<ConversationMemoryEntity>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        descriptor.includePendingChanges = false
        return try? context.fetch(descriptor).first
    }

    /// Save or replace the conversation memory. Only one instance is kept.
    func saveConversationMemory(
        summary: String,
        turnCount: Int,
        topics: [String]
    ) throws {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<ConversationMemoryEntity>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            existing.memorySummary = summary
            existing.turnCount = turnCount
            existing.topics = topics
            existing.lastConversationAt = Date()
            existing.updatedAt = Date()
        } else {
            let entity = ConversationMemoryEntity(
                memorySummary: summary,
                turnCount: turnCount,
                topics: topics
            )
            context.insert(entity)
        }

        if context.hasChanges {
            try context.save()
        }
    }

    // MARK: - Cleanup

    /// Delete all Echo memory data (used for "reset Echo" in settings).
    func deleteAllMemory() throws {
        let context = ModelContext(container)

        let profiles = try context.fetch(FetchDescriptor<UserProfileEntity>())
        for p in profiles { context.delete(p) }

        let summaries = try context.fetch(FetchDescriptor<DailySummaryEntity>())
        for s in summaries { context.delete(s) }

        let memories = try context.fetch(FetchDescriptor<ConversationMemoryEntity>())
        for m in memories { context.delete(m) }

        if context.hasChanges {
            try context.save()
        }
    }

    /// Delete daily summaries older than a given number of days.
    func pruneOldSummaries(olderThanDays days: Int) throws {
        let calendar = Calendar.current
        guard let cutoffDate = calendar.date(byAdding: .day, value: -days, to: Date()) else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let cutoffKey = formatter.string(from: cutoffDate)

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<DailySummaryEntity>(
            predicate: #Predicate { $0.dateKey < cutoffKey }
        )
        let old = try context.fetch(descriptor)
        for entity in old {
            context.delete(entity)
        }
        if context.hasChanges {
            try context.save()
        }
    }
}
