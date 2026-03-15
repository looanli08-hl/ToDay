import SwiftUI

struct WatchHomeView: View {
    @ObservedObject var viewModel: WatchViewModel

    @State private var isShowingMood = false
    @State private var annotationContext: AnnotationContext?

    var body: some View {
        TabView {
            homePage
                .tag(0)

            WatchMiniTimelineView(
                events: viewModel.timelineEvents,
                selectedEventID: viewModel.currentEventIdentifier,
                summary: viewModel.timelineSummary,
                dataSource: viewModel.dataSource
            ) { event in
                annotationContext = AnnotationContext(id: event.id, title: event.resolvedName, event: event)
            }
            .tag(1)
        }
        .tabViewStyle(.verticalPage)
        .background(WatchTheme.background.ignoresSafeArea())
        .sheet(item: $annotationContext) { context in
            QuickAnnotationView(contextTitle: context.title) { title in
                if let event = context.event {
                    viewModel.annotate(event, title: title)
                } else {
                    viewModel.annotateCurrentEvent(title: title)
                }
            }
        }
        .sheet(isPresented: $isShowingMood) {
            QuickMoodView { mood in
                viewModel.recordPoint(mood: mood)
            }
        }
    }

    private var homePage: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                currentEventCard

                HStack(spacing: 10) {
                    actionButton(
                        title: "标注",
                        systemImage: "pencil",
                        tint: WatchTheme.accent
                    ) {
                        annotationContext = AnnotationContext(
                            id: viewModel.currentEventIdentifier ?? UUID(),
                            title: viewModel.currentEvent?.eventName ?? "快捷标注",
                            event: nil
                        )
                    }
                    .disabled(!viewModel.canAnnotate)
                    .opacity(viewModel.canAnnotate ? 1 : 0.45)

                    actionButton(
                        title: "心情",
                        systemImage: "face.smiling",
                        tint: WatchTheme.teal
                    ) {
                        isShowingMood = true
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(WatchTheme.background.ignoresSafeArea())
    }

    private var currentEventCard: some View {
        Group {
            if let activeSession = viewModel.activeSession {
                sessionCard(for: activeSession)
            } else if let currentEvent = viewModel.currentEvent {
                eventCard(for: currentEvent)
            } else {
                waitingCard
            }
        }
        .frame(maxWidth: .infinity, minHeight: 160)
    }

    private func eventCard(for event: CurrentEventSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(WatchTheme.badgeText(for: event.eventKind))
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(WatchTheme.eventAccent(for: event.eventKind))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(WatchTheme.badgeFill(for: event.eventKind))
                .clipShape(Capsule())

            Text(event.eventName)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(WatchTheme.text)
                .lineLimit(3)

            TimelineView(.periodic(from: event.startDate, by: 60)) { context in
                Text(durationText(since: event.startDate, now: context.date))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(WatchTheme.textMuted)
            }

            Spacer(minLength: 0)

            HStack(alignment: .center, spacing: 10) {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(WatchTheme.rose)

                    Text(viewModel.currentHeartRate.map { "\($0) 次/分" } ?? "—")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(WatchTheme.text)
                }

                Spacer(minLength: 8)

                Text("\(Self.timeFormatter.string(from: event.startDate)) 开始")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(WatchTheme.textMuted)
            }
        }
        .padding(18)
        .background(WatchTheme.eventCardBackground(for: event.eventKind))
        .shadow(color: WatchTheme.eventGlow(for: event.eventKind), radius: 18, y: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(WatchTheme.borderStrong, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func sessionCard(for session: MoodRecord) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Text("状态")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(WatchTheme.moodAccent(for: session.mood))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(WatchTheme.moodAccent(for: session.mood).opacity(0.16))
                    .clipShape(Capsule())

                Circle()
                    .fill(WatchTheme.moodAccent(for: session.mood))
                    .frame(width: 6, height: 6)
            }

            Text("\(session.mood.rawValue)中")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(WatchTheme.text)
                .lineLimit(2)

            TimelineView(.periodic(from: session.createdAt, by: 60)) { context in
                Text(durationText(since: session.createdAt, now: context.date))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(WatchTheme.textMuted)
            }

            Spacer(minLength: 0)

            HStack(alignment: .center, spacing: 10) {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(WatchTheme.rose)

                    Text(viewModel.currentHeartRate.map { "\($0) 次/分" } ?? "—")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(WatchTheme.text)
                }

                Spacer(minLength: 8)

                Text("\(Self.timeFormatter.string(from: session.createdAt)) 开始")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(WatchTheme.textMuted)
            }
        }
        .padding(18)
        .background(WatchTheme.moodCardBackground(for: session.mood))
        .shadow(color: WatchTheme.moodAccent(for: session.mood).opacity(0.24), radius: 18, y: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(WatchTheme.borderStrong, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var waitingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("戴着手表，开始你的一天")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(WatchTheme.text)

            Text("活动一会儿后，这里会出现你正在做的事。")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(WatchTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(WatchTheme.eventCardBackground(for: "quietTime"))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(WatchTheme.borderStrong, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func actionButton(
        title: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .bold))

                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .foregroundStyle(WatchTheme.text)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(
                LinearGradient(
                    colors: [tint.opacity(0.34), WatchTheme.surface],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(tint.opacity(0.35), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
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

        return "刚刚开始"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

private struct AnnotationContext: Identifiable {
    let id: UUID
    let title: String
    let event: WatchTimelineEventSnapshot?
}

#Preview {
    WatchHomeView(viewModel: WatchViewModel())
}
