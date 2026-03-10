import SwiftUI

enum QuickRecordSheetMode {
    case flexible
    case pointOnly
}

struct QuickRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMood: MoodRecord.Mood?
    @State private var note: String = ""
    @State private var createdAt: Date = Date()
    @State private var isSubmitting = false

    let mode: QuickRecordSheetMode
    let onSave: (MoodRecord) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    moodGrid
                    noteSection
                    timeSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 120)
            }
            .background(TodayTheme.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(TodayTheme.inkSoft)
                            .frame(width: 32, height: 32)
                            .background(TodayTheme.card)
                            .clipShape(Circle())
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                actionBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .background(TodayTheme.background.opacity(0.96))
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func submit(_ record: MoodRecord) {
        guard !isSubmitting else { return }
        isSubmitting = true
        onSave(record)
        dismiss()
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(sheetTitle)
                        .font(.system(size: 28, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(TodayTheme.ink)

                    Text(sheetSubtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(TodayTheme.inkMuted)
                        .lineSpacing(3)
                }

                Spacer()

                Text(modeBadgeTitle)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(modeBadgeTint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(modeBadgeBackground)
                    .clipShape(Capsule())
            }
        }
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("备注")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(TodayTheme.inkMuted)

            TextField("写一句话记录当下…", text: $note)
                .textFieldStyle(.plain)
                .padding(14)
                .background(TodayTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(TodayTheme.border, lineWidth: 1)
                )
        }
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(timeFieldTitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(TodayTheme.inkMuted)

            DatePicker(
                "记录时间",
                selection: $createdAt,
                in: ...Date(),
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TodayTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(TodayTheme.border, lineWidth: 1)
            )
        }
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button(mode == .pointOnly ? "保存打点" : "打点") {
                guard let mood = selectedMood else { return }
                let record = MoodRecord(
                    mood: mood,
                    note: note,
                    createdAt: createdAt,
                    isTracking: false
                )
                submit(record)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(mode == .pointOnly ? .white : TodayTheme.inkSoft)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(mode == .pointOnly ? TodayTheme.teal : TodayTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(mode == .pointOnly ? Color.clear : TodayTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .disabled(selectedMood == nil || isSubmitting)
            .opacity(selectedMood == nil || isSubmitting ? 0.45 : 1)

            if mode == .flexible {
                Button("开始一段") {
                    guard let mood = selectedMood else { return }
                    let record = MoodRecord.active(mood: mood, note: note, createdAt: createdAt)
                    submit(record)
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(TodayTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .disabled(selectedMood == nil || isSubmitting)
                .opacity(selectedMood == nil || isSubmitting ? 0.45 : 1)
            }
        }
    }

    private var sheetTitle: String {
        switch mode {
        case .flexible:
            return "记录此刻"
        case .pointOnly:
            return "补一个打点"
        }
    }

    private var sheetSubtitle: String {
        switch mode {
        case .flexible:
            return "可以直接打一个瞬时片段，也可以开始一段持续状态。"
        case .pointOnly:
            return "当前有一段状态正在进行，这里补充一个瞬时片段，不会打断它。"
        }
    }

    private var timeFieldTitle: String {
        switch mode {
        case .flexible:
            return "发生时间"
        case .pointOnly:
            return "打点时间"
        }
    }

    private var modeBadgeTitle: String {
        switch mode {
        case .flexible:
            return "POINT / SESSION"
        case .pointOnly:
            return "POINT ONLY"
        }
    }

    private var modeBadgeTint: Color {
        switch mode {
        case .flexible:
            return TodayTheme.accent
        case .pointOnly:
            return TodayTheme.teal
        }
    }

    private var modeBadgeBackground: Color {
        switch mode {
        case .flexible:
            return TodayTheme.accentSoft
        case .pointOnly:
            return TodayTheme.tealSoft
        }
    }

    private var moodGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
            ForEach(MoodRecord.Mood.allCases) { mood in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedMood = mood
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(mood.emoji)
                            .font(.title)
                        Text(mood.rawValue)
                            .font(.subheadline.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        selectedMood == mood
                            ? Color(red: 0.95, green: 0.90, blue: 0.82)
                            : Color(uiColor: .secondarySystemBackground)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                selectedMood == mood
                                    ? Color(red: 0.74, green: 0.66, blue: 0.57)
                                    : Color.clear,
                                lineWidth: 2
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
