import SwiftUI

struct QuickRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMood: MoodRecord.Mood?
    @State private var note: String = ""

    let onSave: (MoodRecord) -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Text("此刻感受")
                    .font(.title2.weight(.bold))

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

                Spacer()
            }
            .padding(20)
            .navigationTitle("快速记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        guard let mood = selectedMood else { return }
                        let record = MoodRecord(mood: mood, note: note)
                        onSave(record)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedMood == nil)
                }
            }
        }
        .presentationDetents([.medium])
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
