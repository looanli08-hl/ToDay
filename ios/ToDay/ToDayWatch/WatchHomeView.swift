import SwiftUI

struct WatchHomeView: View {
    private enum EntryMode: String, CaseIterable, Identifiable {
        case point = "打点"
        case session = "开始一段"

        var id: String { rawValue }
    }

    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    @State private var entryMode: EntryMode = .point
    @State private var showSuccess = false
    @State private var successMood: MoodRecord.Mood?

    var body: some View {
        ZStack {
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

            if showSuccess, let successMood {
                successOverlay(for: successMood)
                    .transition(.scale.combined(with: .opacity))
            }
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

                TimelineView(.periodic(from: Date(), by: 60)) { context in
                    Text(durationText(since: activeSession.createdAt, now: context.date))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(WatchTheme.textMuted)
                }

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

    private func successOverlay(for mood: MoodRecord.Mood) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(WatchTheme.teal)

            Text(mood.emoji)
                .font(.system(size: 30))
        }
        .frame(maxWidth: 110, minHeight: 110)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(WatchTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
    }

    private func handleMoodTap(_ mood: MoodRecord.Mood) {
        if connectivityManager.activeSession != nil {
            connectivityManager.sendPointRecord(
                MoodRecord(mood: mood, createdAt: Date(), isTracking: false)
            )
            showPointSuccess(for: mood)
            return
        }

        switch entryMode {
        case .point:
            connectivityManager.sendPointRecord(
                MoodRecord(mood: mood, createdAt: Date(), isTracking: false)
            )
            showPointSuccess(for: mood)
        case .session:
            connectivityManager.startSession(
                MoodRecord.active(mood: mood, createdAt: Date())
            )
        }
    }

    private func showPointSuccess(for mood: MoodRecord.Mood) {
        successMood = mood
        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            showSuccess = true
        }

        Task {
            try? await Task.sleep(for: .seconds(0.8))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    showSuccess = false
                }
            }
        }
    }

    private func durationText(since startDate: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(startDate)))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            if minutes > 0 {
                return "已持续 \(hours) 小时 \(minutes) 分钟"
            }
            return "已持续 \(hours) 小时"
        }

        if minutes > 0 {
            return "已持续 \(minutes) 分钟"
        }

        return "刚刚开始"
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
