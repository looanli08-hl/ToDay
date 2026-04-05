import Foundation
import SwiftData

/// Assembles the full prompt sent to an AI provider by combining:
/// - Personality template (system prompt prefix)
/// - User profile (Layer 1)
/// - Recent daily summaries (Layer 2)
/// - Today's data (Layer 3)
/// - Conversation memory (Layer 4)
/// - User's current input
final class EchoPromptBuilder: @unchecked Sendable {

    private let memoryManager: EchoMemoryManager
    /// Override container for timeline queries. Nil means use AppContainer.modelContainer.
    /// Inject a test container in unit tests to avoid the singleton.
    private let timelineContainer: ModelContainer?

    init(memoryManager: EchoMemoryManager, timelineContainer: ModelContainer? = nil) {
        self.memoryManager = memoryManager
        self.timelineContainer = timelineContainer
    }

    // MARK: - Chat Message Assembly

    /// Build the full message array for a chat-style AI call.
    func buildMessages(
        userInput: String,
        personality: EchoPersonality,
        todayDataSummary: String?,
        conversationHistory: [EchoChatMessage] = []
    ) -> [EchoChatMessage] {
        var messages: [EchoChatMessage] = []

        // System message with full context
        let systemContent = buildSystemPrompt(
            personality: personality,
            todayDataSummary: todayDataSummary
        )
        messages.append(EchoChatMessage(role: .system, content: systemContent))

        // Append conversation history (prior turns)
        messages.append(contentsOf: conversationHistory)

        // Current user input
        messages.append(EchoChatMessage(role: .user, content: userInput))

        return messages
    }

    // MARK: - Thread Message Assembly

    /// Build the full message array for a thread-specific chat.
    /// Includes source data context so Echo knows what triggered this conversation.
    func buildThreadMessages(
        userInput: String,
        personality: EchoPersonality,
        sourceData: EchoSourceData?,
        sourceDescription: String,
        messageType: EchoMessageType,
        todayDataSummary: String? = nil,
        conversationHistory: [EchoChatMessage] = []
    ) -> [EchoChatMessage] {
        var messages: [EchoChatMessage] = []

        // System message with full context + source-specific context
        let systemContent = buildThreadSystemPrompt(
            personality: personality,
            sourceData: sourceData,
            sourceDescription: sourceDescription,
            messageType: messageType,
            todayDataSummary: todayDataSummary
        )
        messages.append(EchoChatMessage(role: .system, content: systemContent))

        // Append conversation history (prior turns)
        messages.append(contentsOf: conversationHistory)

        // Current user input
        messages.append(EchoChatMessage(role: .user, content: userInput))

        return messages
    }

    /// Build system prompt for a thread, including source-specific context.
    private func buildThreadSystemPrompt(
        personality: EchoPersonality,
        sourceData: EchoSourceData?,
        sourceDescription: String,
        messageType: EchoMessageType,
        todayDataSummary: String? = nil
    ) -> String {
        var parts: [String] = []

        // 1. Personality
        parts.append(personality.systemPromptPrefix)

        // 2. Thread context instruction
        let typeLabel: String
        switch messageType {
        case .dailyInsight:  typeLabel = "今日洞察"
        case .shutterEcho:   typeLabel = "快门回响"
        case .thoughtOrg:    typeLabel = "想法整理"
        case .emotionCare:   typeLabel = "情绪关怀"
        case .todoReminder:  typeLabel = "待办提醒"
        case .mirrorUpdate:  typeLabel = "画像更新"
        case .freeChat:      typeLabel = "自由对话"
        }
        parts.append("【当前对话主题】\n这是一个「\(typeLabel)」类型的对话。\(sourceDescription)")

        // 3. Source-specific data
        if let source = sourceData {
            var sourceContext = "【来源数据】\n类型：\(source.type.rawValue)\n描述：\(source.sourceDescription)"
            if let ids = source.shutterRecordIDs, !ids.isEmpty {
                sourceContext += "\n关联快门记录数量：\(ids.count)"
            }
            if let start = source.dateRangeStart, let end = source.dateRangeEnd {
                let formatter = DateFormatter()
                formatter.dateFormat = "M月d日"
                sourceContext += "\n时间范围：\(formatter.string(from: start)) - \(formatter.string(from: end))"
            }
            parts.append(sourceContext)
        }

        // 4. User Profile (Layer 1)
        if let profile = memoryManager.loadUserProfile(),
           !profile.profileText.isEmpty {
            parts.append("【用户画像】\n\(profile.profileText)")
        }

        // 5. Recent Summaries (Layer 2)
        let summaries = memoryManager.loadRecentSummaries(days: 7)
        if !summaries.isEmpty {
            let summaryTexts = summaries.map { "\($0.dateKey): \($0.summaryText)" }
            parts.append("【近期动态】\n\(summaryTexts.joined(separator: "\n"))")
        }

        // 5.5. Historical timeline context — injected for freeChat threads (per AIC-02)
        if messageType == .freeChat {
            let timelineHistory = loadRecentTimelineSummaries(days: 7)
            if !timelineHistory.isEmpty {
                parts.append("【近期生活时间线】\n\(timelineHistory)")
            }
        }

        // 6. Conversation Memory (Layer 4)
        if let memory = memoryManager.loadConversationMemory(),
           !memory.memorySummary.isEmpty {
            parts.append("【对话记忆】\n\(memory.memorySummary)")
        }

        // Today's live data (if provided by caller)
        if let todayData = todayDataSummary, !todayData.isEmpty {
            parts.append("【今日数据】\n\(todayData)")
        }

        return parts.joined(separator: "\n\n")
    }

    // MARK: - System Prompt

