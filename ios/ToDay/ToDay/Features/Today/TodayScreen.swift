import SwiftUI

private enum TodayPalette {
    static let background = Color(red: 0.980, green: 0.980, blue: 0.973)
    static let card = Color.white
    static let ink = Color(red: 0.102, green: 0.102, blue: 0.102)
    static let inkSoft = Color(red: 0.239, green: 0.239, blue: 0.239)
    static let inkMuted = Color(red: 0.541, green: 0.541, blue: 0.541)
    static let inkFaint = Color(red: 0.722, green: 0.722, blue: 0.722)
    static let border = Color(red: 0.886, green: 0.878, blue: 0.863)
    static let cream = Color(red: 0.961, green: 0.953, blue: 0.937)
    static let accent = Color(red: 0.831, green: 0.647, blue: 0.455)
    static let accentSoft = Color(red: 0.831, green: 0.647, blue: 0.455).opacity(0.13)
    static let teal = Color(red: 0.357, green: 0.604, blue: 0.545)
    static let tealSoft = Color(red: 0.357, green: 0.604, blue: 0.545).opacity(0.10)
    static let rose = Color(red: 0.788, green: 0.482, blue: 0.482)
    static let roseSoft = Color(red: 0.788, green: 0.482, blue: 0.482).opacity(0.10)
    static let blue = Color(red: 0.482, green: 0.612, blue: 0.788)
    static let blueSoft = Color(red: 0.482, green: 0.612, blue: 0.788).opacity(0.10)
    static let lavender = Color(red: 0.608, green: 0.557, blue: 0.769)
    static let lavenderSoft = Color(red: 0.608, green: 0.557, blue: 0.769).opacity(0.10)
}

private struct OverviewStat: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let tint: Color
    let background: Color
}

private struct RiverPoint: Identifiable {
    let index: Int
    let x: CGFloat
    let centerY: CGFloat
    let topY: CGFloat
    let bottomY: CGFloat
    let intensity: CGFloat
    let color: Color
    let progress: Double

    var id: Int { index }
}

struct TodayScreen: View {
    @ObservedObject var viewModel: TodayViewModel
    @ObservedObject var monetizationViewModel: MonetizationViewModel

    let onOpenHistory: () -> Void
    let onOpenPro: () -> Void

