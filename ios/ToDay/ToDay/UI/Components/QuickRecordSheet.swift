import SwiftUI

struct QuickRecordSheet: View {
    @Binding var isPresented: Bool
    @State private var noteText: String = ""
    @FocusState private var isTextFocused: Bool

    var onSave: ((String) -> Void)?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // Header
                Text("记录此刻")
                    .font(AppFont.heading())
                    .foregroundStyle(AppColor.label)

                // Text input
                TextEditor(text: $noteText)
                    .font(AppFont.bodyRegular())
                    .foregroundStyle(AppColor.label)
                    .scrollContentBackground(.hidden)
                    .focused($isTextFocused)
                    .frame(minHeight: 120)
                    .padding(AppSpacing.md)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        if noteText.isEmpty {
                            Text("记录此刻的想法...")
                                .font(AppFont.bodyRegular())
                                .foregroundStyle(AppColor.labelTertiary)
                                .padding(AppSpacing.md)
                                .padding(.top, 8)
                                .allowsHitTesting(false)
                        }
                    }

                Spacer()
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.lg)
            .background(AppColor.background)
            .safeAreaInset(edge: .bottom) {
                saveButton
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        isPresented = false
                    }
                    .font(AppFont.body())
                    .foregroundStyle(AppColor.accent)
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
            Text("保存")
                .font(AppFont.body())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(AppColor.accent)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous))
        }
        .disabled(trimmed.isEmpty)
        .opacity(trimmed.isEmpty ? 0.45 : 1.0)
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(
            Color(UIColor.systemGroupedBackground).opacity(0.96)
        )
        .appShadow(.elevated)
    }
}
