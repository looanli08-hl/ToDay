import SwiftUI

struct ShutterTextComposer: View {
    @State private var text: String = ""
    @FocusState private var isFocused: Bool
    let onSend: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 10) {
                TextField("写下此刻的想法…", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .lineLimit(1...6)
                    .focused($isFocused)
                    .padding(14)
                    .background(TodayTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(TodayTheme.border, lineWidth: 1)
                    )

                Button {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onSend(trimmed)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(
                            text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? TodayTheme.inkFaint
                                : TodayTheme.accent
                        )
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .onAppear {
            isFocused = true
        }
    }
}
