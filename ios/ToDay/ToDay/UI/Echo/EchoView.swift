import SwiftUI
import SwiftData

struct EchoView: View {
    @ObservedObject var messageManager: EchoMessageManager
    let aiService: any EchoAIProviding
    let promptBuilder: EchoPromptBuilder
    let container: ModelContainer

    @State private var selectedMessage: EchoMessageEntity?
    @State private var showThread = false

    var body: some View {
        NavigationStack {
            Group {
                if messageManager.allMessages.isEmpty {
                    emptyState
                } else {
                    messageList
                }
            }
            .background(AppColor.background)
            .navigationTitle("Echo")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        startFreeChat()
                    } label: {
                        Image(systemName: "plus.bubble")
                            .foregroundStyle(AppColor.accent)
                    }
                    .accessibilityLabel("新对话")
                }
            }
            .navigationDestination(isPresented: $showThread) {
                if let message = selectedMessage {
                    EchoThreadView(
                        message: message,
                        aiService: aiService,
                        promptBuilder: promptBuilder,
                        container: container
                    )
                }
            }
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.sm) {
                ForEach(messageManager.allMessages, id: \.id) { message in
                    messageRow(message)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.md)
        }
    }

    private func messageRow(_ message: EchoMessageEntity) -> some View {
        Button {
            try? messageManager.markAsRead(id: message.id)
            selectedMessage = message
            showThread = true
        } label: {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                // Type icon
                Text(message.messageType.icon)
                    .font(.system(size: 24))

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    HStack {
                        Text(message.displayTitle)
                            .font(AppFont.body())
                            .foregroundStyle(AppColor.label)

                        Spacer()

                        if !message.isRead {
                            Circle()
                                .fill(AppColor.accent)
                                .frame(width: 8, height: 8)
                        }
                    }

                    if !message.preview.isEmpty {
                        Text(message.preview)
                            .font(AppFont.bodyRegular())
                            .foregroundStyle(AppColor.labelSecondary)
                            .lineLimit(2)
                    }

                    Text(relativeDate(message.createdAt))
                        .font(AppFont.small())
                        .foregroundStyle(AppColor.labelQuaternary)
                }
            }
            .padding(AppSpacing.md)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            .appShadow(.subtle)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(AppColor.echo)

            Text("Echo 还在了解你")
                .font(AppFont.heading())
                .foregroundStyle(AppColor.label)

            Text("当 Unfold 收集到足够的数据后，Echo 会给你发消息，分享它的观察。你也可以直接和它聊天。")
                .font(AppFont.bodyRegular())
                .foregroundStyle(AppColor.labelSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Button {
                startFreeChat()
            } label: {
                Text("随便聊聊")
                    .font(AppFont.body())
                    .foregroundStyle(.white)
                    .frame(maxWidth: 200, minHeight: 44)
                    .background(AppColor.accent)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous))
            }
        }
        .padding(.horizontal, AppSpacing.xl)
    }

    // MARK: - Actions

    private func startFreeChat() {
        if let message = try? messageManager.createFreeChatMessage() {
            selectedMessage = message
            showThread = true
        }
    }

    // MARK: - Helpers

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
