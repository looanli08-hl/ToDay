import Foundation

/// Manages auto-generation timing for Echo's background AI tasks.
///
/// Responsibilities:
/// - Daily summary: trigger when app enters background after configured hour
/// - Weekly profile: check on app launch if 7+ days since last update
/// - Smart echo: check if shutter records need AI-powered resurfacing (future)
///
/// Does NOT manage the existing `EchoEngine` notification-based echo system —
/// the two systems run in parallel.
final class EchoScheduler: @unchecked Sendable {

    private let dailySummaryGenerator: EchoDailySummaryGenerator
    private let weeklyProfileUpdater: EchoWeeklyProfileUpdater
    private let memoryManager: EchoMemoryManager
    private var messageManager: EchoMessageManager?

    /// UserDefaults key for last daily summary date (stored as "yyyy-MM-dd")
    private static let lastDailySummaryKey = "today.echo.lastDailySummaryDate"
    /// UserDefaults key for daily summary trigger hour
    private static let dailySummaryHourKey = "today.echo.dailySummaryHour"

    /// Hour after which daily summary can be triggered (0-23). Default = 20 (8 PM).
    var dailySummaryHour: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: Self.dailySummaryHourKey)
            if stored == 0 && UserDefaults.standard.object(forKey: Self.dailySummaryHourKey) == nil {
                return 20
            }
            return min(max(stored, 0), 23)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.dailySummaryHourKey)
        }
    }

    init(
        dailySummaryGenerator: EchoDailySummaryGenerator,
        weeklyProfileUpdater: EchoWeeklyProfileUpdater,
        memoryManager: EchoMemoryManager
    ) {
        self.dailySummaryGenerator = dailySummaryGenerator
        self.weeklyProfileUpdater = weeklyProfileUpdater
        self.memoryManager = memoryManager
    }

    /// Set the message manager. Called after AppContainer wires everything up
    /// (to break the circular dependency between scheduler and manager).
    func setMessageManager(_ manager: EchoMessageManager) {
        self.messageManager = manager
    }

    // MARK: - Daily Summary

    /// Check if daily summary should be generated.
    /// Returns true if: (1) not already generated today, AND (2) current hour >= configured hour.
    func shouldGenerateDailySummary() -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayKey = formatter.string(from: Date())

        let lastDate = UserDefaults.standard.string(forKey: Self.lastDailySummaryKey)
        if lastDate == todayKey {
            return false // Already generated today
        }

        return true
    }

    /// Check if current time is past the daily summary trigger hour.
    func isAfterDailySummaryHour() -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= dailySummaryHour
    }

    /// Called when app enters background. Triggers daily summary if conditions are met.
    ///
    /// - Parameters:
    ///   - todayDataSummary: Pre-formatted string of today's health/activity data
    ///   - shutterTexts: Text content from today's shutter records
    ///   - moodNotes: Formatted mood records
    func onAppBackground(
        todayDataSummary: String,
        shutterTexts: [String],
        moodNotes: [String]
    ) async {
        guard shouldGenerateDailySummary() && isAfterDailySummaryHour() else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayKey = formatter.string(from: Date())

        do {
            try await dailySummaryGenerator.generateDailySummary(
                dateKey: todayKey,
                todayDataSummary: todayDataSummary,
                shutterTexts: shutterTexts,
                moodNotes: moodNotes
            )

            // Mark as completed for today
            UserDefaults.standard.set(todayKey, forKey: Self.lastDailySummaryKey)

            // Create a dailyInsight message in the message center
            if let manager = messageManager {
                let summary = memoryManager.loadSummary(forDateKey: todayKey)
                let insightText = summary?.summaryText ?? "今天的数据已整理好"
                let preview = String(insightText.prefix(60))

                let sourceData = EchoSourceData(
                    type: .todayData,
                    sourceDescription: "今日数据"
                )

                await MainActor.run {
                    try? manager.generateMessage(
                        type: .dailyInsight,
                        title: "今日洞察",
                        preview: preview,
                        sourceDescription: "来自：今日数据",
                        sourceData: sourceData,
                        initialEchoMessage: insightText
                    )
                }
            }

            // Also prune old summaries (keep 30 days)
            try memoryManager.pruneOldSummaries(olderThanDays: 30)
        } catch {
            print("[EchoScheduler] Daily summary generation failed: \(error)")
        }
    }

    // MARK: - Weekly Profile

    /// Called on app launch. Triggers weekly profile update if 7+ days since last.
    func onAppLaunch() async {
        do {
            try await weeklyProfileUpdater.updateIfNeeded()

            // Check if profile was just updated (by looking at profile update timestamp)
            if let profile = memoryManager.loadUserProfile() {
                let calendar = Calendar.current
                if calendar.isDateInToday(profile.lastUpdatedAt),
                   let manager = messageManager {
                    let preview = String(profile.profileText.prefix(60))
                    let sourceData = EchoSourceData(
                        type: .userProfile,
                        sourceDescription: "你的生活画像"
                    )
                    await MainActor.run {
                        try? manager.generateMessage(
                            type: .mirrorUpdate,
                            title: "我对你有了新的了解",
                            preview: preview,
                            sourceDescription: "来自：你的生活画像",
                            sourceData: sourceData,
                            initialEchoMessage: profile.profileText
                        )
                    }
                }
            }
        } catch {
            print("[EchoScheduler] Weekly profile update failed: \(error)")
        }
    }

    // MARK: - Strong Emotion Trigger

    /// Called when a mood record with strong emotion is saved.
    /// Immediately generates a daily summary update.
    func onStrongEmotion(
        todayDataSummary: String,
        shutterTexts: [String],
        moodNotes: [String]
    ) async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayKey = formatter.string(from: Date())

        do {
            try await dailySummaryGenerator.generateDailySummary(
                dateKey: todayKey,
                todayDataSummary: todayDataSummary,
                shutterTexts: shutterTexts,
                moodNotes: moodNotes,
                isEmotionTriggered: true
            )

            // Create an emotion care message
            if let manager = messageManager {
                let summary = memoryManager.loadSummary(forDateKey: todayKey)
                let insightText = summary?.summaryText ?? "看起来你现在心情有些起伏"
                let preview = String(insightText.prefix(60))

                let sourceData = EchoSourceData(
                    type: .moodTrend,
                    sourceDescription: "近期心情趋势"
                )

                await MainActor.run {
                    try? manager.generateMessage(
                        type: .emotionCare,
                        title: "Echo 想跟你说",
                        preview: preview,
                        sourceDescription: "来自：近期心情趋势",
                        sourceData: sourceData,
                        initialEchoMessage: insightText
                    )
                }
            }
        } catch {
            print("[EchoScheduler] Emotion-triggered summary failed: \(error)")
        }
    }
}
