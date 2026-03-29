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
                VStack(alignment: .leading, spacing: 28) {
                    headerSection
                    cardGridSection
                    insightSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
            .background(AppColor.background)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await todayViewModel.load(forceReload: true)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
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

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ToDay")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppColor.labelSecondary)
                .tracking(2)
                .textCase(.uppercase)

            Text(dashboardVM.dateText)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AppColor.label)

            if todayViewModel.isLoading && todayViewModel.timeline == nil {
                Text("正在整理今天的数据...")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }

            if let errorMessage = todayViewModel.errorMessage, todayViewModel.timeline == nil {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)

                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Card Grid

    private var cardGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日概览")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColor.labelTertiary)
                .tracking(1.5)
                .textCase(.uppercase)

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
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .fill(AppColor.surface)
                    .aspectRatio(1.0, contentMode: .fit)
                    .appShadow(.subtle)
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
            Text("快速记录")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColor.labelTertiary)
                .tracking(1.5)
                .textCase(.uppercase)

            HStack(spacing: 12) {
                Button {
                    todayViewModel.showQuickRecord = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.fill")
                            .font(.subheadline)
                            .foregroundStyle(TodayTheme.rose)

                        Text("记录心情")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(AppColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                    .appShadow(.subtle)
                }
                .buttonStyle(.plain)

                Button {
                    showManualTimeEntry = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.badge.fill")
                            .font(.subheadline)
                            .foregroundStyle(TodayTheme.teal)

                        Text("添加时段")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(AppColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                    .appShadow(.subtle)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Insight

    @ViewBuilder
    private var insightSection: some View {
        let vm = dashboardVM
        VStack(alignment: .leading, spacing: 10) {
            Text("今日洞察")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColor.labelTertiary)
                .tracking(1.5)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(TodayTheme.teal)

                    Text("生活脉搏")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppColor.label)
                }

                Text(vm.insightText)
                    .font(.system(size: 15))
                    .foregroundStyle(AppColor.labelSecondary)
                    .lineSpacing(6)
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            .appShadow(.subtle)
        }
    }

    // MARK: - Day Timeline (full scroll canvas)

    @ViewBuilder
    private var timelinePreviewSection: some View {
        if let timeline = todayViewModel.timeline, !timeline.entries.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("时间轴回放")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text("当天时间轴")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                Text("从凌晨到夜里，把这一天重新走一遍。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

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
            VStack(spacing: 12) {
                Image(systemName: "clock")
                    .font(.title)
                    .foregroundStyle(AppColor.labelQuaternary)

                Text("时间线还是空的")
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppColor.labelSecondary)

                Text("保持 ToDay 在后台运行，会自动记录你的一天。也可以用快门记录生活碎片。")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.labelTertiary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            .appShadow(.subtle)
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
