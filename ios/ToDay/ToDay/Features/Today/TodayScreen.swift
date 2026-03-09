import SwiftUI

struct TodayScreen: View {
    @StateObject private var viewModel: TodayViewModel
    @State private var showProPreview = false
    private let chineseLocale = Locale(identifier: "zh_CN")

    init(viewModel: TodayViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroCard
                    summarySection

                    if viewModel.isLoading && viewModel.timeline == nil {
                        loadingCard
                    } else if let message = viewModel.errorMessage, viewModel.timeline == nil {
                        errorCard(message: message)
                    } else if let timeline = viewModel.timeline {
                        timelineSection(timeline)
                    }

                    recentDaysSection
                    proPreviewCard
                }
                .padding(.vertical, 20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("ToDay")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("刷新") {
                        Task {
                            await viewModel.load(forceReload: true)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    viewModel.showQuickRecord = true
                } label: {
                    Label("快速记录", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(Color(red: 0.35, green: 0.63, blue: 0.54))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .sheet(isPresented: $viewModel.showQuickRecord) {
                QuickRecordSheet { record in
                    viewModel.addMoodRecord(record)
                }
            }
            .sheet(isPresented: $showProPreview) {
                ProPreviewSheet()
            }
            .task {
                await viewModel.loadIfNeeded()
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("把今天过成一条能回看的时间线。")
                    .font(.title2.weight(.bold))

                Spacer()

                if let source = viewModel.timeline?.source {
                    Text(source.badgeTitle)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.72))
                        .clipShape(Capsule())
                }
            }

            Text(todayLabel)
                .font(.subheadline.weight(.medium))

            Text(viewModel.timeline?.summary ?? "先把记录、回看和总结体验做顺，后面再接真实数据。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let source = viewModel.timeline?.source {
                Text(source.helperText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if let timeline = viewModel.timeline {
                        ForEach(timeline.stats) { stat in
                            StatPill(title: stat.title, value: stat.value)
                        }
                    } else {
                        StatPill(title: "模式", value: "本地")
                        StatPill(title: "当前", value: "记录")
                        StatPill(title: "下一步", value: "总结")
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.90, blue: 0.82), Color(red: 0.89, green: 0.83, blue: 0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var summarySection: some View {
        if let summary = viewModel.insightSummary {
            VStack(alignment: .leading, spacing: 12) {
                Text("今日自动总结")
                    .font(.title3.weight(.semibold))

                Text(summary.headline)
                    .font(.headline)

                Text(summary.narrative)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !summary.badges.isEmpty {
                    FlexibleBadgeRow(items: summary.badges)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private func timelineSection(_ timeline: DayTimeline) -> some View {
        Text("今日时间线")
            .font(.title3.weight(.semibold))
            .padding(.horizontal, 20)

        VStack(spacing: 12) {
            ForEach(timeline.entries) { entry in
                TimelineCard(entry: entry)
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var recentDaysSection: some View {
        if !viewModel.recentDigests.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("最近 7 天")
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 20)

                VStack(spacing: 12) {
                    ForEach(viewModel.recentDigests) { digest in
                        RecentDayCard(digest: digest)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var proPreviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Pro 连续洞察")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("即将开放")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.94, green: 0.88, blue: 0.78))
                    .clipShape(Capsule())
            }

            Text("下一步的重点不是让你填更多表单，而是把最近 7 天的记录自动整理成趋势、节奏和状态变化。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                showProPreview = true
            } label: {
                Label("查看 Pro 预告", systemImage: "sparkles")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.35, green: 0.63, blue: 0.54))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 20)
    }

    private var loadingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProgressView()
            Text("正在整理今天的时间线…")
                .font(.headline)
            Text("这里会根据当前环境读取模拟数据或真实 HealthKit 数据。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 20)
    }

    private func errorCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("时间线暂时不可用")
                .font(.title2.weight(.bold))

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("重试") {
                Task {
                    await viewModel.load(forceReload: true)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 20)
    }

    private var todayLabel: String {
        Date().formatted(.dateTime.weekday(.wide).month(.wide).day().locale(chineseLocale))
    }
}

private struct TimelineCard: View {
    let entry: TimelineEntry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(entry.title)
                        .font(.headline)
                    Spacer()
                    Text(entry.timeRange)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Text(entry.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var color: Color {
        switch entry.kind {
        case .sleep:
            return Color(red: 0.43, green: 0.54, blue: 0.80)
        case .move:
            return Color(red: 0.84, green: 0.49, blue: 0.43)
        case .focus:
            return Color(red: 0.35, green: 0.63, blue: 0.54)
        case .pause:
            return Color(red: 0.74, green: 0.66, blue: 0.57)
        case .mood:
            return Color(red: 0.85, green: 0.65, blue: 0.40)
        }
    }
}

private struct RecentDayCard: View {
    let digest: RecentDayDigest

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(digest.title)
                        .font(.headline)

                    Spacer()

                    Text(digest.date.formatted(.dateTime.month(.abbreviated).day().locale(Locale(identifier: "zh_CN"))))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Text(digest.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var color: Color {
        switch digest.mood {
        case .happy:
            return Color(red: 0.96, green: 0.77, blue: 0.39)
        case .calm:
            return Color(red: 0.35, green: 0.63, blue: 0.54)
        case .tired:
            return Color(red: 0.43, green: 0.54, blue: 0.80)
        case .irritated:
            return Color(red: 0.84, green: 0.49, blue: 0.43)
        case .focused:
            return Color(red: 0.28, green: 0.54, blue: 0.47)
        case .zoning:
            return Color(red: 0.74, green: 0.66, blue: 0.57)
        case .none:
            return Color(red: 0.74, green: 0.66, blue: 0.57)
        }
    }
}

private struct StatPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct FlexibleBadgeRow: View {
    let items: [String]

    var body: some View {
        ViewThatFits(in: .vertical) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    badge(item)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    badge(item)
                }
            }
        }
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(red: 0.95, green: 0.90, blue: 0.82))
            .clipShape(Capsule())
    }
}

private struct ProPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("连续洞察 Pro")
                            .font(.title2.weight(.bold))

                        Text("ToDay 后续会把最近 7 天的记录整理成更像产品价值本身的结果，而不只是把更多输入动作堆给你。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    ProFeatureRow(
                        title: "7 天生活节奏",
                        detail: "把情绪、停顿、专注和活动放到一条连续曲线上看。"
                    )
                    ProFeatureRow(
                        title: "自动趋势总结",
                        detail: "告诉你这周更像在恢复、拉扯、推进还是飘着过。"
                    )
                    ProFeatureRow(
                        title: "更长历史回看",
                        detail: "不只看今天，还能回看最近一段时间的变化轨迹。"
                    )
                }
                .padding(20)
            }
            .navigationTitle("Pro 预告")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct ProFeatureRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

#Preview {
    TodayScreen(
        viewModel: TodayViewModel(
            provider: MockTimelineDataProvider(),
            recordStore: UserDefaultsMoodRecordStore(
                defaults: UserDefaults(suiteName: "ToDayPreviewStore") ?? .standard,
                key: "preview.manualRecords"
            )
        )
    )
}
