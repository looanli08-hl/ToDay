import SwiftUI

struct TodayScreen: View {
    @ObservedObject var viewModel: TodayViewModel

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    // Date Strip (always visible)
                    dateStrip

                    // Date Header
                    dateHeader

                    // AI Analysis Block (between header and timeline)
                    if viewModel.aiSummary != nil || viewModel.patternInsight != nil {
                        if let summary = viewModel.aiSummary {
                            aiSummaryCard(summary)
                        }
                        if let insight = viewModel.patternInsight {
                            patternCard(insight)
                        }
                    }

                    // Loading / Error / Empty / Timeline
                    if viewModel.isLoading && !viewModel.entries.isEmpty {
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

                    Spacer(minLength: viewModel.isToday ? 100 : AppSpacing.xxl)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.md)
            }
            .background(AppColor.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showCalendar = true
                    } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppColor.accent)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if viewModel.isToday {
                    bottomActionBar
                }
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
            .sheet(isPresented: $viewModel.showCalendar) {
                calendarSheet
            }
            .task {
                await viewModel.load()
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
    }

    // MARK: - Date Strip

    private var dateStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.xs) {
                    ForEach(viewModel.recentDateRange, id: \.self) { date in
                        dateCell(date)
                            .id(date)
                    }
                }
                .padding(.horizontal, AppSpacing.xxs)
            }
            .onAppear {
                proxy.scrollTo(
                    calendar.startOfDay(for: viewModel.selectedDate),
                    anchor: .center
                )
            }
            .onChange(of: viewModel.selectedDate) { _, newDate in
                withAnimation {
                    proxy.scrollTo(
                        calendar.startOfDay(for: newDate),
                        anchor: .center
                    )
                }
            }
        }
    }

    private func dateCell(_ date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: viewModel.selectedDate)
        let isTodayDate = calendar.isDateInToday(date)

        return VStack(spacing: AppSpacing.xxs) {
            if isTodayDate {
                Text("今")
                    .font(AppFont.small())
                    .foregroundStyle(isSelected ? .white : AppColor.accent)
            } else {
                Text("\(calendar.component(.day, from: date))")
                    .font(AppFont.small())
                    .foregroundStyle(isSelected ? .white : AppColor.label)
            }
        }
        .frame(width: 40, height: 40)
        .background(
            isSelected
                ? AppColor.accent
                : AppColor.surface
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture {
            viewModel.selectDate(date)
        }
    }

    // MARK: - Date Header

    private var dateHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(headerTitle)
                .heroStyle()

            Text(formattedDate)
                .font(AppFont.small())
                .foregroundStyle(AppColor.labelTertiary)
                .tracking(1.4)
        }
    }

    private var headerTitle: String {
        if viewModel.isToday {
            return "今日画卷"
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "MM月dd日"
            return formatter.string(from: viewModel.currentDate)
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy · MM · dd EEE"
        return formatter.string(from: viewModel.currentDate)
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
            Text(viewModel.isToday ? "今日时间轴" : "时间轴")
                .font(AppFont.heading())
                .foregroundStyle(AppColor.label)

            Text(viewModel.isToday
                 ? "从凌晨到夜里，一天的起伏与留白。"
                 : "这一天的生活画卷。")
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
                Text("正在整理脉络...")
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

                Text(viewModel.isToday ? "等待数据中" : "这一天还没有记录")
                    .font(AppFont.body())
                    .foregroundStyle(AppColor.label)

                Text(viewModel.isToday
                     ? "带着手机出门走走，位置和活动数据会自动填入时间轴。你也可以先用下方的「记录此刻」手动打点。"
                     : "戴上手表或用快门记录生活碎片")
                    .font(AppFont.bodyRegular())
                    .foregroundStyle(AppColor.labelSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                if viewModel.isToday {
                    Button("刷新") {
                        Task { await viewModel.refresh() }
                    }
                    .font(AppFont.body())
                    .foregroundStyle(AppColor.accent)
                }
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

    // MARK: - Calendar Sheet

    private var calendarSheet: some View {
        NavigationStack {
            DatePicker(
                "选择日期",
                selection: $viewModel.selectedDate,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(AppColor.accent)
            .padding()
            .background(AppColor.background)
            .navigationTitle("选择日期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("回到今日") {
                        viewModel.returnToToday()
                    }
                    .font(AppFont.bodyRegular())
                    .foregroundStyle(AppColor.accent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        viewModel.showCalendar = false
                        Task { await viewModel.loadTimeline(for: viewModel.selectedDate) }
                    }
                    .font(AppFont.body())
                    .foregroundStyle(AppColor.accent)
                }
            }
        }
        .presentationDetents([.large])
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
