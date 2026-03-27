import SwiftUI

/// The new Echo tab root view — a message center showing all Echo-initiated messages.
/// Each message links to an independent conversation thread.
struct EchoMessageListView: View {
    @ObservedObject var messageManager: EchoMessageManager
    let threadViewModelFactory: (EchoMessageEntity) -> EchoThreadViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: AppSpacing.sm) {
                    if messageManager.allMessages.isEmpty {
                        emptyState
                    } else {
                        // Message list
                        ForEach(messageManager.allMessages, id: \.id) { message in
                            NavigationLink(value: message.id) {
                                EchoMessageCard(entity: message)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    try? messageManager.deleteMessage(id: message.id)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }

                    // Bottom entry: free chat
                    freeChatButton
                        .padding(.top, AppSpacing.sm)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xxl)
            }
            .background(AppColor.background)
            .navigationTitle("Echo")
            .navigationDestination(for: UUID.self) { messageId in
                if let message = messageManager.allMessages.first(where: { $0.id == messageId }) {
                    let vm = threadViewModelFactory(message)
                    EchoThreadView(viewModel: vm)
                        .onAppear {
                            if !message.isRead {
                                try? messageManager.markAsRead(id: message.id)
                            }
                        }
                }
            }
            .refreshable {
                messageManager.refresh()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()
                .frame(height: AppSpacing.xxl)

            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(AppColor.echo)

            Text("Echo 还没有给你发消息")
                .font(AppFont.subheadline)
                .foregroundStyle(AppColor.labelSecondary)

            Text("Echo 会根据你的日常记录主动给你发消息，\n就像一个关心你的朋友。")
                .font(AppFont.caption)
                .foregroundStyle(AppColor.labelTertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xxl)
    }

    // MARK: - Free Chat Button

    private var freeChatButton: some View {
        Button {
            if let _ = try? messageManager.createFreeChatMessage() {
                // The NavigationLink will handle navigation via the message list refresh
            }
        } label: {
            HStack(spacing: AppSpacing.xs) {
                Text("✨")
                    .font(.body)

                Text("跟 Echo 随便聊聊")
                    .font(AppFont.subheadline)
                    .foregroundStyle(AppColor.echo)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(AppColor.labelTertiary)
            }
            .padding(AppSpacing.md)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .strokeBorder(AppColor.soft(AppColor.echo), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
