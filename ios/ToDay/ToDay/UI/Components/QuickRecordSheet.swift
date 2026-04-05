import SwiftUI

struct QuickRecordSheet: View {
    @Binding var isPresented: Bool

    let moods: [MoodRecord.Mood] = MoodRecord.Mood.allCases
    @State private var selectedMood: MoodRecord.Mood?
    @State private var noteText: String = ""
    @State private var isSubmitting = false

    var onSave: ((MoodRecord.Mood, String) -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    // Title
                    Text("记录此刻")
                        .font(AppFont.heading())
                        .foregroundStyle(AppColor.label)

                    Text("选一个心情，写一句话记录当下。")
                        .font(AppFont.bodyRegular())
                        .foregroundStyle(AppColor.labelSecondary)

                    // Mood Grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.sm), count: 3), spacing: AppSpacing.sm) {
                        ForEach(moods) { mood in
                            moodCell(mood)
                        }
                    }

                    // Note Input
                    TextField("写一句话记录当下...", text: $noteText, axis: .vertical)
                        .font(AppFont.bodyRegular())
                        .foregroundStyle(AppColor.label)
                        .padding(AppSpacing.md)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
                        .lineLimit(3...6)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.lg)
            }
            .background(AppColor.background)
            .safeAreaInset(edge: .bottom) {
                actionBar
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
        }
    }

    // MARK: - Mood Cell

    @ViewBuilder
    private func moodCell(_ mood: MoodRecord.Mood) -> some View {
        let isSelected = selectedMood == mood
        VStack(spacing: AppSpacing.xxs) {
            Text(mood.emoji)
                .font(.system(size: 28))
            Text(mood.rawValue)
                .font(AppFont.small())
                .foregroundStyle(isSelected ? AppColor.accent : AppColor.labelSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .padding(.vertical, AppSpacing.xs)
        .background(
            isSelected
                ? AppColor.accent.opacity(0.12)
                : Color.clear
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                .stroke(isSelected ? AppColor.accent : Color.clear, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedMood = mood
            }
        }
        .accessibilityLabel(mood.rawValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Action Bar

    @ViewBuilder
    private var actionBar: some View {
        HStack(spacing: AppSpacing.sm) {
            Button {
                guard let mood = selectedMood, !isSubmitting else { return }
                isSubmitting = true
                onSave?(mood, noteText.trimmingCharacters(in: .whitespacesAndNewlines))
                isPresented = false
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "heart.circle")
                    Text("记录此刻")
                }
                .font(AppFont.body())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(AppColor.accent)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous))
            }
            .disabled(selectedMood == nil || isSubmitting)
            .opacity(selectedMood == nil || isSubmitting ? 0.45 : 1.0)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(
            Color(UIColor.systemGroupedBackground).opacity(0.96)
        )
        .appShadow(.elevated)
    }
}
