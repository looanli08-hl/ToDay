import SwiftUI

struct WatchHomeView: View {
    @StateObject private var viewModel = WatchViewModel()
    @State private var isChoosingSessionMood = false
    @State private var showSuccess = false
    @State private var successMood: MoodRecord.Mood?

    private let idleColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    private let activeColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    if let activeSession = viewModel.activeSession {
                        activeSessionSection(activeSession)
                        activePointRow(excluding: activeSession.mood)
                    } else {
                        idleSection
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
            }
            .background(WatchTheme.background)

            if showSuccess, let successMood {
                successOverlay(for: successMood)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .background(WatchTheme.background.ignoresSafeArea())
    }

    private var idleSection: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text("现在，你感觉")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(WatchTheme.textMuted)

                Text("点一下就记下")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(WatchTheme.textMuted.opacity(0.85))
            }
            .frame(maxWidth: .infinity)

            LazyVGrid(columns: idleColumns, spacing: 8) {
                ForEach(MoodRecord.Mood.allCases) { mood in
                    moodButton(mood, style: .idlePoint) {
                        recordPoint(mood)
                    }
                }
            }

            if isChoosingSessionMood {
                sessionChooserSection
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                    isChoosingSessionMood.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Text("开始一段")
                    Image(systemName: isChoosingSessionMood ? "chevron.down" : "play.fill")
                        .font(.system(size: 10, weight: .bold))
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(WatchTheme.background)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(WatchTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var sessionChooserSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("选一个状态开始")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(WatchTheme.text)

            LazyVGrid(columns: idleColumns, spacing: 8) {
                ForEach(MoodRecord.Mood.allCases) { mood in
                    moodButton(mood, style: .sessionChoice) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            isChoosingSessionMood = false
                        }
                        viewModel.startSession(mood: mood)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(WatchTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(WatchTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func activeSessionSection(_ activeSession: MoodRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(activeSession.mood.emoji) \(activeSession.mood.rawValue)中")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(WatchTheme.text)

                TimelineView(.periodic(from: Date(), by: 60)) { context in
                    Text(durationText(since: activeSession.createdAt, now: context.date))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(WatchTheme.teal)
                }

                Text("\(Self.timeFormatter.string(from: activeSession.createdAt)) 开始")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WatchTheme.textMuted)
            }

            Button {
                viewModel.endSession()
            } label: {
                HStack(spacing: 6) {
                    Text("结束这段")
                    Image(systemName: "stop.fill")
                        .font(.system(size: 10, weight: .bold))
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(WatchTheme.background)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(WatchTheme.teal)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(WatchTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(WatchTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func activePointRow(excluding currentMood: MoodRecord.Mood) -> some View {
        let moods = MoodRecord.Mood.allCases.filter { $0 != currentMood }

        return VStack(alignment: .leading, spacing: 8) {
            Text("补一个点")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(WatchTheme.textMuted)

            LazyVGrid(columns: activeColumns, spacing: 6) {
                ForEach(moods) { mood in
                    moodButton(mood, style: .activePoint) {
                        recordPoint(mood)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(WatchTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(WatchTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func moodButton(
        _ mood: MoodRecord.Mood,
        style: MoodButtonStyle,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(mood.emoji)
                .font(.system(size: style.emojiSize))
                .frame(maxWidth: .infinity, minHeight: style.minHeight)
                .background(style.backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                        .stroke(style.borderColor, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mood.rawValue)
    }

    private func successOverlay(for mood: MoodRecord.Mood) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(WatchTheme.teal)

            Text(mood.emoji)
                .font(.system(size: 30))
        }
        .frame(width: 116, height: 116)
        .background(WatchTheme.surface.opacity(0.92))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(WatchTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func recordPoint(_ mood: MoodRecord.Mood) {
        viewModel.recordPoint(mood: mood)
        showPointSuccess(for: mood)
    }

    private func showPointSuccess(for mood: MoodRecord.Mood) {
        successMood = mood
        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            showSuccess = true
        }

        Task {
            try? await Task.sleep(for: .seconds(0.8))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.18)) {
                    showSuccess = false
                }
            }
        }
    }

    private func durationText(since startDate: Date, now: Date) -> String {
        let totalMinutes = max(0, Int(now.timeIntervalSince(startDate)) / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            if minutes > 0 {
                return "已持续 \(hours) 小时 \(minutes) 分钟"
            }
            return "已持续 \(hours) 小时"
        }

        if minutes > 0 {
            return "已持续 \(minutes) 分钟"
        }

        return "已持续不到 1 分钟"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

private struct MoodButtonStyle {
    let minHeight: CGFloat
    let emojiSize: CGFloat
    let cornerRadius: CGFloat
    let backgroundColor: Color
    let borderColor: Color

    static let idlePoint = MoodButtonStyle(
        minHeight: 54,
        emojiSize: 26,
        cornerRadius: 18,
        backgroundColor: WatchTheme.elevated,
        borderColor: WatchTheme.border
    )

    static let sessionChoice = MoodButtonStyle(
        minHeight: 48,
        emojiSize: 24,
        cornerRadius: 16,
        backgroundColor: WatchTheme.accentSoft,
        borderColor: WatchTheme.accent.opacity(0.2)
    )

    static let activePoint = MoodButtonStyle(
        minHeight: 46,
        emojiSize: 22,
        cornerRadius: 14,
        backgroundColor: WatchTheme.elevated,
        borderColor: WatchTheme.border
    )
}

#Preview {
    WatchHomeView()
}
