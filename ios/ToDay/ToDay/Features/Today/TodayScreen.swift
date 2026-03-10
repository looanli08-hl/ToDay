import SwiftUI

struct TodayScreen: View {
    @ObservedObject var viewModel: TodayViewModel
    @ObservedObject var monetizationViewModel: MonetizationViewModel

    let onOpenHistory: () -> Void
    let onOpenPro: () -> Void

    @State private var expandedEntryID: String?

    private let chineseLocale = Locale(identifier: "zh_CN")

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
                        timelineSection(timeline)
                    }

                    summarySection
                    weeklySpotlightSection
                    recentDaysSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(TodayTheme.background)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                quickRecordButton
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .background(TodayTheme.background.opacity(0.92))
            }
            .sheet(isPresented: $viewModel.showQuickRecord) {
                QuickRecordSheet { record in
                    viewModel.startMoodRecord(record)
                }
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

    private func timelineSection(_ timeline: DayTimeline) -> some View {
        ContentCard {
            EyebrowLabel("TIMELINE")

            Text("时间线")
                .font(.system(size: 23, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(TodayTheme.ink)

            VStack(spacing: 8) {
                ForEach(timeline.entries) { entry in
                    TimelineStreamRow(
                        entry: entry,
                        isExpanded: expandedEntryID == entry.id
                    ) {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                            expandedEntryID = expandedEntryID == entry.id ? nil : entry.id
                        }
                    }
                }
            }
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
        if monetizationViewModel.isProUnlocked, let weeklyInsight = viewModel.weeklyInsight {
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
        } else {
            ContentCard {
                EyebrowLabel("PRO PREVIEW")

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("把生活记录变成可付费的陪伴")
                            .font(.system(size: 23, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(TodayTheme.ink)

                        Text("免费版先把今天讲清楚，Pro 再负责把最近 7 天的节奏、波峰和回看价值整理出来。")
                            .font(.system(size: 14))
                            .foregroundStyle(TodayTheme.inkMuted)
                            .lineSpacing(4)
                    }

                    Spacer()

                    Text("会员")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(TodayTheme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(TodayTheme.accentSoft)
                        .clipShape(Capsule())
                }

                Button(action: onOpenPro) {
                    Text("前往会员页")
                        .font(.system(size: 14, weight: .semibold))
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

    private var quickRecordButton: some View {
        Button {
            viewModel.handleQuickRecordTap()
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
            .background(viewModel.activeRecord == nil ? TodayTheme.accent : TodayTheme.teal)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(
                color: (viewModel.activeRecord == nil ? TodayTheme.accent : TodayTheme.teal).opacity(0.22),
                radius: 18,
                x: 0,
                y: 10
            )
        }
        .buttonStyle(.plain)
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
        ContentCard {
            EyebrowLabel("UNAVAILABLE")
            Text("时间线暂时不可用")
                .font(.system(size: 24, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(TodayTheme.ink)

            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(TodayTheme.inkMuted)

            Button("重新整理") {
                Task {
                    await viewModel.load(forceReload: true)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(TodayTheme.teal)
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
        let formatter = DateFormatter()
        formatter.locale = chineseLocale
        formatter.dateFormat = "yyyy · MM · dd EEE"
        return formatter.string(from: viewModel.timeline?.date ?? Date())
    }
}

#Preview {
    AppRootScreen(
        todayViewModel: TodayViewModel(
            provider: MockTimelineDataProvider(),
            recordStore: UserDefaultsMoodRecordStore(
                defaults: UserDefaults(suiteName: "ToDayPreviewStore") ?? .standard,
                key: "preview.manualRecords"
            )
        ),
        monetizationViewModel: MonetizationViewModel(
            defaults: UserDefaults(suiteName: "ToDayPreviewStore") ?? .standard,
            key: "preview.pro"
        )
    )
}
