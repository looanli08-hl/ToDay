import Foundation
import SwiftData

@MainActor
final class EchoThreadViewModel: ObservableObject {
    // MARK: - Published State

    @Published private(set) var displayMessages: [EchoChatMessage] = []
    @Published private(set) var isGenerating = false
    @Published var errorMessage: String?

    // MARK: - Properties

    let threadId: UUID
    let sourceData: EchoSourceData?
    let messageType: EchoMessageType
    let sourceDescription: String

    // MARK: - Dependencies

    private let aiService: any EchoAIProviding
    private let memoryManager: EchoMemoryManager
    private let promptBuilder: EchoPromptBuilder
    private let container: ModelContainer
    private let todayDataSummary: String?

    // MARK: - Internal

    private var currentSession: EchoChatSessionEntity?

    init(
        threadId: UUID,
        sourceData: EchoSourceData?,
        messageType: EchoMessageType,
        sourceDescription: String,
        aiService: any EchoAIProviding,
        memoryManager: EchoMemoryManager,
        promptBuilder: EchoPromptBuilder,
        container: ModelContainer,
        todayDataSummary: String? = nil
    ) {
        self.threadId = threadId
        self.sourceData = sourceData
        self.messageType = messageType
        self.sourceDescription = sourceDescription
        self.aiService = aiService
        self.memoryManager = memoryManager
        self.promptBuilder = promptBuilder
        self.container = container
        self.todayDataSummary = todayDataSummary
    }

    // MARK: - Load Thread

    func loadThread() {
        let context = ModelContext(container)
        let id = threadId
        var descriptor = FetchDescriptor<EchoChatSessionEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1

        if let session = try? context.fetch(descriptor).first {
            currentSession = session
            displayMessages = session.toChatMessages()
        }
    }

    // MARK: - Send Message

    func sendMessage(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        errorMessage = nil

        // Add user message to display
        let userMessage = EchoChatMessage(role: .user, content: trimmed)
        displayMessages.append(userMessage)

        // Persist user message
        persistMessage(role: .user, content: trimmed)

        // Generate AI response
        isGenerating = true

        do {
            let recentMessages = Array(displayMessages.suffix(20).dropLast())
            let messages = promptBuilder.buildThreadMessages(
                userInput: trimmed,
                personality: currentPersonality,
                sourceData: sourceData,
                sourceDescription: sourceDescription,
                messageType: messageType,
                todayDataSummary: todayDataSummary,
                conversationHistory: recentMessages
            )

            let response = try await aiService.respond(messages: messages)

            let assistantMessage = EchoChatMessage(role: .assistant, content: response)
            displayMessages.append(assistantMessage)

            persistMessage(role: .assistant, content: response)
        } catch {
            errorMessage = (error as? EchoAIError)?.errorDescription
                ?? "AI 回应失败：\(error.localizedDescription)"
        }

        isGenerating = false
    }

    // MARK: - Private

    private var currentPersonality: EchoPersonality {
        guard let raw = UserDefaults.standard.string(forKey: "today.echo.personality") else {
            return .gentle
        }
        return EchoPersonality(rawValue: raw) ?? .gentle
    }

    private func persistMessage(role: EchoChatRole, content: String) {
        guard let session = currentSession else { return }
        let context = ModelContext(container)

        let sessionID = session.id
        var descriptor = FetchDescriptor<EchoChatSessionEntity>(
            predicate: #Predicate { $0.id == sessionID }
        )
        descriptor.fetchLimit = 1

        guard let liveSession = try? context.fetch(descriptor).first else { return }
        liveSession.addMessage(role: role, content: content)
        try? context.save()

        currentSession = liveSession
    }
}
