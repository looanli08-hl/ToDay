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
                topBar
                currentEventCard
                signalRow

                if !previewEvents.isEmpty {
                    timelinePreviewCard
                }

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
                sessionCard(for: activeSession, currentEvent: viewModel.currentEvent)
            } else if let currentEvent = viewModel.currentEvent {
                eventCard(for: currentEvent)
            } else {
                waitingCard
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 164)
    }

    private var topBar: some View {
        HStack(alignment: .top, spacing: 10) {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                Text(Self.timeFormatter.string(from: context.date))
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(WatchTheme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .trailing, spacing: 6) {
                sourceBadge
                Text(syncStatusText)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(WatchTheme.textFaint)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }
        }
    }

    private var sourceBadge: some View {
        Label(viewModel.dataSource.label, systemImage: WatchTheme.sourceIcon(for: viewModel.dataSource))
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(WatchTheme.sourceFill(for: viewModel.dataSource))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(WatchTheme.sourceBackground(for: viewModel.dataSource))
            .clipShape(Capsule())
    }

    private func eventCard(for event: CurrentEventSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                eventIconOrb(symbolName: event.iconName, tint: WatchTheme.eventAccent(for: event.eventKind))

                VStack(alignment: .leading, spacing: 6) {
                    Text(event.eventName)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(WatchTheme.text)
                        .lineLimit(2)

                    Text(WatchTheme.badgeText(for: event.eventKind))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(WatchTheme.eventAccent(for: event.eventKind))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(WatchTheme.badgeFill(for: event.eventKind))
                        .clipShape(Capsule())
                }

                Spacer(minLength: 0)
            }

            TimelineView(.periodic(from: event.startDate, by: 60)) { context in
                VStack(alignment: .leading, spacing: 2) {
                    Text(durationText(since: event.startDate, now: context.date))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(WatchTheme.text)

                    Text(eventSecondaryLine(for: event))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(WatchTheme.textMuted)
                        .lineLimit(2)
                }
            }

            HStack(spacing: 8) {
                capsuleMeta(
                    systemImage: "clock",
                    text: "\(Self.timeFormatter.string(from: event.startDate)) 开始"
                )

                if let currentHeartRate = viewModel.currentHeartRate {
                    capsuleMeta(
                        systemImage: "heart.fill",
                        text: "\(currentHeartRate) BPM",
                        tint: WatchTheme.rose
                    )
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(WatchTheme.eventCardBackground(for: event.eventKind))
        .shadow(color: WatchTheme.eventGlow(for: event.eventKind), radius: 18, y: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(WatchTheme.borderStrong, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func sessionCard(for session: MoodRecord, currentEvent: CurrentEventSnapshot?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(WatchTheme.moodAccent(for: session.mood).opacity(0.22))
                        .frame(width: 46, height: 46)

                    Text(session.mood.emoji)
                        .font(.system(size: 26))
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("正在记录")
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
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(WatchTheme.text)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            TimelineView(.periodic(from: session.createdAt, by: 60)) { context in
                Text(durationText(since: session.createdAt, now: context.date))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(WatchTheme.text)
            }

            Text(sessionContextLine(currentEvent: currentEvent))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(WatchTheme.textMuted)
                .lineLimit(2)

            HStack(spacing: 8) {
                capsuleMeta(
                    systemImage: "iphone",
                    text: "手机状态已同步",
                    tint: WatchTheme.teal
                )

                if let currentHeartRate = viewModel.currentHeartRate {
                    capsuleMeta(
                        systemImage: "heart.fill",
                        text: "\(currentHeartRate) BPM",
                        tint: WatchTheme.rose
                    )
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(WatchTheme.moodCardBackground(for: session.mood))
        .shadow(color: WatchTheme.moodAccent(for: session.mood).opacity(0.24), radius: 18, y: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(WatchTheme.borderStrong, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var waitingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("等待数据同步")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(WatchTheme.text)

            Text("先活动一会儿，或先记一个心情，手机与手表会逐渐拼出今天。")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(WatchTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(WatchTheme.eventCardBackground(for: "quietTime"))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(WatchTheme.borderStrong, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var signalRow: some View {
        HStack(spacing: 10) {
            metricPill(
                systemImage: "heart.fill",
                title: "实时心率",
                value: viewModel.currentHeartRate.map { "\($0) BPM" } ?? "等待采样",
                tint: WatchTheme.rose
            )

            metricPill(
                systemImage: "dot.radiowaves.left.and.right",
                title: "当前来源",
                value: viewModel.dataSource.label,
                tint: WatchTheme.sourceFill(for: viewModel.dataSource)
            )
        }
    }

    private var timelinePreviewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("最近片段")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(WatchTheme.text)

                Spacer()

                Text("向下看时间线")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(WatchTheme.textFaint)
            }

            ForEach(previewEvents, id: \.id) { event in
                HStack(spacing: 8) {
                    Circle()
                        .fill(WatchTheme.eventAccent(for: event.kindRawValue))
                        .frame(width: 8, height: 8)

                    Text(event.resolvedName)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(WatchTheme.text)
                        .lineLimit(1)

                    Spacer(minLength: 6)

                    Text(eventTimeRangeLabel(event))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(WatchTheme.textFaint)
                        .lineLimit(1)
                }
            }
        }
        .padding(12)
        .background(WatchTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(WatchTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func metricPill(systemImage: String, title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(tint)

            Text(value)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(WatchTheme.text)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(WatchTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(WatchTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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

    private func eventIconOrb(symbolName: String, tint: Color) -> some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.18))
                .frame(width: 42, height: 42)

            Image(systemName: symbolName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(tint)
        }
    }

    private func capsuleMeta(systemImage: String, text: String, tint: Color = WatchTheme.textFaint) -> some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(WatchTheme.surface.opacity(0.72))
            .clipShape(Capsule())
    }

    private func eventSecondaryLine(for event: CurrentEventSnapshot) -> String {
        switch viewModel.dataSource {
        case .phone:
            return "手机刚刚同步了这段状态。"
        case .local:
            return "手机离线时，手表正用本地数据继续推理。"
        case .sessionFallback:
            return "这是你手动记录的当前状态。"
        case .waiting:
            return "活动一会儿，时间线会逐渐补全。"
        }
    }

    private func sessionContextLine(currentEvent: CurrentEventSnapshot?) -> String {
        guard let currentEvent,
              let activeSession = viewModel.activeSession,
              currentEvent.eventName != activeSession.mood.rawValue else {
            return "这段手动状态会一直同步到手机和时间轴。"
        }

        return "当前系统片段是「\(currentEvent.eventName)」，但手动状态会优先显示。"
    }

    private var previewEvents: [WatchTimelineEventSnapshot] {
        Array(viewModel.timelineEvents.prefix(3))
    }

    private func eventTimeRangeLabel(_ event: WatchTimelineEventSnapshot) -> String {
        "\(event.startDate.formatted(Self.compactTimeFormat)) - \(event.endDate.formatted(Self.compactTimeFormat))"
    }

    private var syncStatusText: String {
        guard let generatedAt = viewModel.currentTimelineSnapshot?.generatedAt else {
            return viewModel.dataSource == .waiting ? "等待第一批数据" : "同步中"
        }

        let seconds = max(0, Int(Date().timeIntervalSince(generatedAt)))
        if seconds < 90 {
            return "刚刚更新"
        }

        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes) 分钟前更新"
        }

        let hours = minutes / 60
        return "\(hours) 小时前更新"
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

    private static let compactTimeFormat: Date.FormatStyle = .dateTime
        .hour(.twoDigits(amPM: .omitted))
        .minute(.twoDigits)
}

private struct AnnotationContext: Identifiable {
    let id: UUID
    let title: String
    let event: WatchTimelineEventSnapshot?
}

#Preview {
    WatchHomeView(viewModel: WatchViewModel())
}
