import SwiftUI

/// Text input bar at the bottom of the Echo chat screen.
/// Styled to match the ShutterTextComposer pattern — warm editorial aesthetic.
struct EchoChatInputBar: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let isGenerating: Bool
    let isTemporaryMode: Bool
    let onSend: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Temporary mode indicator
            if isTemporaryMode {
                HStack(spacing: AppSpacing.xxs) {
                    Image(systemName: "eye.slash.fill")
                        .font(.caption2)
                    Text("临时会话 — 对话不会被记录")
                        .font(AppFont.caption)
                }
                .foregroundStyle(AppColor.labelTertiary)
                .padding(.vertical, AppSpacing.xxs)
            }

            Divider()
                .foregroundStyle(AppColor.separator)

            HStack(alignment: .bottom, spacing: AppSpacing.sm) {
                TextField("跟 Echo 说点什么…", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(AppFont.body)
                    .lineLimit(1...6)
                    .focused($isFocused)
                    .padding(14)
                    .background(AppColor.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                    .disabled(isGenerating)

                Button {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onSend(trimmed)
                    text = ""
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(sendButtonColor)
                }
                .disabled(isSendDisabled)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
        }
        .background(AppColor.background)
    }

    // MARK: - Computed

    private var isSendDisabled: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating
    }

    private var sendButtonColor: Color {
        if isSendDisabled {
            return AppColor.labelQuaternary
        }
        return AppColor.echo
    }
}
