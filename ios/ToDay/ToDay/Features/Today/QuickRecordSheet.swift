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
            VStack(alignment: .leading, spacing: 24) {
                Text(sheetTitle)
                    .font(.title2.weight(.bold))

                Text(sheetSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                moodGrid

                VStack(alignment: .leading, spacing: 8) {
                    Text("备注")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    TextField("写一句话记录当下…", text: $note)
                        .textFieldStyle(.plain)
                        .padding(14)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(timeFieldTitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

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
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle(mode == .pointOnly ? "补充打点" : "快速记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    Button(mode == .pointOnly ? "保存" : "打点") {
                        guard let mood = selectedMood else { return }
                        let record = MoodRecord(
                            mood: mood,
                            note: note,
                            createdAt: createdAt,
                            isTracking: false
                        )
                        submit(record)
                    }
                    .fontWeight(.medium)
                    .disabled(selectedMood == nil || isSubmitting)

                    if mode == .flexible {
                        Button("开始") {
                            guard let mood = selectedMood else { return }
                            let record = MoodRecord.active(mood: mood, note: note, createdAt: createdAt)
                            submit(record)
                        }
                        .fontWeight(.semibold)
                        .disabled(selectedMood == nil || isSubmitting)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func submit(_ record: MoodRecord) {
        guard !isSubmitting else { return }
        isSubmitting = true
        onSave(record)
        dismiss()
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
