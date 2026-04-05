import Foundation
import SwiftData
import UserNotifications

/// Manages auto-generation timing for Echo's background AI tasks.
///
/// Responsibilities:
/// - Daily summary: trigger when app enters background after configured hour
/// - Weekly profile: check on app launch if 7+ days since last update
/// - Pattern check: detect behavioral patterns and generate proactive push insight
///
/// Does NOT manage the existing `EchoEngine` notification-based echo system —
/// the two systems run in parallel.
final class EchoScheduler: @unchecked Sendable {

    private let dailySummaryGenerator: EchoDailySummaryGenerator
    private let weeklyProfileUpdater: EchoWeeklyProfileUpdater
    private let memoryManager: EchoMemoryManager
    private let aiService: any EchoAIProviding
    private let promptBuilder: EchoPromptBuilder
    private let notificationScheduler: any EchoNotificationScheduling
    private var messageManager: EchoMessageManager?

    /// UserDefaults key for last daily summary date (stored as "yyyy-MM-dd")
    private static let lastDailySummaryKey = "today.echo.lastDailySummaryDate"
    /// UserDefaults key for daily summary trigger hour
    private static let dailySummaryHourKey = "today.echo.dailySummaryHour"
    /// UserDefaults key for last pattern insight date (idempotency guard)
    private static let lastPatternInsightKey = "today.echo.lastPatternInsightDate"

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
        memoryManager: EchoMemoryManager,
        aiService: any EchoAIProviding = EchoAIService(),
        promptBuilder: EchoPromptBuilder? = nil,
        notificationScheduler: any EchoNotificationScheduling = SystemNotificationScheduler()
    ) {
        self.dailySummaryGenerator = dailySummaryGenerator
        self.weeklyProfileUpdater = weeklyProfileUpdater
        self.memoryManager = memoryManager
        self.aiService = aiService
        self.promptBuilder = promptBuilder ?? EchoPromptBuilder(memoryManager: memoryManager)
        self.notificationScheduler = notificationScheduler
    }

    /// Set the message manager. Called after AppContainer wires everything up
    /// (to break the circular dependency between scheduler and manager).
    func setMessageManager(_ manager: EchoMessageManager) {
        self.messageManager = manager
    }

    // MARK: - Daily Summary

    /// Check if summary should be regenerated.
    /// Returns true if enough time has passed since last generation (throttle: 30 minutes).
    func shouldGenerateDailySummary() -> Bool {
        let lastTimestamp = UserDefaults.standard.double(forKey: Self.lastDailySummaryKey + ".timestamp")
        guard lastTimestamp > 0 else { return true } // Never generated

        let elapsed = Date().timeIntervalSince1970 - lastTimestamp
        return elapsed >= 1800 // 30 minutes throttle
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
        guard shouldGenerateDailySummary() else { return }

        // If no summary was passed, try to load from persisted timeline
        let effectiveSummary: String
        if todayDataSummary.isEmpty {
            effectiveSummary = loadTodayTimelineSummary()
        } else {
            effectiveSummary = todayDataSummary
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayKey = formatter.string(from: Date())

        do {
            try await dailySummaryGenerator.generateDailySummary(
                dateKey: todayKey,
                todayDataSummary: effectiveSummary,
                shutterTexts: shutterTexts,
                moodNotes: moodNotes
            )

            // Record generation timestamp (throttle: 30 min)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastDailySummaryKey + ".timestamp")
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

        await onPatternCheck()
    }

    // MARK: - Timeline Data Loading

    /// Load today's persisted timeline and format as text summary for Echo.
    private func loadTodayTimelineSummary() -> String {
        let context = ModelContext(AppContainer.modelContainer)
        let today = Calendar.current.startOfDay(for: Date())
        let key = DayTimelineEntity.dateKey(for: today)
        var descriptor = FetchDescriptor<DayTimelineEntity>(predicate: #Predicate { $0.dateKey == key })
        descriptor.fetchLimit = 1

        guard let entity = try? context.fetch(descriptor).first else { return "" }
        let timeline = entity.toDayTimeline()

        return timeline.entries
            .filter { $0.kind != .mood }
            .map { event in
                var line = "\(event.kindBadgeTitle): \(event.resolvedName) (\(event.scrollDurationText))"
                if let subtitle = event.subtitle {
                    line += " - \(subtitle)"
                }
                return line
            }
            .joined(separator: "\n")
    }

    // MARK: - Pattern Recognition

    /// Detect a behavioral pattern and generate a proactive push insight.
    ///
    /// This method is idempotent: it runs at most once per calendar day, controlled
    /// by the `lastPatternInsightKey` UserDefaults value. It also skips silently when:
    /// - Less than 21 days of DailySummaryEntity data exist
    /// - No detectable pattern is found (streak < 3 days)
    /// - The AI response contains prescriptive language (tone guard)
    /// - Notification permission is denied (Echo inbox message is still created)
    func onPatternCheck() async {
        let context = ModelContext(AppContainer.modelContainer)
        let engine = PatternDetectionEngine()

        guard engine.hasSufficientData(context: context) else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let todayKey = formatter.string(from: Date())

        let lastKey = UserDefaults.standard.string(forKey: Self.lastPatternInsightKey)
        guard lastKey != todayKey else { return }

        guard let pattern = engine.detectBestPattern(context: context) else { return }

        let prompt = promptBuilder.buildPatternInsightPrompt(pattern)
        let insightText: String
        do {
            insightText = try await aiService.summarize(prompt: prompt)
        } catch {
            return
        }

        // Tone guard — reject prescriptive AI output
        let prescriptiveKeywords = ["建议", "应该", "需要", "可以考虑", "尝试"]
        guard !prescriptiveKeywords.contains(where: { insightText.contains($0) }) else { return }

        // Persist as Echo inbox message
        if let manager = messageManager {
            let preview = String(insightText.prefix(60))
            let sourceData = EchoSourceData(
                type: .dateRange,
                sourceDescription: "近期\(pattern.streakLength)天行为规律"
            )
            await MainActor.run {
                try? manager.generateMessage(
                    type: .dailyInsight,
                    title: "Echo 发现了一个规律",
                    preview: preview,
                    sourceDescription: "来自：行为规律分析",
                    sourceData: sourceData,
                    initialEchoMessage: insightText
                )
            }
        }

        // Schedule push notification (permission-gated)
        let notificationID = "echo.pattern.\(todayKey)"
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
            notificationScheduler.removeNotifications(identifiers: [notificationID])
            if let triggerDate = Calendar.current.date(
                bySettingHour: dailySummaryHour, minute: 5, second: 0, of: Date()
            ) {
                notificationScheduler.scheduleEchoNotification(
                    identifier: notificationID,
                    title: "Echo",
                    body: insightText,
                    triggerDate: triggerDate
                )
            }
        }

        UserDefaults.standard.set(todayKey, forKey: Self.lastPatternInsightKey)
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
