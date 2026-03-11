import SwiftUI

struct WatchHomeView: View {
    private enum EntryMode: String, CaseIterable, Identifiable {
        case point = "打点"
        case session = "开始一段"

        var id: String { rawValue }
    }

    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    @State private var entryMode: EntryMode = .point

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let activeSession = connectivityManager.activeSession {
                        activeSessionSection(activeSession)
                    } else {
                        modePickerSection
                    }

                    moodGridSection
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .background(WatchTheme.background)
            .navigationTitle("ToDay")
        }
    }

    private func activeSessionSection(_ activeSession: MoodRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("进行中")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(WatchTheme.teal)

            VStack(alignment: .leading, spacing: 6) {
                Text("\(activeSession.mood.emoji) \(activeSession.mood.rawValue)")
                    .font(.headline)
                    .foregroundStyle(WatchTheme.text)

                Text("开始于 \(Self.timeFormatter.string(from: activeSession.createdAt))")
                    .font(.caption2)
                    .foregroundStyle(WatchTheme.textMuted)
            }

            Button("结束这段状态") {
                connectivityManager.endSession(recordID: activeSession.id, endedAt: Date())
            }
            .buttonStyle(.borderedProminent)
            .tint(WatchTheme.teal)

            Text("可以继续补一个打点")
                .font(.caption2)
                .foregroundStyle(WatchTheme.textMuted)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WatchTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(WatchTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var modePickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("记录方式")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(WatchTheme.textMuted)

            HStack(spacing: 8) {
                ForEach(EntryMode.allCases) { mode in
                    Button {
                        entryMode = mode
                    } label: {
                        Text(mode.rawValue)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(entryMode == mode ? WatchTheme.background : WatchTheme.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(entryMode == mode ? WatchTheme.accent : WatchTheme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(WatchTheme.border, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var moodGridSection: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
            ForEach(MoodRecord.Mood.allCases) { mood in
                Button {
                    handleMoodTap(mood)
                } label: {
                    VStack(spacing: 4) {
                        Text(mood.emoji)
                            .font(.title3)
                        Text(mood.rawValue)
                            .font(.caption2.weight(.semibold))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 62)
                    .padding(.vertical, 8)
                    .background(WatchTheme.elevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(WatchTheme.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func handleMoodTap(_ mood: MoodRecord.Mood) {
        if connectivityManager.activeSession != nil {
            connectivityManager.sendPointRecord(
                MoodRecord(mood: mood, createdAt: Date(), isTracking: false)
            )
            return
        }

        switch entryMode {
        case .point:
            connectivityManager.sendPointRecord(
                MoodRecord(mood: mood, createdAt: Date(), isTracking: false)
            )
        case .session:
            connectivityManager.startSession(
                MoodRecord.active(mood: mood, createdAt: Date())
            )
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

#Preview {
    WatchHomeView()
}
