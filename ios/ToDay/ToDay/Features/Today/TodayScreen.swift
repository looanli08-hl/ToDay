import SwiftData
import SwiftUI
import UIKit

struct TodayScreen: View {
    @ObservedObject var viewModel: TodayViewModel
    @State private var selectedEvent: InferredEvent?
    @State private var annotatingEvent: InferredEvent?
    @State private var sharePayload: ScrollSharePayload?

    let onOpenHistory: () -> Void

    private let chineseLocale = Locale(identifier: "zh_CN")
    private static let dateHeaderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy · MM · dd EEE"
        return formatter
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerSection
                    overviewSection

                    if viewModel.isLoading && viewModel.timeline == nil {
                        loadingCard
                    } else if let message = viewModel.errorMessage, viewModel.timeline == nil {
                        errorCard(message: message)
                    } else if let timeline = viewModel.timeline {
                        if timeline.entries.isEmpty {
                            emptyStateCard
                        } else {
                            signatureSection(timeline)
                            scrollCanvasSection(timeline)
                        }
                    }

                    summarySection
                    weeklySpotlightSection
                    recentDaysSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task {
                    await viewModel.load(forceReload: true)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                bottomActionBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .background(Color(UIColor.systemGroupedBackground).opacity(0.92))
            }
            .sheet(isPresented: $viewModel.showQuickRecord) {
                QuickRecordSheet(mode: viewModel.quickRecordMode) { record in
                    viewModel.startMoodRecord(record)
                }
            }
            .sheet(isPresented: $viewModel.showScreenTimeInput) {
                ScreenTimeInputView(
                    dateKey: viewModel.currentDateKey(),
                    existingRecord: viewModel.existingScreenTimeRecord()
                ) { record in
                    viewModel.saveScreenTimeRecord(record)
                }
            }
            .sheet(item: $selectedEvent) { event in
                EventDetailView(event: event) {
                    selectedEvent = nil
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(150))
                        annotatingEvent = event
                    }
                }
            }
            .sheet(item: $annotatingEvent) { event in
                AnnotationSheet(event: event) { title in
                    viewModel.annotateEvent(event, title: title)
                }
            }
            .sheet(item: $sharePayload) { payload in
                ScrollShareSheet(image: payload.image)
            }
            .task {
                await viewModel.loadIfNeeded()
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(dateHeader)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color(UIColor.tertiaryLabel))
                        .tracking(1.4)

                    Text("今日画卷")
                        .font(.system(size: 33, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(.primary)
                }

                Spacer()

                HStack(spacing: 10) {
                    Button {
                        viewModel.openQuickRecordComposer()
                    } label: {
                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 42, height: 42)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .overlay(
                                Circle()
                                    .stroke(Color(UIColor.separator), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        shareCurrentScroll()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 42, height: 42)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .overlay(
                                Circle()
                                    .stroke(Color(UIColor.separator), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.timeline == nil)
                    .opacity(viewModel.timeline == nil ? 0.45 : 1)

                    Button {
                        Task {
                            await viewModel.load(forceReload: true)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 42, height: 42)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .overlay(
                                Circle()
                                    .stroke(Color(UIColor.separator), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(viewModel.timeline?.summary ?? "先把今天铺成一张可回看的画卷，再决定哪些片段值得长期留下。")
                .font(.system(size: 14))
                .foregroundStyle(Color(UIColor.tertiaryLabel))
                .lineSpacing(3)
        }
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(overviewStats) { stat in
                        OverviewStatCard(stat: stat)
                    }
                }
                .padding(.vertical, 2)
            }

            HStack(spacing: 10) {
                Button {
                    viewModel.showScreenTimeInput = true
                } label: {
                    Label("屏幕时间", systemImage: "iphone.gen3")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TodayTheme.blue)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(TodayTheme.blueSoft)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
    }

    private func signatureSection(_ timeline: DayTimeline) -> some View {
        ContentCard {
            EyebrowLabel("今日脉络")

            Text("今日脉络")
                .font(.system(size: 23, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(.primary)

            Text("把一天里的起伏、停顿和推进压成一条流线，先看今天的流向，再回到具体片段。")
                .font(.system(size: 14))
                .foregroundStyle(Color(UIColor.tertiaryLabel))
                .lineSpacing(4)

            TodayFlowSignatureView(entries: timeline.entries)
                .frame(height: 82)

            HStack {
                ForEach(["00:00", "06:00", "12:00", "18:00", "24:00"], id: \.self) { label in
                    Text(label)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color(UIColor.quaternaryLabel))

                    if label != "24:00" {
                        Spacer()
                    }
                }
            }
        }
    }

    private func scrollCanvasSection(_ timeline: DayTimeline) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            EyebrowLabel("今日时间轴")

            Text("今日时间轴")
                .font(.system(size: 23, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(.primary)

            Text("从凌晨到夜里，一天的起伏与留白。")
                .font(.system(size: 14))
                .foregroundStyle(Color(UIColor.tertiaryLabel))
                .lineSpacing(4)

            DayScrollView(
                timeline: timeline,
                onEventTap: { event in
                    selectedEvent = event
                },
                onBlankTap: { event in
                    annotatingEvent = event
                }
            )
        }
    }

    private var emptyStateCard: some View {
        ContentCard {
            VStack(spacing: 16) {
                Image(systemName: "applewatch.and.arrow.forward")
                    .font(.system(size: 36))
                    .foregroundStyle(Color(UIColor.quaternaryLabel))

                Text("等待数据中")
                    .font(.system(size: 20, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(.primary)

                Text("戴上 Apple Watch 活动一会儿，心率、步数和运动数据会自动填入时间轴。你也可以先用下方的「记录此刻」手动打点。")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Button("刷新") {
                    Task {
                        await viewModel.load(forceReload: true)
                    }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(TodayTheme.teal)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var summarySection: some View {
        if let summary = viewModel.insightSummary {
            ContentCard {
                EyebrowLabel("今日总结")

                Text("今日自动总结")
                    .font(.system(size: 23, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(.primary)

                Text(summary.headline)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(summary.narrative)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
                    .lineSpacing(4)

                if !summary.badges.isEmpty {
                    FlexibleBadgeRow(items: summary.badges, tone: .accent)
                }
            }
        }
    }

    @ViewBuilder
    private var weeklySpotlightSection: some View {
        if let weeklyInsight = viewModel.weeklyInsight {
            ContentCard(background: TodayTheme.tealSoft.opacity(0.7)) {
                EyebrowLabel("七日节律")

                Text("最近 7 天")
                    .font(.system(size: 23, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(.primary)

                Text(weeklyInsight.headline)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(weeklyInsight.narrative)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
                    .lineSpacing(4)

                FlexibleBadgeRow(items: weeklyInsight.badges, tone: .teal)
            }
        }
    }

    @ViewBuilder
    private var recentDaysSection: some View {
        if !viewModel.recentDigests.isEmpty {
            ContentCard {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        EyebrowLabel("最近几天")

                        Text("最近记录")
                            .font(.system(size: 23, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(.primary)
                    }

                    Spacer()

                    Button(action: onOpenHistory) {
                        Text("查看全部")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                VStack(spacing: 10) {
                    ForEach(viewModel.recentDigests.prefix(3)) { digest in
                        RecentDayCard(digest: digest, locale: chineseLocale)
                    }
                }
            }
        }
    }

    private var bottomActionBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let activeSessionTitle = viewModel.activeSessionTitle,
               let activeSessionDetail = viewModel.activeSessionDetail {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("进行中")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(TodayTheme.teal)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(TodayTheme.tealSoft)
                            .clipShape(Capsule())

                        Text(activeSessionTitle)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }

                    Text(activeSessionDetail)
                        .font(.system(size: 13))
                        .foregroundStyle(Color(UIColor.tertiaryLabel))
                        .lineLimit(2)
                }
            }

            if viewModel.activeRecord == nil {
                Button {
                    viewModel.openQuickRecordComposer()
                } label: {
                    VStack(spacing: 4) {
                        Label(viewModel.quickRecordButtonTitle, systemImage: viewModel.quickRecordButtonSystemImage)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)

                        if let caption = viewModel.quickRecordButtonCaption {
                            Text(caption)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.84))
                        }
                    }
                    .padding(.vertical, 15)
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 10) {
                    Button {
                        viewModel.openPointComposer()
                    } label: {
                        Label("补一个打点", systemImage: "plus.circle")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color(UIColor.separator), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        viewModel.finishActiveMoodRecord()
                    } label: {
                        Label("结束这段状态", systemImage: "stop.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(TodayTheme.teal)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(Color(UIColor.tertiarySystemGroupedBackground).opacity(0.94))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(UIColor.separator), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.primary.opacity(0.06), radius: 18, x: 0, y: 8)
    }

    private var loadingCard: some View {
        ContentCard {
            EyebrowLabel("整理中")
            ProgressView()
            Text("正在整理今天的脉络...")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)
            Text("这里会根据当前环境读取模拟数据或真实 HealthKit 数据。")
                .font(.system(size: 14))
                .foregroundStyle(Color(UIColor.tertiaryLabel))
        }
    }

    private func errorCard(message: String) -> some View {
        let showsSettingsButton = message.contains("授权")

        return ContentCard {
            EyebrowLabel("暂不可用")
            Text("时间线暂时不可用")
                .font(.system(size: 24, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(.primary)

            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Color(UIColor.tertiaryLabel))

            HStack(spacing: 12) {
                Button("重新整理") {
                    Task {
                        await viewModel.load(forceReload: true)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(TodayTheme.teal)

                if showsSettingsButton {
                    Button("前往设置") {
                        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(settingsURL)
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                }
            }
        }
    }

    private var overviewStats: [OverviewStat] {
        let entryCount = viewModel.timeline?.entries.count ?? 0
        let sourceText = viewModel.timeline?.source.badgeTitle ?? "本地"

        return [
            OverviewStat(label: "片段", value: "\(entryCount)", tint: TodayTheme.blue, background: TodayTheme.blueSoft),
            OverviewStat(label: "记录", value: "\(viewModel.todayManualRecordCount)", tint: TodayTheme.teal, background: TodayTheme.tealSoft),
            OverviewStat(label: "快门", value: "\(viewModel.todayShutterCount())", tint: TodayTheme.scrollGold, background: TodayTheme.scrollGold.opacity(0.12)),
            OverviewStat(label: "来源", value: sourceText, tint: Color.accentColor, background: Color.accentColor.opacity(0.12))
        ]
    }

    private var dateHeader: String {
        Self.dateHeaderFormatter.string(from: viewModel.timeline?.date ?? Date())
    }

    private func shareCurrentScroll() {
        guard let timeline = viewModel.timeline else { return }
        sharePayload = ScrollSharePayload(image: ScrollShareService.renderScrollAsImage(timeline: timeline))
    }
}

private struct ScrollSharePayload: Identifiable {
    let id = UUID()
    let image: UIImage
}

#Preview {
    TodayScreen(
        viewModel: TodayViewModel(
            provider: MockTimelineDataProvider(),
            recordStore: UserDefaultsMoodRecordStore(
                defaults: UserDefaults(suiteName: "ToDayPreviewStore") ?? .standard,
                key: "preview.manualRecords"
            ),
            modelContainer: previewModelContainer
        ),
        onOpenHistory: {}
    )
}

@MainActor
private let previewModelContainer: ModelContainer = {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try! ModelContainer(
        for: MoodRecordEntity.self,
        DayTimelineEntity.self,
        ShutterRecordEntity.self,
        SpendingRecordEntity.self,
        configurations: configuration
    )
}()
