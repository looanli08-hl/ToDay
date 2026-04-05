import SwiftUI

struct TodayScreen: View {
    @ObservedObject var viewModel: TodayViewModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // Date Header
                dateHeader

                // Stats Row
                if !viewModel.stats.isEmpty {
                    statsRow
                }

                // AI Summary Card
                if let summary = viewModel.aiSummary {
                    aiSummaryCard(summary)
                }

                // Loading / Error / Empty / Timeline
                if viewModel.isLoading && !viewModel.entries.isEmpty {
                    // Background refresh — show existing timeline
                    timelineSection
                } else if viewModel.isLoading {
                    loadingCard
                } else if let error = viewModel.errorMessage {
                    errorCard(error)
                } else if viewModel.entries.isEmpty {
                    emptyCard
                } else {
                    timelineSection
                }

                // Pattern Insight
                if let insight = viewModel.patternInsight {
                    patternCard(insight)
                }

                Spacer(minLength: 100)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.md)
        }
        .background(AppColor.background)
        .safeAreaInset(edge: .bottom) {
            bottomActionBar
        }
        .sheet(item: $viewModel.selectedEvent) { event in
            eventDetailSheet(event)
        }
        .sheet(isPresented: $viewModel.showQuickRecord) {
            QuickRecordSheet(
                isPresented: $viewModel.showQuickRecord,
                onSave: { note in
                    viewModel.saveMemo(note)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Date Header

    private var dateHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text("今日画卷")
                .heroStyle()

            Text(formattedDate)
                .font(AppFont.small())
                .foregroundStyle(AppColor.labelTertiary)
                .tracking(1.4)
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy · MM · dd EEE"
        return formatter.string(from: viewModel.currentDate)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: AppSpacing.xs) {
            ForEach(viewModel.stats.prefix(4)) { stat in
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(stat.value)
                        .font(.system(size: 23, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppColor.label)
                    Text(stat.title)
                        .font(AppFont.small())
                        .foregroundStyle(AppColor.labelTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, AppSpacing.md)
                .padding(.horizontal, AppSpacing.md)
                .background(AppColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                .appShadow(.subtle)
            }
        }
    }

    // MARK: - AI Summary Card

    private func aiSummaryCard(_ summary: String) -> some View {
        ContentCard(background: AppColor.echo.opacity(0.08)) {
            Text("Echo 今日洞察")
                .font(AppFont.smallBold())
                .foregroundStyle(AppColor.echo)

            Text(summary)
                .font(AppFont.bodyRegular())
                .foregroundStyle(AppColor.label)
                .lineSpacing(4)
        }
    }

    // MARK: - Timeline Section

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("今日时间轴")
                .font(AppFont.heading())
                .foregroundStyle(AppColor.label)

            Text("从凌晨到夜里，一天的起伏与留白。")
                .font(AppFont.small())
                .foregroundStyle(AppColor.labelTertiary)

            DayScrollView(
                entries: viewModel.entries,
                date: viewModel.currentDate,
                isToday: viewModel.isToday,
                onEventTap: { event in
                    viewModel.selectedEvent = event
                }
            )
        }
    }

    // MARK: - Loading Card

    private var loadingCard: some View {
        ContentCard {
            HStack(spacing: AppSpacing.sm) {
                ProgressView()
                    .tint(AppColor.accent)
                Text("正在整理今天的脉络...")
                    .font(AppFont.bodyRegular())
                    .foregroundStyle(AppColor.labelSecondary)
            }
        }
    }

    // MARK: - Error Card

    private func errorCard(_ message: String) -> some View {
        ContentCard {
            Text("时间线暂时不可用")
                .font(AppFont.body())
                .foregroundStyle(AppColor.label)

            Text(message)
                .font(AppFont.small())
                .foregroundStyle(AppColor.labelTertiary)

            HStack(spacing: AppSpacing.sm) {
                Button("重新整理") {
                    Task { await viewModel.refresh() }
                }
                .font(AppFont.body())
                .foregroundStyle(AppColor.accent)

                Button("前往设置") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(AppFont.bodyRegular())
                .foregroundStyle(AppColor.labelTertiary)
            }
        }
    }

    // MARK: - Empty Card

    private var emptyCard: some View {
        ContentCard {
            VStack(spacing: AppSpacing.md) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 40))
                    .foregroundStyle(AppColor.labelQuaternary)

                Text("等待数据中")
                    .font(AppFont.body())
                    .foregroundStyle(AppColor.label)

                Text("带着手机出门走走，位置和活动数据会自动填入时间轴。你也可以先用下方的「记录此刻」手动打点。")
                    .font(AppFont.bodyRegular())
                    .foregroundStyle(AppColor.labelSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Button("刷新") {
                    Task { await viewModel.refresh() }
                }
                .font(AppFont.body())
                .foregroundStyle(AppColor.accent)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Pattern Card

    private func patternCard(_ insight: String) -> some View {
        ContentCard(background: AppColor.surfaceElevated) {
            Text("Echo 发现了一个规律")
                .font(AppFont.smallBold())
                .foregroundStyle(AppColor.echo)

            Text(insight)
                .font(AppFont.bodyRegular())
                .foregroundStyle(AppColor.label)
                .lineSpacing(4)
        }
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        HStack(spacing: AppSpacing.sm) {
            if viewModel.hasActiveSession {
                Button {
                    viewModel.openQuickRecordComposer()
                } label: {
                    Text("补一个打点")
                        .font(AppFont.body())
                        .foregroundStyle(AppColor.label)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(AppColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .appShadow(.subtle)
                }

                Button {
                    viewModel.finishActiveRecord()
                } label: {
                    Text("结束这段状态")
                        .font(AppFont.body())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(AppColor.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            } else {
                Button {
                    viewModel.openQuickRecordComposer()
                } label: {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "square.and.pencil")
                        Text("记录此刻")
                    }
                    .font(AppFont.body())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(AppColor.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(
            Color(UIColor.systemGroupedBackground).opacity(0.96)
        )
        .appShadow(.elevated)
    }

    // MARK: - Event Detail Sheet

    @ViewBuilder
    private func eventDetailSheet(_ event: InferredEvent) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    // Header
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(event.kindBadgeTitle)
                            .font(AppFont.smallBold())
                            .foregroundStyle(AppColor.color(for: event.kind))

                        Text(event.resolvedName)
                            .font(AppFont.heading())
                            .foregroundStyle(AppColor.label)

                        Text(event.scrollDurationText)
                            .font(AppFont.small())
                            .foregroundStyle(AppColor.labelTertiary)
                    }
                    .padding(AppSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColor.color(for: event.kind).opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))

                    // Subtitle / detail
                    if let subtitle = event.subtitle {
                        Text(subtitle)
                            .font(AppFont.bodyRegular())
                            .foregroundStyle(AppColor.labelSecondary)
                            .lineSpacing(4)
                    }

                    // Time range
                    ContentCard {
                        HStack {
                            Text("时间")
                                .font(AppFont.small())
                                .foregroundStyle(AppColor.labelTertiary)
                            Spacer()
                            Text(timeRangeText(event))
                                .font(AppFont.small())
                                .foregroundStyle(AppColor.label)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.md)
            }
            .background(AppColor.background)
            .navigationTitle("片段详情")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func timeRangeText(_ event: InferredEvent) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: event.startDate)) - \(formatter.string(from: event.endDate))"
    }
}
