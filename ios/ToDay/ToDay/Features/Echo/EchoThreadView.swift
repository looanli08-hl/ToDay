import SwiftUI

/// Conversation detail page for a single Echo message thread.
/// Reuses EchoChatBubbleView and EchoChatInputBar from the existing chat system.
struct EchoThreadView: View {
    @ObservedObject var viewModel: EchoThreadViewModel
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Source banner
            if !viewModel.sourceDescription.isEmpty && viewModel.messageType != .freeChat {
                sourceBanner
            }

            // Scrollable chat area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Chat messages
                        ForEach(Array(viewModel.displayMessages.enumerated()), id: \.element.id) { index, message in
                            let isLast = index == viewModel.displayMessages.count - 1
                            EchoChatBubbleView(
                                message: message,
                                isLastMessage: isLast
                            )
                        }

                        // Thinking indicator
                        if viewModel.isGenerating {
                            EchoThinkingView()
                                .padding(.top, AppSpacing.xxs)
                        }

                        // Error message
                        if let error = viewModel.errorMessage {
                            errorBanner(error)
                        }

                        // Bottom anchor
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.displayMessages.count) { _, _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }

            // Input bar
            EchoChatInputBar(
                text: $inputText,
                isFocused: $isInputFocused,
                isGenerating: viewModel.isGenerating,
                isTemporaryMode: false
            ) { text in
                Task {
                    await viewModel.sendMessage(text)
                }
            }
        }
        .background(AppColor.background)
        .navigationTitle(viewModel.messageType.icon + " " + viewModel.messageType.defaultTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadThread()
        }
    }

    // MARK: - Source Banner

    private var sourceBanner: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "link")
                .font(.caption2)
                .foregroundStyle(AppColor.echo)

            Text("关于：\(viewModel.sourceDescription)")
                .font(AppFont.caption)
                .foregroundStyle(AppColor.labelSecondary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xs)
        .background(AppColor.soft(AppColor.echo))
    }

    // MARK: - Error Banner

    private func errorBanner(_ error: String) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(AppColor.workout)

            Text(error)
                .font(AppFont.caption)
                .foregroundStyle(AppColor.labelSecondary)
                .lineLimit(2)

            Spacer()

            Button("重试") {
                viewModel.errorMessage = nil
            }
            .font(AppFont.caption)
            .foregroundStyle(AppColor.echo)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xs)
        .background(AppColor.soft(AppColor.workout))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xxs)
    }
}