    func buildSystemPrompt(
        personality: EchoPersonality,
        todayDataSummary: String?
    ) -> String {
        var parts: [String] = []

        // 1. Personality
        parts.append(personality.systemPromptPrefix)

        // 2. User Profile (Layer 1)
        if let profile = memoryManager.loadUserProfile(),
           !profile.profileText.isEmpty {
            parts.append("【用户画像】\n\(profile.profileText)")
        }

        // 3. Recent Summaries (Layer 2)
        let summaries = memoryManager.loadRecentSummaries(days: 7)
        if !summaries.isEmpty {
            let summaryTexts = summaries.map { "\($0.dateKey): \($0.summaryText)" }
            parts.append("【近期动态】\n\(summaryTexts.joined(separator: "\n"))")
        }

        // 3.5. Historical timeline data from persistence
        let timelineHistory = loadRecentTimelineSummaries(days: 7)
        if !timelineHistory.isEmpty {
            parts.append("【近期生活时间线】\n\(timelineHistory)")
        }

        // 4. Conversation Memory (Layer 4)
        if let memory = memoryManager.loadConversationMemory(),
           !memory.memorySummary.isEmpty {
            parts.append("【对话记忆】\n\(memory.memorySummary)")
        }

        // 5. Today Data (Layer 3)
        if let todayData = todayDataSummary, !todayData.isEmpty {
            parts.append("【今日数据】\n\(todayData)")
        }

        return parts.joined(separator: "\n\n")
    }

    // MARK: - Historical Timeline Loading

    /// Load recent days' timeline summaries from SwiftData persistence.
    /// Uses timelineContainer if set (for unit tests), otherwise falls back to AppContainer.modelContainer.
    private func loadRecentTimelineSummaries(days: Int) -> String {
        let context = ModelContext(timelineContainer ?? AppContainer.modelContainer)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var summaries: [String] = []

        for offset in 1...days {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let key = DayTimelineEntity.dateKey(for: date)
            var descriptor = FetchDescriptor<DayTimelineEntity>(predicate: #Predicate { $0.dateKey == key })
            descriptor.fetchLimit = 1

            guard let entity = try? context.fetch(descriptor).first else { continue }
            let timeline = entity.toDayTimeline()
            let eventSummary = timeline.entries
                .filter { $0.kind != .mood }
                .map { "\($0.kindBadgeTitle) \($0.resolvedName) (\($0.scrollDurationText))" }
                .joined(separator: ", ")

            if !eventSummary.isEmpty {
                let formatter = DateFormatter()
                formatter.dateFormat = "M月d日"
                summaries.append("\(formatter.string(from: date)): \(eventSummary)")
            }
        }

        return summaries.joined(separator: "\n")
    }

    // MARK: - Daily Summary Prompt

    /// Build a prompt for the daily summary generator.
    func buildDailySummaryPrompt(
        todayDataSummary: String,
        shutterTexts: [String],
        moodNotes: [String]
    ) -> String {
        var parts: [String] = []

        parts.append("""
        你是用户最亲近的朋友。根据以下数据，用2-3句话描述他到目前为止的这一天。

        要求：
        - 像老朋友随口说的，不像AI生成的报告
        - 不要罗列数据（不说"你步行了30分钟"），而是描述感受和节奏（"下午换了个地方待着，从图书馆转到了咖啡厅"）
        - 如果数据还很少（比如刚起床），就说短一点，别硬凑
        - 不评判，不建议，不用"你应该""建议""加油"
        - 用中文，口语化，50-100字
        """)

        parts.append("【健康与活动数据】\n\(todayDataSummary)")

        if !shutterTexts.isEmpty {
            parts.append("【快门记录】\n\(shutterTexts.joined(separator: "\n"))")
        }

        if !moodNotes.isEmpty {
            parts.append("【心情记录】\n\(moodNotes.joined(separator: "\n"))")
        }

        parts.append("只输出描述正文，不加标题、日期或情绪标签。")

        return parts.joined(separator: "\n\n")
    }

    // MARK: - Pattern Insight Prompt

    /// Build a Chinese-language prompt asking AI to describe a detected behavioral pattern.
    ///
    /// The prompt instructs the model to output a single observational sentence (20-40 characters),
    /// describing the pattern without evaluation or prescriptive advice.
    func buildPatternInsightPrompt(_ pattern: DetectedPattern) -> String {
        let timeLabel: String
        switch pattern.timeOfDay {
        case .morning:   timeLabel = "早上"
        case .afternoon: timeLabel = "下午"
        case .evening:   timeLabel = "晚上"
        }
        return """
        请根据以下行为规律，生成一句简洁的中文观察（20-40字）。只描述规律，不评价，不建议，语气温和自然，像老朋友观察到的一件事。

        规律：用户连续\(pattern.streakLength)天\(timeLabel)都在\(pattern.placeName)

        只输出一句话，不加标题或解释。
        """
    }

    // MARK: - Profile Update Prompt

    /// Build a prompt for the weekly profile updater.
    func buildProfileUpdatePrompt(
        currentProfile: String?,
        recentSummaries: [String]
    ) -> String {
        var parts: [String] = []

        parts.append("请根据以下一周的每日摘要，生成或更新用户画像。画像应描述这个人的性格特征、生活习惯、作息规律和兴趣爱好。控制在 200 字以内。")

        if let current = currentProfile, !current.isEmpty {
            parts.append("【当前画像】\n\(current)")
            parts.append("请在此基础上更新，保留准确的部分，修正不再符合的描述，补充新发现的特征。")
        } else {
            parts.append("这是首次生成画像，请尽可能从有限数据中提取特征。")
        }

        parts.append("【近期每日摘要】\n\(recentSummaries.joined(separator: "\n"))")

        parts.append("请直接输出画像文本，不需要标题。")

        return parts.joined(separator: "\n\n")
    }
}
