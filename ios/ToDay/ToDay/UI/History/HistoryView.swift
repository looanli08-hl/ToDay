import SwiftUI

struct HistoryView: View {
    let timelineProvider: any TimelineDataProviding
    let moodRecordManager: MoodRecordManager
    let shutterManager: ShutterManager
    let annotationStore: AnnotationStore

    @State private var selectedDate: Date = Date()
    @State private var timeline: DayTimeline?
    @State private var isLoading = false
    @State private var showCalendar = false
    @State private var selectedEvent: InferredEvent?

    private let calendar = Calendar.current
    private let recentDays = 30

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    // Date Strip
                    dateStrip

                    // Content
                    if isLoading {
                        ProgressView()
                            .tint(AppColor.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.xxl)
                    } else if let timeline, !timeline.entries.isEmpty {
                        // Stats
                        if !timeline.stats.isEmpty {
                            statsGrid(timeline.stats)
                        }

                        // Timeline
                        DayScrollView(
                            entries: timeline.entries,
                            date: selectedDate,
                            isToday: calendar.isDateInToday(selectedDate),
                            onEventTap: { event in
                                selectedEvent = event
                            }
                        )
                    } else {
                        emptyState
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.md)
            }
            .background(AppColor.background)
            .navigationTitle("回看")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("展开") {
                        showCalendar = true
                    }
                    .font(AppFont.bodyRegular())
                    .foregroundStyle(AppColor.accent)
                }
            }
            .sheet(isPresented: $showCalendar) {
                calendarSheet
            }
            .sheet(item: $selectedEvent) { event in
                eventDetailSheet(event)
            }
        }
        .task {
            await loadTimeline(for: selectedDate)
        }
    }

    // MARK: - Date Strip

    private var dateStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.xs) {
                    ForEach(recentDateRange, id: \.self) { date in
                        dateCell(date)
                            .id(date)
                    }
                }
                .padding(.horizontal, AppSpacing.xxs)
            }
            .onAppear {
                proxy.scrollTo(selectedDate, anchor: .center)
            }
            .onChange(of: selectedDate) { _, newDate in
                withAnimation {
                    proxy.scrollTo(newDate, anchor: .center)
                }
            }
        }
    }

    private func dateCell(_ date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)

        return VStack(spacing: AppSpacing.xxs) {
            if isToday {
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
            selectedDate = date
            Task { await loadTimeline(for: date) }
        }
    }

    private var recentDateRange: [Date] {
        (0..<recentDays).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: Date()))
        }.reversed()
    }

    // MARK: - Stats Grid

    private func statsGrid(_ stats: [TimelineStat]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
            ForEach(stats.prefix(4)) { stat in
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(stat.value)
                        .font(.system(size: 23, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColor.label)
                    Text(stat.title)
                        .font(AppFont.small())
                        .foregroundStyle(AppColor.labelTertiary)
                }
                .padding(AppSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                .appShadow(.subtle)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 40))
                .foregroundStyle(AppColor.labelQuaternary)

            Text("这一天还没有记录")
                .font(AppFont.body())
                .foregroundStyle(AppColor.label)

            Text("戴上手表或用快门记录生活碎片")
                .font(AppFont.bodyRegular())
                .foregroundStyle(AppColor.labelSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xxl)
    }

    // MARK: - Calendar Sheet

    private var calendarSheet: some View {
        NavigationStack {
            DatePicker(
                "选择日期",
                selection: $selectedDate,
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
                        selectedDate = Date()
                        showCalendar = false
                        Task { await loadTimeline(for: selectedDate) }
                    }
                    .font(AppFont.bodyRegular())
                    .foregroundStyle(AppColor.accent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        showCalendar = false
                        Task { await loadTimeline(for: selectedDate) }
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

                    if let subtitle = event.subtitle {
                        Text(subtitle)
                            .font(AppFont.bodyRegular())
                            .foregroundStyle(AppColor.labelSecondary)
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

    // MARK: - Data Loading

    private func loadTimeline(for date: Date) async {
        isLoading = true
        do {
            let base = try await timelineProvider.loadTimeline(for: date)
            let moodEvents = moodRecordManager.records(on: date)
                .map { $0.toInferredEvent(referenceDate: Date(), calendar: calendar) }
            let shutterEvents = shutterManager.inferredEvents(on: date)
            let annotations = annotationStore.annotations(on: date).map(\.asEvent)

            var allEntries = base.entries + moodEvents + shutterEvents + annotations
            allEntries.sort { $0.startDate < $1.startDate }

            timeline = DayTimeline(
                date: base.date,
                summary: base.summary,
                source: base.source,
                stats: base.stats,
                entries: allEntries
            )
        } catch {
            timeline = nil
        }
        isLoading = false
    }
}
