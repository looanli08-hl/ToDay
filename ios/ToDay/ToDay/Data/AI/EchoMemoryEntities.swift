import Foundation
import SwiftData

// MARK: - Layer 1: User Profile (Long-term Memory)

/// AI-generated user portrait — personality traits, habits, routines.
/// Updated weekly. Carried as context in every conversation.
@Model
final class UserProfileEntity {
    @Attribute(.unique) var id: UUID
    /// AI-generated user description (~200 chars)
    var profileText: String
    /// Last time the profile was updated
    var lastUpdatedAt: Date
    /// Number of times the profile has been regenerated
    var generationCount: Int
    /// Raw daily summary IDs used to generate this version
    var sourceSummaryIDs: [UUID]

    init(
        id: UUID = UUID(),
        profileText: String = "",
        lastUpdatedAt: Date = Date(),
        generationCount: Int = 0,
        sourceSummaryIDs: [UUID] = []
    ) {
        self.id = id
        self.profileText = profileText
        self.lastUpdatedAt = lastUpdatedAt
        self.generationCount = generationCount
        self.sourceSummaryIDs = sourceSummaryIDs
    }
}

// MARK: - Layer 2: Daily Summary (Short-term Memory)

/// One summary per day — generated at bedtime or on strong-emotion trigger.
/// Recent 7 days are included as context.
@Model
final class DailySummaryEntity {
    @Attribute(.unique) var id: UUID
    /// Date string formatted as "yyyy-MM-dd"
    var dateKey: String
    /// AI-generated summary of the day
    var summaryText: String
    /// Detected mood trend (e.g. "平静", "低落", "兴奋")
    var moodTrend: String?
    /// Key highlights extracted by AI
    var highlights: [String]
    /// When this summary was generated
    var createdAt: Date
    /// Whether this was triggered by strong emotion (vs. scheduled)
    var isEmotionTriggered: Bool

    init(
        id: UUID = UUID(),
        dateKey: String,
        summaryText: String,
        moodTrend: String? = nil,
        highlights: [String] = [],
        createdAt: Date = Date(),
        isEmotionTriggered: Bool = false
    ) {
        self.id = id
        self.dateKey = dateKey
        self.summaryText = summaryText
        self.moodTrend = moodTrend
        self.highlights = highlights
        self.createdAt = createdAt
        self.isEmotionTriggered = isEmotionTriggered
    }
}

// MARK: - Layer 4: Conversation Memory

/// Summarized history of Echo-user conversations.
/// Updated after each conversation session.
@Model
final class ConversationMemoryEntity {
    @Attribute(.unique) var id: UUID
    /// Compressed summary of conversation history (~200 chars)
    var memorySummary: String
    /// Number of conversation turns summarized
    var turnCount: Int
    /// Topics discussed (for quick lookup)
    var topics: [String]
    /// Last conversation date
    var lastConversationAt: Date
    /// When this memory was last updated
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        memorySummary: String = "",
        turnCount: Int = 0,
        topics: [String] = [],
        lastConversationAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.memorySummary = memorySummary
        self.turnCount = turnCount
        self.topics = topics
        self.lastConversationAt = lastConversationAt
        self.updatedAt = updatedAt
    }
}
