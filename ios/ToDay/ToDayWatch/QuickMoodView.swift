import SwiftUI
import WatchKit

struct QuickMoodView: View {
    @Environment(\.dismiss) private var dismiss

    let onSelect: (MoodRecord.Mood) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Self.moods) { mood in
                Button {
                    onSelect(mood)
                    WKInterfaceDevice.current().play(.success)
                    dismiss()
                } label: {
                    VStack(spacing: 6) {
                        Text(mood.emoji)
                            .font(.system(size: 26))

                        Text(mood.rawValue)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .lineLimit(1)
                    }
                    .foregroundStyle(WatchTheme.text)
                    .frame(maxWidth: .infinity, minHeight: 62)
                    .background(WatchTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(WatchTheme.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .background(WatchTheme.background.ignoresSafeArea())
    }

    private static let moods: [MoodRecord.Mood] = [
        .happy,
        .calm,
        .tired,
        .focused
    ]
}
