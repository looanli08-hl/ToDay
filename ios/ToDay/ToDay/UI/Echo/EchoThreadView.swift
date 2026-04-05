import SwiftUI
import SwiftData

struct EchoThreadView: View {
    let message: EchoMessageEntity
    let aiService: any EchoAIProviding
    let promptBuilder: EchoPromptBuilder
    let container: ModelContainer

    @State private var chatMessages: [EchoChatMessage] = []
    @State private var inputText: String = ""
    @State private var isSending = false
    @State private var errorText: String?

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: AppSpacing.sm) {
                        ForEach(chatMessages) { msg in
                            messageBubble(msg)
                                .id(msg.id)
                        }

                        if isSending {
                            HStack {
                                ProgressView()
                                    .tint(AppColor.accent)
                                Text("Echo 正在思考...")
                                    .font(AppFont.small())
                                    .foregroundStyle(AppColor.labelTertiary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, AppSpacing.md)
                        }

                        if let error = errorText {
                            Text(error)
                                .font(AppFont.small())
                                .foregroundStyle(AppColor.mood)
                                .padding(.horizontal, AppSpacing.md)
                        }
                    }
                    .padding(.vertical, AppSpacing.md)
                }
                .onChange(of: chatMessages.count) { _, _ in
                    if let last = chatMessages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Input bar
            inputBar
        }
        .background(AppColor.background)
        .navigationTitle(message.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            loadThread()
        }
    }

    // MARK: - Message Bubble

    @ViewBuilder
    private func messageBubble(_ msg: EchoChatMessage) -> some View {
        let isUser = msg.role == .user

        HStack {
            if isUser { Spacer(minLength: 60) }

            Text(msg.content)
                .font(AppFont.bodyRegular())
                .foregroundStyle(isUser ? .white : AppColor.label)
                .lineSpacing(4)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(
                    isUser
                        ? AppColor.accent
                        : AppColor.surface
                )
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
                .appShadow(.subtle)

            if !isUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal, AppSpacing.md)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: AppSpacing.sm) {
            TextField("说点什么...", text: $inputText, axis: .vertical)
                .font(AppFont.bodyRegular())
                .foregroundStyle(AppColor.label)
                .lineLimit(1...4)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending
                            ? AppColor.labelQuaternary
                            : AppColor.accent
                    )
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            .accessibilityLabel("发送")
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xs)
        .background(
            Color(UIColor.systemGroupedBackground).opacity(0.96)
        )
    }

    // MARK: - Thread Loading

    private func loadThread() {
        let context = ModelContext(container)
        let threadId = message.threadId
        var descriptor = FetchDescriptor<EchoChatSessionEntity>(
            predicate: #Predicate { $0.id == threadId }
        )
        descriptor.fetchLimit = 1

        guard let session = try? context.fetch(descriptor).first else { return }
        chatMessages = session.toChatMessages().filter { $0.role != .system }
    }

    // MARK: - Send Message

    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }

        let userMessage = EchoChatMessage(role: .user, content: trimmed)
        chatMessages.append(userMessage)
        inputText = ""
        isSending = true
        errorText = nil

        // Persist user message to thread
        persistMessage(role: .user, content: trimmed)

        Task {
            do {
                let history = chatMessages.filter { $0.role != .system }

                let messages = promptBuilder.buildThreadMessages(
                    userInput: trimmed,
                    personality: .gentle,
                    sourceData: message.sourceData,
                    sourceDescription: message.sourceDescription,
                    messageType: message.messageType,
                    conversationHistory: history.dropLast().map { $0 }
                )

                let response = try await aiService.respond(messages: messages)

                let assistantMessage = EchoChatMessage(role: .assistant, content: response)
                chatMessages.append(assistantMessage)

                // Persist assistant message
                persistMessage(role: .assistant, content: response)
            } catch {
                errorText = error.localizedDescription
            }

            isSending = false
        }
    }

    private func persistMessage(role: EchoChatRole, content: String) {
        let context = ModelContext(container)
        let threadId = message.threadId
        var descriptor = FetchDescriptor<EchoChatSessionEntity>(
            predicate: #Predicate { $0.id == threadId }
        )
        descriptor.fetchLimit = 1

        guard let session = try? context.fetch(descriptor).first else { return }
        session.addMessage(role: role, content: content)
        try? context.save()
    }
}
