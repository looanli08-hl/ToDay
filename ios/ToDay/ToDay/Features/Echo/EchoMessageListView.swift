import SwiftUI
import SwiftData

/// The new Echo tab root view — a message center showing all Echo-initiated messages.
/// Each message links to an independent conversation thread.
struct EchoMessageListView: View {
    @ObservedObject var messageManager: EchoMessageManager
    let threadViewModelFactory: (EchoMessageEntity) -> EchoThreadViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var renamingMessage: EchoMessageEntity?
    @State private var renameText = ""
    @State private var showRenameAlert = false
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
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
                                Button {
                                    renamingMessage = message
                                    renameText = message.displayTitle
                                    showRenameAlert = true
                                } label: {
                                    Label("重命名", systemImage: "pencil")
                                }

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
            .alert("重命名对话", isPresented: $showRenameAlert) {
                TextField("对话名称", text: $renameText)
                Button("保存") {
                    if let msg = renamingMessage {
                        msg.customTitle = renameText.isEmpty ? nil : renameText
                        try? modelContext.save()
                    }
                }
                Button("取消", role: .cancel) {}
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
            if let entity = try? messageManager.createFreeChatMessage() {
                navigationPath.append(entity.id)
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