    @State private var expandedEntryID: UUID?

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
                        riverSection(timeline)
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
            .background(TodayPalette.background)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                quickRecordButton
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .background(TodayPalette.background.opacity(0.92))
            }
            .sheet(isPresented: $viewModel.showQuickRecord) {
                QuickRecordSheet { record in
                    viewModel.addMoodRecord(record)
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
                        .foregroundStyle(TodayPalette.inkMuted)
                        .tracking(1.4)

                    Text("今日画卷")
                        .font(.system(size: 33, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(TodayPalette.ink)
                }

                Spacer()

                Button {
                    Task {
                        await viewModel.load(forceReload: true)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(TodayPalette.inkSoft)
                        .frame(width: 42, height: 42)
                        .background(TodayPalette.card)
                        .overlay(
                            Circle()
                                .stroke(TodayPalette.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            Text(viewModel.timeline?.summary ?? "先把今天铺成一张可回看的画卷，再决定哪些片段值得长期留下。")
                .font(.system(size: 14, weight: .regular, design: .default))
                .foregroundStyle(TodayPalette.inkMuted)
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

    @ViewBuilder
    private var summarySection: some View {
        if let summary = viewModel.insightSummary {
            ContentCard {
                EyebrowLabel("TODAY SUMMARY")

                Text("今日自动总结")
                    .font(.system(size: 23, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(TodayPalette.ink)

                Text(summary.headline)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TodayPalette.inkSoft)

                Text(summary.narrative)
                    .font(.system(size: 14))
                    .foregroundStyle(TodayPalette.inkMuted)
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
            ContentCard(background: TodayPalette.tealSoft.opacity(0.65)) {
                EyebrowLabel("WEEKLY RHYTHM")

                Text("最近 7 天")
                    .font(.system(size: 23, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(TodayPalette.ink)

                Text(weeklyInsight.headline)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TodayPalette.inkSoft)

                Text(weeklyInsight.narrative)
                    .font(.system(size: 14))
                    .foregroundStyle(TodayPalette.inkMuted)
                    .lineSpacing(4)

                FlexibleBadgeRow(items: weeklyInsight.badges, tone: .teal)
            }
        } else {
            ContentCard {
                EyebrowLabel("PRO PREVIEW")

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("时间会自己长出趋势")
                            .font(.system(size: 23, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(TodayPalette.ink)

                        Text("先让免费版把今天讲清楚，Pro 再负责把最近 7 天的节奏、波峰和回看价值整理出来。")
                            .font(.system(size: 14))
                            .foregroundStyle(TodayPalette.inkMuted)
                            .lineSpacing(4)
                    }

                    Spacer()

                    Text("会员")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(TodayPalette.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(TodayPalette.accentSoft)
                        .clipShape(Capsule())
                }

                Button(action: onOpenPro) {
                    Text("前往会员页")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(TodayPalette.teal)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func riverSection(_ timeline: DayTimeline) -> some View {
        ContentCard {
            EyebrowLabel("TIME RIVER")

            Text("时间之河")
                .font(.system(size: 23, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(TodayPalette.ink)

            Text("把一天里的起伏、停顿和推进压成一条河流，先看波形，再回到具体片段。")
                .font(.system(size: 14))
                .foregroundStyle(TodayPalette.inkMuted)
                .lineSpacing(4)

            TimeRiverView(entries: timeline.entries)
                .frame(height: 82)

            HStack {
                ForEach(["00:00", "06:00", "12:00", "18:00", "24:00"], id: \.self) { label in
                    Text(label)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(TodayPalette.inkFaint)

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
                .foregroundStyle(TodayPalette.ink)

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
    private var recentDaysSection: some View {
        if !viewModel.recentDigests.isEmpty {
            ContentCard {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        EyebrowLabel("RECENT DAYS")

                        Text("最近记录")
                            .font(.system(size: 23, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(TodayPalette.ink)
                    }

                    Spacer()

                    Button(action: onOpenHistory) {
                        Text("查看全部")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(TodayPalette.inkSoft)
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
            viewModel.showQuickRecord = true
        } label: {
            Label("记录此刻", systemImage: "plus.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.vertical, 15)
                .frame(maxWidth: .infinity)
                .background(TodayPalette.accent)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: TodayPalette.accent.opacity(0.22), radius: 18, x: 0, y: 10)
        }
    }

    private var loadingCard: some View {
        ContentCard {
            EyebrowLabel("LOADING")
            ProgressView()
            Text("正在整理今天的时间之河...")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(TodayPalette.ink)
            Text("这里会根据当前环境读取模拟数据或真实 HealthKit 数据。")
                .font(.system(size: 14))
                .foregroundStyle(TodayPalette.inkMuted)
        }
    }

    private func errorCard(message: String) -> some View {
        ContentCard {
            EyebrowLabel("UNAVAILABLE")
            Text("时间线暂时不可用")
                .font(.system(size: 24, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(TodayPalette.ink)

            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(TodayPalette.inkMuted)

            Button("重新整理") {
                Task {
                    await viewModel.load(forceReload: true)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(TodayPalette.teal)
        }
    }

    private var overviewStats: [OverviewStat] {
        let entryCount = viewModel.timeline?.entries.count ?? 0
        let sourceText = viewModel.timeline?.source.badgeTitle ?? "本地"

        return [
            OverviewStat(label: "片段", value: "\(entryCount)", tint: TodayPalette.blue, background: TodayPalette.blueSoft),
            OverviewStat(label: "记录", value: "\(viewModel.todayManualRecordCount)", tint: TodayPalette.teal, background: TodayPalette.tealSoft),
            OverviewStat(label: "备注", value: "\(viewModel.todayNoteCount)", tint: TodayPalette.rose, background: TodayPalette.roseSoft),
            OverviewStat(label: "来源", value: sourceText, tint: TodayPalette.accent, background: TodayPalette.accentSoft)
        ]
    }

    private var dateHeader: String {
        let formatter = DateFormatter()
        formatter.locale = chineseLocale
        formatter.dateFormat = "yyyy · MM · dd EEE"
        return formatter.string(from: viewModel.timeline?.date ?? Date())
    }
}

private struct ContentCard<Content: View>: View {
    let background: Color
    @ViewBuilder let content: Content

    init(
        background: Color = TodayPalette.card,
        @ViewBuilder content: () -> Content
    ) {
        self.background = background
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(TodayPalette.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct EyebrowLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(TodayPalette.inkMuted)
            .tracking(2.4)
    }
}

private struct OverviewStatCard: View {
    let stat: OverviewStat

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(stat.label)
                .font(.system(size: 11))
                .foregroundStyle(TodayPalette.inkMuted)

            Text(stat.value)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(stat.tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .frame(width: 92, alignment: .leading)
        .background(stat.background)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(TodayPalette.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct TimeRiverView: View {
    let entries: [TimelineEntry]

    var body: some View {
        GeometryReader { proxy in
            let points = riverPoints(in: proxy.size)

            ZStack {
                riverBody(points: points)
                    .fill(riverGradient(points: points))

                riverLine(points: points)
                    .stroke(riverGradient(points: points), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))

                ForEach(points.filter { $0.intensity >= 0.82 }) { point in
                    Circle()
                        .fill(point.color)
                        .frame(width: 6, height: 6)
                        .position(x: point.x, y: point.centerY)
                }
            }
        }
    }

    private func riverPoints(in size: CGSize) -> [RiverPoint] {
        guard !entries.isEmpty else { return [] }

        let width = max(size.width, 1)
        let centerY = size.height / 2

        return entries.enumerated().map { index, entry in
            let progress = Double(entry.startMinuteOfDay) / Double(24 * 60)
            let x = width * CGFloat(progress)
            let wave = CGFloat(sin(Double(index) * 0.7) * 3.0)
            let intensity = entry.kind.riverIntensity
            let amplitude = 8 + (intensity * 18)

            return RiverPoint(
                index: index,
                x: x,
                centerY: centerY - (intensity * 10) + wave,
                topY: centerY - amplitude + wave,
                bottomY: centerY + amplitude - (wave * 0.4),
                intensity: intensity,
                color: entry.kind.riverColor,
                progress: progress
            )
        }
    }

    private func riverBody(points: [RiverPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }

        path.move(to: CGPoint(x: first.x, y: first.topY))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: point.x, y: point.topY))
        }

        for point in points.reversed() {
            path.addLine(to: CGPoint(x: point.x, y: point.bottomY))
        }

        path.closeSubpath()
        return path
    }

    private func riverLine(points: [RiverPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }

        path.move(to: CGPoint(x: first.x, y: first.centerY))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: point.x, y: point.centerY))
        }
        return path
    }

    private func riverGradient(points: [RiverPoint]) -> LinearGradient {
        let stops = points.map { point in
            Gradient.Stop(
                color: point.color.opacity(0.45 + (point.intensity * 0.35)),
                location: point.progress
            )
        }

        return LinearGradient(
            gradient: Gradient(stops: stops),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

private struct TimelineStreamRow: View {
    let entry: TimelineEntry
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    Text(entry.timeRange)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(TodayPalette.inkMuted)
                        .frame(width: 74, alignment: .leading)

                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(entry.kind.riverBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(entry.kind.riverColor.opacity(isExpanded ? 0.22 : 0), lineWidth: 1.4)
                        )
                        .frame(width: 30, height: 30)
                        .overlay {
                            Text(entry.kind.icon)
                                .font(.system(size: 14))
                        }

                    Text(entry.title)
                        .font(.system(size: 15, weight: isExpanded ? .semibold : .regular))
                        .foregroundStyle(TodayPalette.inkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    IntensityBar(progress: entry.kind.riverIntensity, color: entry.kind.riverColor)
                        .frame(width: 48)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(TodayPalette.inkMuted)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }

                if isExpanded {
                    Text(entry.detail)
                        .font(.system(size: 14))
                        .foregroundStyle(TodayPalette.inkMuted)
                        .lineSpacing(4)
                        .padding(.leading, 84)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .background(isExpanded ? entry.kind.riverBackground : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct IntensityBar: View {
    let progress: CGFloat
    let color: Color

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(TodayPalette.border)
                .frame(height: 3)

            Capsule()
                .fill(color)
                .frame(width: max(10, 48 * progress), height: 3)
        }
    }
}

private struct RecentDayCard: View {
    let digest: RecentDayDigest
    let locale: Locale

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(digest.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(TodayPalette.inkSoft)

                    Spacer()

                    Text(digest.date.formatted(.dateTime.month(.abbreviated).day().locale(locale)))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(TodayPalette.inkMuted)
                }

                Text(digest.detail)
                    .font(.system(size: 13))
                    .foregroundStyle(TodayPalette.inkMuted)

                if let notePreview = digest.notePreview {
                    Text("“\(notePreview)”")
                        .font(.system(size: 12))
                        .foregroundStyle(TodayPalette.inkSoft)
                        .lineLimit(1)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TodayPalette.cream.opacity(0.55))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(TodayPalette.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var color: Color {
        switch digest.mood {
        case .happy:
            return TodayPalette.accent
        case .calm:
            return TodayPalette.teal
        case .tired:
            return TodayPalette.blue
        case .irritated:
            return TodayPalette.rose
        case .focused:
            return TodayPalette.teal
        case .zoning:
            return TodayPalette.inkFaint
        case .none:
            return TodayPalette.inkFaint
        }
    }
}

private struct FlexibleBadgeRow: View {
    enum Tone {
        case accent
        case teal
    }

    let items: [String]
    let tone: Tone

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
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(TodayPalette.inkSoft)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(background)
            .clipShape(Capsule())
    }

    private var background: Color {
        switch tone {
        case .accent:
            return TodayPalette.accentSoft
        case .teal:
            return TodayPalette.tealSoft
        }
    }
}

private extension TimelineEntry.Kind {
    var riverColor: Color {
        switch self {
        case .sleep:
            return TodayPalette.blue
        case .move:
            return TodayPalette.rose
        case .focus:
            return TodayPalette.teal
        case .pause:
            return TodayPalette.inkFaint
        case .mood:
            return TodayPalette.accent
        }
    }

    var riverBackground: Color {
        switch self {
        case .sleep:
            return TodayPalette.blueSoft
        case .move:
            return TodayPalette.roseSoft
        case .focus:
            return TodayPalette.tealSoft
        case .pause:
            return TodayPalette.cream
        case .mood:
            return TodayPalette.accentSoft
        }
    }

    var riverIntensity: CGFloat {
        switch self {
        case .sleep:
            return 0.24
        case .move:
            return 0.68
        case .focus:
            return 0.90
        case .pause:
            return 0.20
        case .mood:
            return 0.48
        }
    }

    var icon: String {
        switch self {
        case .sleep:
            return "🌙"
        case .move:
            return "🚶"
        case .focus:
            return "⌘"
        case .pause:
            return "☁️"
        case .mood:
            return "✦"
        }
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
