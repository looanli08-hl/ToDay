import Foundation

/// Assembles the full prompt sent to an AI provider by combining:
/// - Personality template (system prompt prefix)
/// - User profile (Layer 1)
/// - Recent daily summaries (Layer 2)
/// - Today's data (Layer 3)
/// - Conversation memory (Layer 4)
/// - User's current input
final class EchoPromptBuilder: @unchecked Sendable {

    private let memoryManager: EchoMemoryManager

    init(memoryManager: EchoMemoryManager) {
        self.memoryManager = memoryManager
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

    // MARK: - Daily Summary Prompt

    /// Build a prompt for the daily summary generator.
    func buildDailySummaryPrompt(
        todayDataSummary: String,
        shutterTexts: [String],
        moodNotes: [String]
    ) -> String {
        var parts: [String] = []

        parts.append("请根据以下数据，生成一段简洁的中文日记摘要（100-150字）。摘要应包含关键活动、情绪和值得记住的细节。")

        parts.append("【健康与活动数据】\n\(todayDataSummary)")

        if !shutterTexts.isEmpty {
            parts.append("【快门记录】\n\(shutterTexts.joined(separator: "\n"))")
        }

        if !moodNotes.isEmpty {
            parts.append("【心情记录】\n\(moodNotes.joined(separator: "\n"))")
        }

        parts.append("请输出摘要正文，不需要标题或日期。同时在最后一行单独输出情绪趋势关键词（如：平静/积极/低落/混合）。")

        return parts.joined(separator: "\n\n")
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
