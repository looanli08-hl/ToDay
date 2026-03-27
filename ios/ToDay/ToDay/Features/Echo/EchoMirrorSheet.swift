import SwiftUI

/// Sheet that displays the "Echo 眼中的你" user portrait.
/// Users can provide feedback ("这不像我") to refine the portrait.
struct EchoMirrorSheet: View {
    @ObservedObject var viewModel: EchoChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var feedbackText = ""
    @State private var showFeedbackInput = false
    @FocusState private var isFeedbackFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Header illustration
                    headerSection

                    // Portrait content
                    if viewModel.isGenerating && viewModel.mirrorPortrait == nil {
                        loadingSection
                    } else if let portrait = viewModel.mirrorPortrait {
                        portraitSection(portrait)
                    } else if let error = viewModel.errorMessage {
                        errorSection(error)
                    }
                }
                .padding(.vertical, AppSpacing.lg)
            }
            .background(AppColor.background)
            .navigationTitle("Echo 眼中的你")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .task {
            if viewModel.mirrorPortrait == nil {
                await viewModel.generateMirrorPortrait()
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(AppColor.echo)

            Text("Echo 基于你的日常数据\n描绘出的你")
                .font(AppFont.subheadline)
                .foregroundStyle(AppColor.labelSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    private var loadingSection: some View {
        VStack(spacing: AppSpacing.md) {
            ProgressView()
            Text("Echo 正在描绘你的画像…")
                .font(AppFont.caption)
                .foregroundStyle(AppColor.labelTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xxl)
    }

    private func portraitSection(_ portrait: String) -> some View {
        VStack(spacing: AppSpacing.lg) {
            // Portrait card
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text(portrait)
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.label)
                    .lineSpacing(6)
                    .textSelection(.enabled)
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
            .appShadow(.subtle)
            .padding(.horizontal, AppSpacing.md)

            // Feedback section
            if showFeedbackInput {
                feedbackInputSection
            } else {
                feedbackButtons
            }

            // Updating indicator
            if viewModel.isGenerating {
                HStack(spacing: AppSpacing.xs) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("正在更新画像…")
                        .font(AppFont.caption)
                        .foregroundStyle(AppColor.labelTertiary)
                }
            }
        }
    }

    private var feedbackButtons: some View {
        HStack(spacing: AppSpacing.sm) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showFeedbackInput = true
                }
            } label: {
                Label("这不像我", systemImage: "hand.thumbsdown")
                    .font(AppFont.subheadline)
                    .foregroundStyle(AppColor.labelSecondary)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.xs)
                    .background(AppColor.surfaceElevated)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                // Share functionality — future enhancement
            } label: {
                Label("分享", systemImage: "square.and.arrow.up")
                    .font(AppFont.subheadline)
                    .foregroundStyle(AppColor.echo)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.xs)
                    .background(AppColor.soft(AppColor.echo))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var feedbackInputSection: some View {
        VStack(spacing: AppSpacing.sm) {
            Text("告诉 Echo 哪里不准确")
                .font(AppFont.caption)
                .foregroundStyle(AppColor.labelSecondary)

            HStack(alignment: .bottom, spacing: AppSpacing.sm) {
                TextField("例如：我其实不太爱跑步…", text: $feedbackText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(AppFont.body)
                    .lineLimit(1...4)
                    .focused($isFeedbackFocused)
                    .padding(14)
                    .background(AppColor.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))

                Button {
                    let trimmed = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    Task {
                        await viewModel.sendMirrorFeedback(trimmed)
                        feedbackText = ""
                        withAnimation {
                            showFeedbackInput = false
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? AppColor.labelQuaternary
                                : AppColor.echo
                        )
                }
                .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isGenerating)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppSpacing.md)
        }
        .onAppear {
            isFeedbackFocused = true
        }
    }

    private func errorSection(_ error: String) -> some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(AppColor.labelTertiary)

            Text(error)
                .font(AppFont.subheadline)
                .foregroundStyle(AppColor.labelSecondary)
                .multilineTextAlignment(.center)

            Button("重试") {
                Task {
                    await viewModel.generateMirrorPortrait()
                }
            }
            .font(AppFont.subheadline)
            .foregroundStyle(AppColor.echo)
        }
        .padding(.horizontal, AppSpacing.lg)
    }
}
