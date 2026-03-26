import SwiftUI

struct EchoChatScreen: View {
    @ObservedObject var viewModel: EchoChatViewModel
    @ObservedObject var echoViewModel: EchoViewModel
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    @State private var showOldEchoes = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Scrollable content area
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // Daily insight card (if available)
                            if let insight = viewModel.dailyInsight {
                                EchoDailyInsightCard(insightText: insight) {
                                    Task {
                                        await viewModel.sendMessage("跟我聊聊今天的洞察")
                                    }
                                }
                                .padding(.top, AppSpacing.md)
                                .padding(.bottom, AppSpacing.sm)
                            }

                            // Mirror button + temp mode toggle
                            actionBar

                            // Old echo notification link (collapsed)
                            if !echoViewModel.todayEchoes.isEmpty {
                                oldEchoesLink
                            }

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

                            // Bottom spacer for scroll anchor
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
                    isTemporaryMode: viewModel.isTemporaryMode
                ) { text in
                    Task {
                        await viewModel.sendMessage(text)
                    }
                }
            }
            .background(AppColor.background)
            .navigationTitle("Echo")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            viewModel.showMirrorSheet = true
                        } label: {
                            Label("Echo 眼中的你", systemImage: "person.crop.circle.badge.questionmark")
                        }

                        Toggle(isOn: $viewModel.isTemporaryMode) {
                            Label("临时会话", systemImage: "eye.slash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(AppColor.labelSecondary)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showMirrorSheet) {
                EchoMirrorSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showOldEchoes) {
                NavigationStack {
                    EchoScreen(viewModel: echoViewModel)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("完成") { showOldEchoes = false }
                            }
                        }
                }
            }
            .onAppear {
                viewModel.loadCurrentSession()
                viewModel.loadDailyInsight()
            }
        }
    }

    // MARK: - Subviews

    private var actionBar: some View {
        HStack(spacing: AppSpacing.sm) {
            // Mirror button
            Button {
                viewModel.showMirrorSheet = true
            } label: {
                Label("Echo 眼中的你", systemImage: "sparkles")
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.echo)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.xs)
                    .background(AppColor.soft(AppColor.echo))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer()

            // Temp mode indicator
            if viewModel.isTemporaryMode {
                HStack(spacing: AppSpacing.xxs) {
                    Image(systemName: "eye.slash.fill")
                        .font(.caption2)
                    Text("临时会话")
                        .font(AppFont.caption)
                }
                .foregroundStyle(AppColor.labelTertiary)
                .padding(.horizontal, AppSpacing.xs)
                .padding(.vertical, AppSpacing.xxs)
                .background(AppColor.surfaceElevated)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xs)
    }

    private var oldEchoesLink: some View {
        Button {
            showOldEchoes = true
        } label: {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "bell.badge")
                    .font(.caption)
                    .foregroundStyle(AppColor.echo)

                Text("\(echoViewModel.todayEchoes.count) 条回响待查看")
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.labelSecondary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(AppColor.labelTertiary)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.xs)
    }

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
