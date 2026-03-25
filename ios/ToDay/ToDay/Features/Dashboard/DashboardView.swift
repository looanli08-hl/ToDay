import SwiftData
import SwiftUI
import UIKit

struct DashboardView: View {
    @ObservedObject var todayViewModel: TodayViewModel
    let onOpenTimeline: () -> Void
    @State private var selectedEvent: InferredEvent?
    @State private var annotatingEvent: InferredEvent?

    private var dashboardVM: DashboardViewModel {
        DashboardViewModel(timeline: todayViewModel.timeline)
    }

    private let cardColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    cardGridSection
                    insightSection
                    timelinePreviewSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(TodayTheme.background)
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await todayViewModel.loadIfNeeded()
            }
            .refreshable {
                await todayViewModel.load(forceReload: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task {
                    await todayViewModel.load(forceReload: true)
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
                    todayViewModel.annotateEvent(event, title: title)
                }
            }
        }
    }

    // MARK: - Header

    private var dayOfWeekText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: dashboardVM.timeline?.date ?? Date())
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(dashboardVM.dateText)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(TodayTheme.inkMuted)
                            .tracking(1.4)

                        Text(dayOfWeekText)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(TodayTheme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(TodayTheme.accentSoft)
                            .clipShape(Capsule())
                    }

                    Text("仪表盘")
                        .font(.system(size: 33, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(TodayTheme.ink)
                }

                Spacer()

                Button {
                    Task {
                        await todayViewModel.load(forceReload: true)
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

            if todayViewModel.isLoading && todayViewModel.timeline == nil {
                Text("正在整理今天的数据...")
                    .font(.system(size: 14))
                    .foregroundStyle(TodayTheme.inkMuted)
            }

            if let errorMessage = todayViewModel.errorMessage, todayViewModel.timeline == nil {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(TodayTheme.rose)

                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(TodayTheme.inkMuted)
                        .lineLimit(2)
                }
            }
        }
    }

    // MARK: - Card Grid

    private var cardGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("今日概览")

            if todayViewModel.isLoading && todayViewModel.timeline == nil {
                cardGridPlaceholder
            } else {
                LazyVGrid(columns: cardColumns, spacing: 12) {
                    ForEach(dashboardVM.cards) { card in
                        DashboardCardView(card: card)
                    }
                }
            }
        }
    }

    private var cardGridPlaceholder: some View {
        LazyVGrid(columns: cardColumns, spacing: 12) {
            ForEach(0..<6, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(TodayTheme.elevatedCard)
                    .aspectRatio(1.0, contentMode: .fit)
                    .overlay(
                        ProgressView()
                    )
            }
        }
    }

    // MARK: - Quick Actions

    @State private var showManualTimeEntry = false

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("快速记录")

            HStack(spacing: 12) {
                // Mood recording button
                Button {
                    todayViewModel.showQuickRecord = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(TodayTheme.rose)
                            .frame(width: 36, height: 36)
                            .background(TodayTheme.roseSoft)
                            .clipShape(Circle())

                        Text("记录心情")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(TodayTheme.ink)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(TodayTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(TodayTheme.border, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)

                // Manual time period button
                Button {
                    showManualTimeEntry = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.badge.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(TodayTheme.teal)
                            .frame(width: 36, height: 36)
                            .background(TodayTheme.tealSoft)
                            .clipShape(Circle())

                        Text("添加时段")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(TodayTheme.ink)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(TodayTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(TodayTheme.border, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Insight

    @ViewBuilder
    private var insightSection: some View {
        let vm = dashboardVM
        ContentCard(background: TodayTheme.tealSoft.opacity(0.7)) {
            SectionHeader("今日洞察")

            HStack(spacing: 10) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TodayTheme.teal)
                    .frame(width: 32, height: 32)
                    .background(TodayTheme.teal.opacity(0.12))
                    .clipShape(Circle())

                Text("生活脉搏")
                    .font(.system(size: 23, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(TodayTheme.ink)
            }

            Text(vm.insightText)
                .font(.system(size: 14))
                .foregroundStyle(TodayTheme.inkMuted)
                .lineSpacing(4)
        }
    }

    // MARK: - Day Timeline (full scroll canvas)

    @ViewBuilder
    private var timelinePreviewSection: some View {
        if let timeline = todayViewModel.timeline, !timeline.entries.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        SectionHeader("时间轴回放")

                        Text("当天时间轴")
                            .font(.system(size: 23, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(TodayTheme.ink)
                    }

                    Spacer()
                }

                Text("从凌晨到夜里，把这一天重新走一遍。")
                    .font(.system(size: 13))
                    .foregroundStyle(TodayTheme.inkMuted)

                DayScrollView(
                    timeline: timeline,
                    onEventTap: { event in
                        selectedEvent = event
                    },
                    onBlankTap: { event in
                        annotatingEvent = event
                    },
                    showsCurrentTimeNeedle: true
                )
            }
        } else if todayViewModel.timeline != nil {
            ContentCard {
                VStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.system(size: 28))
                        .foregroundStyle(TodayTheme.inkFaint)

                    Text("时间线还是空的")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(TodayTheme.inkSoft)

                    Text("戴上 Apple Watch 活动一会儿，或用快门记录生活碎片。")
                        .font(.system(size: 14))
                        .foregroundStyle(TodayTheme.inkMuted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
    }
}



#Preview {
    DashboardView(
        todayViewModel: TodayViewModel(
            provider: MockTimelineDataProvider(),
            recordStore: UserDefaultsMoodRecordStore(
                defaults: UserDefaults(suiteName: "DashboardPreviewStore") ?? .standard,
                key: "preview.manualRecords"
            ),
            modelContainer: previewModelContainer
        ),
        onOpenTimeline: {}
    )
}

@MainActor
private let previewModelContainer: ModelContainer = {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try! ModelContainer(for: MoodRecordEntity.self, DayTimelineEntity.self, configurations: configuration)
}()
