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
                        signatureSection(timeline)
                        scrollCanvasSection(timeline)
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
            .background(TodayTheme.background)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                bottomActionBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .background(TodayTheme.background.opacity(0.92))
            }
            .sheet(isPresented: $viewModel.showQuickRecord) {
                QuickRecordSheet(mode: viewModel.quickRecordMode) { record in
                    viewModel.startMoodRecord(record)
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
                        .foregroundStyle(TodayTheme.inkMuted)
                        .tracking(1.4)

                    Text("今日画卷")
                        .font(.system(size: 33, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(TodayTheme.ink)
                }

                Spacer()

                HStack(spacing: 10) {
                    Button {
                        viewModel.openQuickRecordComposer()
                    } label: {
                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(TodayTheme.accent)
                            .frame(width: 42, height: 42)
                            .background(TodayTheme.card)
                            .overlay(
                                Circle()
                                    .stroke(TodayTheme.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        shareCurrentScroll()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(TodayTheme.inkSoft)
                            .frame(width: 42, height: 42)
                            .background(TodayTheme.card)
                            .overlay(
                                Circle()
                                    .stroke(TodayTheme.border, lineWidth: 1)
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
                            .foregroundStyle(TodayTheme.inkSoft)
                            .frame(width: 42, height: 42)
                            .background(TodayTheme.card)
                            .overlay(
                                Circle()
                                    .stroke(TodayTheme.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(viewModel.timeline?.summary ?? "先把今天铺成一张可回看的画卷，再决定哪些片段值得长期留下。")
                .font(.system(size: 14))
                .foregroundStyle(TodayTheme.inkMuted)
                .lineSpacing(3)
        }
    }

    private var overviewSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(overviewStats) { stat in
                    OverviewStatCard(stat: stat)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func signatureSection(_ timeline: DayTimeline) -> some View {
        ContentCard {
            EyebrowLabel("DAILY SIGNATURE")

            Text("今日脉络")
                .font(.system(size: 23, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(TodayTheme.ink)

            Text("把一天里的起伏、停顿和推进压成一条流线，先看今天的流向，再回到具体片段。")
                .font(.system(size: 14))
                .foregroundStyle(TodayTheme.inkMuted)
                .lineSpacing(4)

            TodayFlowSignatureView(entries: timeline.entries)
                .frame(height: 82)

            HStack {
                ForEach(["00:00", "06:00", "12:00", "18:00", "24:00"], id: \.self) { label in
                    Text(label)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(TodayTheme.inkFaint)

                    if label != "24:00" {
                        Spacer()
                    }
                }
            }
        }
    }

    private func scrollCanvasSection(_ timeline: DayTimeline) -> some View {
        ContentCard {
            EyebrowLabel("SCROLL CANVAS")

            Text("横向长卷")
                .font(.system(size: 23, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(TodayTheme.ink)

            Text("把一天摊成一卷，从凌晨到夜里横向看清楚片段如何铺开。空白段落也会留出来，方便你之后再补标。")
                .font(.system(size: 14))
                .foregroundStyle(TodayTheme.inkMuted)
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

    @ViewBuilder
    private var summarySection: some View {
        if let summary = viewModel.insightSummary {
            ContentCard {
                EyebrowLabel("TODAY SUMMARY")

                Text("今日自动总结")
                    .font(.system(size: 23, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(TodayTheme.ink)

                Text(summary.headline)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TodayTheme.inkSoft)

                Text(summary.narrative)
                    .font(.system(size: 14))
                    .foregroundStyle(TodayTheme.inkMuted)
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
                EyebrowLabel("WEEKLY RHYTHM")

                Text("最近 7 天")
                    .font(.system(size: 23, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(TodayTheme.ink)

                Text(weeklyInsight.headline)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TodayTheme.inkSoft)

                Text(weeklyInsight.narrative)
                    .font(.system(size: 14))
                    .foregroundStyle(TodayTheme.inkMuted)
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
                        EyebrowLabel("RECENT DAYS")

                        Text("最近记录")
                            .font(.system(size: 23, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(TodayTheme.ink)
                    }

                    Spacer()

                    Button(action: onOpenHistory) {
                        Text("查看全部")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(TodayTheme.inkSoft)
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
                            .foregroundStyle(TodayTheme.inkSoft)
                    }

                    Text(activeSessionDetail)
                        .font(.system(size: 13))
                        .foregroundStyle(TodayTheme.inkMuted)
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
                    .background(TodayTheme.accent)
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
                            .foregroundStyle(TodayTheme.inkSoft)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(TodayTheme.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(TodayTheme.border, lineWidth: 1)
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
        .background(TodayTheme.elevatedCard.opacity(0.94))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(TodayTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: TodayTheme.ink.opacity(0.06), radius: 18, x: 0, y: 8)
    }

    private var loadingCard: some View {
        ContentCard {
            EyebrowLabel("LOADING")
            ProgressView()
            Text("正在整理今天的脉络...")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(TodayTheme.ink)
            Text("这里会根据当前环境读取模拟数据或真实 HealthKit 数据。")
                .font(.system(size: 14))
                .foregroundStyle(TodayTheme.inkMuted)
        }
    }

    private func errorCard(message: String) -> some View {
        let showsSettingsButton = message.contains("授权")

        return ContentCard {
            EyebrowLabel("UNAVAILABLE")
            Text("时间线暂时不可用")
                .font(.system(size: 24, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(TodayTheme.ink)

            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(TodayTheme.inkMuted)

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
                    .tint(TodayTheme.inkSoft)
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
            OverviewStat(label: "备注", value: "\(viewModel.todayNoteCount)", tint: TodayTheme.rose, background: TodayTheme.roseSoft),
            OverviewStat(label: "来源", value: sourceText, tint: TodayTheme.accent, background: TodayTheme.accentSoft)
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
    AppRootScreen(
        todayViewModel: TodayViewModel(
            provider: MockTimelineDataProvider(),
            recordStore: UserDefaultsMoodRecordStore(
                defaults: UserDefaults(suiteName: "ToDayPreviewStore") ?? .standard,
                key: "preview.manualRecords"
            )
        )
    )
}
