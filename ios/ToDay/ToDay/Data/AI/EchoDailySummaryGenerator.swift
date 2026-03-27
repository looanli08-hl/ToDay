import Foundation

/// Generates a daily summary by feeding the day's data to AI and persisting the result.
///
/// Called at bedtime (via EchoScheduler, future task) or on strong-emotion trigger.
/// The summary is stored as a `DailySummaryEntity` and used by `EchoPromptBuilder`
/// as Layer 2 (short-term memory) context.
final class EchoDailySummaryGenerator: @unchecked Sendable {

    private let aiService: any EchoAIProviding
    private let memoryManager: EchoMemoryManager
    private let promptBuilder: EchoPromptBuilder

    init(
        aiService: any EchoAIProviding,
        memoryManager: EchoMemoryManager,
        promptBuilder: EchoPromptBuilder
    ) {
        self.aiService = aiService
        self.memoryManager = memoryManager
        self.promptBuilder = promptBuilder
    }

    /// Generate and persist a daily summary for the given date.
    ///
    /// - Parameters:
    ///   - dateKey: Date string "yyyy-MM-dd"
    ///   - todayDataSummary: Pre-formatted string of health/activity data
    ///   - shutterTexts: Text content from today's shutter records
    ///   - moodNotes: Formatted mood records ("mood: note")
    ///   - isEmotionTriggered: Whether this was triggered by a strong emotion event
    func generateDailySummary(
        dateKey: String,
        todayDataSummary: String,
        shutterTexts: [String],
        moodNotes: [String],
        isEmotionTriggered: Bool = false
    ) async throws {
        let prompt = promptBuilder.buildDailySummaryPrompt(
            todayDataSummary: todayDataSummary,
            shutterTexts: shutterTexts,
            moodNotes: moodNotes
        )

        let rawResponse = try await aiService.summarize(prompt: prompt)
        let (summaryText, moodTrend) = parseSummaryResponse(rawResponse)

        try memoryManager.saveDailySummary(
            dateKey: dateKey,
            summaryText: summaryText,
            moodTrend: moodTrend,
            highlights: extractHighlights(from: summaryText),
            isEmotionTriggered: isEmotionTriggered
        )
    }

    // MARK: - Parsing

    /// Parse the AI response: body text + mood trend on the last line.
    ///
    /// Expected format:
    /// ```
    /// 今天走了 8000 步，心情不错...
    /// 平静
    /// ```
    private func parseSummaryResponse(_ response: String) -> (summaryText: String, moodTrend: String?) {
        let lines = response.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }

        guard lines.count >= 2 else {
            return (response.trimmingCharacters(in: .whitespacesAndNewlines), nil)
        }

        let moodLine = lines.last!.trimmingCharacters(in: .whitespacesAndNewlines)
        let knownMoods = ["平静", "积极", "低落", "混合", "兴奋", "焦虑", "疲惫", "满足"]

        if knownMoods.contains(moodLine) {
            let summaryText = lines.dropLast().joined(separator: "\n")
            return (summaryText, moodLine)
        }

        return (response.trimmingCharacters(in: .whitespacesAndNewlines), nil)
    }

    /// Extract short highlights from the summary text.
    /// Simple heuristic: split by Chinese punctuation, take first few segments.
    private func extractHighlights(from text: String) -> [String] {
        let separators = CharacterSet(charactersIn: "，。；！？、")
        let segments = text.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count >= 4 }

        return Array(segments.prefix(3))
    }
}
