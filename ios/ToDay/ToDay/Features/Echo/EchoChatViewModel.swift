import Foundation
import SwiftData

@MainActor
final class EchoChatViewModel: ObservableObject {
    // MARK: - Published State

    @Published private(set) var displayMessages: [EchoChatMessage] = []
    @Published private(set) var isGenerating = false
    @Published var dailyInsight: String?
    @Published var mirrorPortrait: String?
    @Published var showMirrorSheet = false
    @Published var errorMessage: String?
    /// Today's live timeline data injected by parent view. Set via .onChange or direct assignment.
    var todayDataSummary: String? = nil
    @Published var isTemporaryMode = false {
        didSet {
            if isTemporaryMode {
                startTemporarySession()
            } else {
                endTemporarySession()
            }
        }
    }

    /// User-selected personality. Persisted to UserDefaults.
    var personality: EchoPersonality {
        get {
            guard let raw = UserDefaults.standard.string(forKey: "today.echo.personality") else {
                return .gentle
            }
            return EchoPersonality(rawValue: raw) ?? .gentle
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "today.echo.personality")
            objectWillChange.send()
        }
    }

    // MARK: - Dependencies

    private let aiService: any EchoAIProviding
    private let memoryManager: EchoMemoryManager
    private let promptBuilder: EchoPromptBuilder
    private let container: ModelContainer

    // MARK: - Internal State

    private var currentSession: EchoChatSessionEntity?
    private var temporaryMessages: [EchoChatMessage] = []

    init(
        aiService: any EchoAIProviding,
        memoryManager: EchoMemoryManager,
        promptBuilder: EchoPromptBuilder,
        container: ModelContainer
    ) {
        self.aiService = aiService
        self.memoryManager = memoryManager
        self.promptBuilder = promptBuilder
        self.container = container
    }

    // MARK: - Session Management

    /// Load or create today's chat session.
    func loadCurrentSession() {
        let context = ModelContext(container)
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())

        var descriptor = FetchDescriptor<EchoChatSessionEntity>(
            predicate: #Predicate {
                $0.isTemporary == false && $0.lastActiveAt >= startOfDay
            },
            sortBy: [SortDescriptor(\.lastActiveAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        if let existing = try? context.fetch(descriptor).first {
            currentSession = existing
            displayMessages = existing.toChatMessages()
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "M月d日"
            let session = EchoChatSessionEntity(
                title: "\(formatter.string(from: Date())) 对话"
            )
            context.insert(session)
            try? context.save()
            currentSession = session
            displayMessages = []
        }
    }

    // MARK: - Send Message

    /// Send a user message and get Echo's response.
    func sendMessage(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        errorMessage = nil

        // Add user message to display
        let userMessage = EchoChatMessage(role: .user, content: trimmed)
        displayMessages.append(userMessage)

        // Persist user message (unless temporary)
        if !isTemporaryMode {
            persistMessage(role: .user, content: trimmed)
        }

        // Generate AI response
        isGenerating = true

        do {
            // Build conversation history for context
            let history: [EchoChatMessage]
            if isTemporaryMode {
                history = temporaryMessages
            } else {
                // Use recent messages as conversation history (limit to last 20 turns)
                let recentMessages = Array(displayMessages.suffix(20).dropLast())
                history = recentMessages
            }

            let messages = promptBuilder.buildMessages(
                userInput: trimmed,
                personality: personality,
                todayDataSummary: todayDataSummary,
                conversationHistory: history
            )

            let response = try await aiService.respond(messages: messages)

            let assistantMessage = EchoChatMessage(role: .assistant, content: response)
            displayMessages.append(assistantMessage)

            // Persist assistant message (unless temporary)
            if !isTemporaryMode {
                persistMessage(role: .assistant, content: response)
                // Update conversation memory after each exchange
                await updateConversationMemory()
            } else {
                temporaryMessages.append(userMessage)
                temporaryMessages.append(assistantMessage)
            }
        } catch {
            errorMessage = (error as? EchoAIError)?.errorDescription
                ?? "AI 回应失败：\(error.localizedDescription)"
        }

        isGenerating = false
    }

    // MARK: - Daily Insight

    /// Load today's daily insight from stored summaries.
    func loadDailyInsight() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayKey = formatter.string(from: Date())

        if let summary = memoryManager.loadSummary(forDateKey: todayKey) {
            dailyInsight = summary.summaryText
        } else {
            // Try yesterday's if today's isn't generated yet
            let calendar = Calendar.current
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) {
                let yesterdayKey = formatter.string(from: yesterday)
                if let summary = memoryManager.loadSummary(forDateKey: yesterdayKey) {
                    dailyInsight = summary.summaryText
                }
            }
        }
    }

    // MARK: - Mirror Portrait

    /// Generate the "Echo 眼中的你" portrait.
    func generateMirrorPortrait() async {
        isGenerating = true
        errorMessage = nil

        do {
            let profile = memoryManager.loadUserProfile()
            let summaries = memoryManager.loadRecentSummaries(days: 7)
            let summaryTexts = summaries.map { "\($0.dateKey): \($0.summaryText)" }

            let prompt: String
            if let profileText = profile?.profileText, !profileText.isEmpty {
                prompt = """
                基于以下用户画像和近期数据，生成一段温暖的第二人称描述（"你是..."），\
                像一个了解用户的老朋友在描述他们。200字以内。

                【画像】
                \(profileText)

                【近期摘要】
                \(summaryTexts.joined(separator: "\n"))

                请直接输出描述文本，不需要标题。
                """
            } else if !summaries.isEmpty {
                prompt = """
                基于以下近期数据，生成一段温暖的第二人称描述（"你是..."），\
                像一个刚开始了解用户的朋友在描述初步印象。150字以内。

                【近期摘要】
                \(summaryTexts.joined(separator: "\n"))

                请直接输出描述文本，不需要标题。
                """
            } else {
                prompt = """
                你还没有足够的数据来描述用户。生成一段简短的温暖的开场白，\
                告诉用户你还在了解他们，期待通过日常互动更好地认识他们。80字以内。
                """
            }

            let result = try await aiService.generateProfile(prompt: prompt)
            mirrorPortrait = result.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            errorMessage = (error as? EchoAIError)?.errorDescription
                ?? "生成画像失败：\(error.localizedDescription)"
        }

        isGenerating = false
    }

    /// Send feedback about the mirror portrait ("这不像我").
    func sendMirrorFeedback(_ feedback: String) async {
        isGenerating = true
        errorMessage = nil

        do {
            let currentPortrait = mirrorPortrait ?? ""
            let prompt = """
            用户看了你对他的描述后，给出了反馈。请根据反馈调整画像描述。200字以内。

            【当前描述】
            \(currentPortrait)

            【用户反馈】
            \(feedback)

            请直接输出调整后的描述文本。
            """

            let result = try await aiService.generateProfile(prompt: prompt)
            let updatedPortrait = result.trimmingCharacters(in: .whitespacesAndNewlines)
            mirrorPortrait = updatedPortrait

            // Also update the stored user profile with this feedback
            let summaryIDs = memoryManager.loadRecentSummaries(days: 7).map(\.id)
            try memoryManager.saveUserProfile(
                text: updatedPortrait,
                sourceSummaryIDs: summaryIDs
            )
        } catch {
            errorMessage = (error as? EchoAIError)?.errorDescription
                ?? "更新画像失败：\(error.localizedDescription)"
        }

        isGenerating = false
    }

    // MARK: - Temporary Mode

    private func startTemporarySession() {
        temporaryMessages = []
        // Keep existing displayMessages visible but mark the boundary
        let marker = EchoChatMessage(
            role: .system,
            content: "临时会话已开启，以下对话不会被记录"
        )
        displayMessages.append(marker)
    }

    private func endTemporarySession() {
        temporaryMessages = []
        // Reload the real session messages
        if let session = currentSession {
            displayMessages = session.toChatMessages()
        } else {
            displayMessages = []
        }
    }

    // MARK: - Private Helpers

    private func persistMessage(role: EchoChatRole, content: String) {
        guard let session = currentSession else { return }
        let context = ModelContext(container)

        // Re-fetch the session in this context
        let sessionID = session.id
        var descriptor = FetchDescriptor<EchoChatSessionEntity>(
            predicate: #Predicate { $0.id == sessionID }
        )
        descriptor.fetchLimit = 1

        guard let liveSession = try? context.fetch(descriptor).first else { return }
        liveSession.addMessage(role: role, content: content)
        try? context.save()

        // Update our reference
        currentSession = liveSession
    }

    private func updateConversationMemory() async {
        // Build a summary of the current conversation for Layer 4
        let recentMessages = displayMessages.suffix(10)
        let turnSummary = recentMessages
            .filter { $0.role != .system }
            .map { "\($0.role == .user ? "用户" : "Echo"): \($0.content)" }
            .joined(separator: "\n")

        let topics = extractTopics(from: turnSummary)

        do {
            try memoryManager.saveConversationMemory(
                summary: String(turnSummary.prefix(500)),
                turnCount: displayMessages.filter { $0.role == .user }.count,
                topics: topics
            )
        } catch {
            // Non-critical — log but don't surface to user
            print("[EchoChatViewModel] Failed to update conversation memory: \(error)")
        }
    }

    /// Simple topic extraction: look for noun-like segments.
    private func extractTopics(from text: String) -> [String] {
        // Basic keyword extraction — could be upgraded to AI-based later
        let words = text.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            .filter { $0.count >= 2 }

        // Deduplicate and take top frequent terms
        var frequency: [String: Int] = [:]
        for word in words {
            frequency[word, default: 0] += 1
        }

        let sorted = frequency.sorted { $0.value > $1.value }
        return Array(sorted.prefix(5).map(\.key))
    }
}
