import SwiftUI

struct QuickRecordSheet: View {
    @Binding var isPresented: Bool
    @State private var noteText: String = ""
    @FocusState private var isTextFocused: Bool

    var onSave: ((String) -> Void)?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // Title — large serif italic, journal-like
                Text("note this moment")
                    .font(.system(size: 28, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(AppColor.label)
                    .padding(.top, AppSpacing.xxl)
                    .padding(.horizontal, AppSpacing.lg)

                // Subtle timestamp
                Text(currentTimeString)
                    .font(AppFont.micro())
                    .foregroundStyle(AppColor.labelQuaternary)
                    .tracking(1.0)
                    .padding(.top, AppSpacing.xxs)
                    .padding(.horizontal, AppSpacing.lg)

                // Text input — journal feel, no visible border
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $noteText)
                        .font(AppFont.bodyRegular())
                        .foregroundStyle(AppColor.label)
                        .scrollContentBackground(.hidden)
                        .focused($isTextFocused)
                        .frame(minHeight: 160)
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.top, AppSpacing.lg)

                    if noteText.isEmpty {
                        Text("what's on your mind...")
                            .font(AppFont.whisper())
                            .foregroundStyle(AppColor.labelQuaternary)
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.top, AppSpacing.lg + 8)
                            .allowsHitTesting(false)
                    }
                }

                // Subtle baseline separator
                Rectangle()
                    .fill(AppColor.labelQuaternary.opacity(0.2))
                    .frame(height: 0.5)
                    .padding(.horizontal, AppSpacing.lg)

                Spacer()
            }
            .background(AppColor.background)
            .safeAreaInset(edge: .bottom) {
                saveButton
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppColor.labelTertiary)
                    }
                }
            }
            .onAppear {
                isTextFocused = true
            }
        }
    }

    // MARK: - Save Button

    @ViewBuilder
    private var saveButton: some View {
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        Button {
            guard !trimmed.isEmpty else { return }
            onSave?(trimmed)
            isPresented = false
        } label: {
            Text("save")
                .font(AppFont.body())
                .foregroundStyle(trimmed.isEmpty ? AppColor.labelQuaternary : AppColor.accent)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .disabled(trimmed.isEmpty)
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColor.background)
    }

    // MARK: - Helpers

    private var currentTimeString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
}
