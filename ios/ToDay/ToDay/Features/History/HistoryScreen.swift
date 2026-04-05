import SwiftUI

struct HistoryScreen: View {
    @ObservedObject var viewModel: TodayViewModel
    @StateObject private var activityProvider = CurrentActivityProvider()

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var showCalendar = false
    @State private var selectedTimeline: DayTimeline?
    @State private var isLoadingSelectedDay = false
    @State private var selectedEvent: InferredEvent?
    @State private var annotatingEvent: InferredEvent?
    @State private var visibleMonth: Date = {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? cal.startOfDay(for: Date())
    }()

    private let calendar = Calendar.current
    private let chineseLocale = Locale(identifier: "zh_CN")

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 0. Recording status indicator
                recordingStatusBar

                // 0.5. Real-time activity status
                if !activityProvider.statusText.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: activityProvider.statusIcon)
                            .font(.caption2)
                            .foregroundStyle(AppColor.labelTertiary)
                        Text(activityProvider.statusText)
                            .font(.caption)
                            .foregroundStyle(AppColor.labelSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
                    .background(AppColor.surface)
                }

                // 1. Date strip (sticky at top)
                dateStripSection

                Divider()

                // 2. Selected day content (scrollable)
                ScrollView {
                    selectedDayContent
                }
                .background(AppColor.background)
            }
            .navigationTitle("回看")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showCalendar) {
                calendarSheet
            }
            .sheet(item: $selectedEvent) { event in
                EventDetailView(event: event) {
                    selectedEvent = nil
                }
            }
            .sheet(item: $annotatingEvent) { event in
                EventAnnotationSheet(event: event) { title in
                    viewModel.annotateEvent(event, title: title)
                    annotatingEvent = nil
                    // Reload the selected day to reflect annotation
                    Task { await loadSelectedDay() }
                }
                .presentationDetents([.medium, .large])
            }
            .task(id: selectedDate) {
                await loadSelectedDay()
            }
            .onAppear {
                activityProvider.refresh()
            }
            .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
                activityProvider.refresh()
            }
        }
    }

    // MARK: - Recording Status

    @State private var pulseAnimation = false

    private var recordingStatusBar: some View {
        let isToday = calendar.isDateInToday(selectedDate)
        let eventCount = viewModel.timeline?.entries.filter { $0.kind != .mood }.count ?? 0
        let lastRecorded = BackgroundTaskManager.lastRecordedDate

        return HStack(spacing: 10) {
            // Pulse dot
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
                .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                .opacity(pulseAnimation ? 0.6 : 1.0)
                .animation(
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                    value: pulseAnimation
                )

            if isToday {
                Text("正在记录")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.green)

                Text("·")
                    .foregroundStyle(.tertiary)

                Text("今天已记录 \(eventCount) 个时刻")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else if let lastRecorded {
                Text("自动记录中")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.green)

                Text("·")
                    .foregroundStyle(.tertiary)

                Text("上次记录 \(relativeTimeText(from: lastRecorded))")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                Text("等待首次记录")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(AppColor.surface)
        .onAppear { pulseAnimation = true }
    }

    private func relativeTimeText(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            return "\(Int(interval / 60)) 分钟前"
        } else if interval < 86400 {
            return "\(Int(interval / 3600)) 小时前"
        } else {
            return "\(Int(interval / 86400)) 天前"
        }
    }

    // MARK: - Date Strip

    private var dateStripSection: some View {
        HStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(last30Days, id: \.self) { date in
                            dateCell(for: date)
                                .id(date)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .onAppear {
                    proxy.scrollTo(selectedDate, anchor: .center)
                }
                .onChange(of: selectedDate) { _, newValue in
                    withAnimation {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }

            // Expand button
            Button {
                showCalendar = true
            } label: {
                VStack(spacing: 2) {
                    Text("展开")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .background(AppColor.surface)
    }

    private func dateCell(for date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let dayNumber = calendar.component(.day, from: date)
        let hasData = hasDayData(for: date)

        return Button {
            selectedDate = calendar.startOfDay(for: date)
        } label: {
            VStack(spacing: 6) {
                Text(isToday ? "今" : "\(dayNumber)")
                    .font(.system(size: 16, weight: isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? .white : AppColor.label)
                    .frame(width: 40, height: 40)
                    .background(isSelected ? AppColor.accent : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Circle()
                    .fill(hasData ? Color.accentColor : .clear)
                    .frame(width: 5, height: 5)
            }
        }
        .buttonStyle(.plain)
    }

    private var last30Days: [Date] {
        let today = calendar.startOfDay(for: Date())
        return (0..<30).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
    }

    // MARK: - Selected Day Content

    private var selectedDayContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Date header
            Text(selectedDateFormatted)
                .font(.system(size: 23, weight: .regular, design: .serif))
                .italic()
                .padding(.horizontal, 20)
                .padding(.top, 20)

            if let timeline = selectedTimeline {
                // Metrics section
                sectionLabel("数据概览")
                metricsSection(for: timeline)

                // Insight section
                insightSection(for: timeline)

                // Full timeline
                sectionLabel("当天时间轴")

                DayScrollView(
                    timeline: timeline,
                    onEventTap: { event in
                        selectedEvent = event
                    },
                    onBlankTap: { event in
                        annotatingEvent = event
                    },
                    showsCurrentTimeNeedle: calendar.isDateInToday(selectedDate)
                )
                .padding(.horizontal, 20)
            } else if isLoadingSelectedDay {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(40)
            } else {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 40))
                        .foregroundStyle(.quaternary)

                    Text("这一天还没有记录")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text("戴上手表或用快门记录生活碎片")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(60)
            }
        }
        .padding(.bottom, 100) // space for tab bar
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AppColor.labelTertiary)
            .tracking(1.5)
            .textCase(.uppercase)
            .padding(.horizontal, 20)
    }

    // MARK: - Insight Section

    private func insightSection(for timeline: DayTimeline) -> some View {
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
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColor.label)
                }

                Text(insightText(for: timeline))
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
        .padding(.horizontal, 20)
    }

    private func insightText(for timeline: DayTimeline) -> String {
        let eventCount = timeline.entries.count
        let activeMinutes = Int(timeline.entries.reduce(0.0) { total, event in
            switch event.kind {
            case .workout, .activeWalk, .commute:
                return total + event.duration / 60
            default:
                return total
            }
        })
        let sleepHrs = sleepHours(in: timeline)

        var parts: [String] = []
        if eventCount > 0 {
            parts.append("今天共记录了 \(eventCount) 个时刻")
        }
        if activeMinutes > 0 {
            parts.append("活动时间约 \(activeMinutes) 分钟")
        }
        if sleepHrs > 0 {
            parts.append(String(format: "睡眠约 %.1f 小时", sleepHrs))
        }
        return parts.isEmpty ? "今天还没有记录" : parts.joined(separator: "，") + "。"
    }

    private var selectedDateFormatted: String {
        let formatter = DateFormatter()
        formatter.locale = chineseLocale
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: selectedDate)
    }

    // MARK: - Metrics Section

    private func metricsSection(for timeline: DayTimeline) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            metricCard(
                icon: "flame.fill",
                iconColor: .orange,
                label: "运动",
                value: exerciseMinutes(timeline),
                detail: "活动时间"
            )
            metricCard(
                icon: "moon.fill",
                iconColor: AppColor.sleep,
                label: "睡眠",
                value: sleepHoursFormatted(timeline),
                detail: "总睡眠"
            )
            metricCard(
                icon: "figure.walk",
                iconColor: AppColor.walk,
                label: "步数",
                value: stepCountFormatted(timeline),
                detail: "今日步行"
            )
            metricCard(
                icon: "camera.aperture",
                iconColor: AppColor.shutter,
                label: "快门",
                value: shutterCount(timeline),
                detail: "捕捉记录"
            )
        }
        .padding(.horizontal, 20)
    }

    private func metricCard(icon: String, iconColor: Color, label: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconColor)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColor.labelSecondary)
            }

            Text(value)
                .font(.system(size: 23, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColor.label)

            Text(detail)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(AppColor.labelTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        .appShadow(.subtle)
    }

    // MARK: - Event Row

    private func eventRow(event: InferredEvent) -> some View {
        HStack(spacing: 12) {
            // Left color bar
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(event.cardStroke)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.resolvedName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(eventTimeText(event))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(event.scrollDurationText)
                .font(.subheadline.monospacedDigit().bold())
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        .shadow(color: Color(red: 0.4, green: 0.3, blue: 0.2).opacity(0.06), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 20)
    }

    // MARK: - Calendar Sheet

    private var calendarSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Month navigation header
                    HStack {
                        Button {
                            shiftMonth(by: -1)
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Text(monthTitle)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Spacer()

                        Button {
                            shiftMonth(by: 1)
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(canAdvanceMonth ? .secondary : .quaternary)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canAdvanceMonth)
                    }
                    .padding(.horizontal, 20)

                    // Weekday headers
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7),
                        spacing: 8
                    ) {
                        ForEach(weekdayTitles, id: \.self) { title in
                            Text(title)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity)
                        }

                        ForEach(Array(monthGrid.enumerated()), id: \.offset) { _, day in
                            if let day {
                                calendarDayCell(for: day)
                            } else {
                                Color.clear
                                    .frame(height: 50)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 16)
            }
            .navigationTitle("选择日期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { showCalendar = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("回到今日") {
                        selectedDate = calendar.startOfDay(for: Date())
                        showCalendar = false
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func calendarDayCell(for date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let dayNumber = calendar.component(.day, from: date)
        let hasData = hasDayData(for: date)
        let isInFuture = date > Date()

        return Button {
            selectedDate = calendar.startOfDay(for: date)
            showCalendar = false
        } label: {
            VStack(spacing: 4) {
                Text("\(dayNumber)")
                    .font(.body)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(
                        isSelected ? Color.white :
                            (isInFuture ? Color(UIColor.quaternaryLabel) : Color.primary)
                    )
                    .frame(width: 36, height: 36)
                    .background(isSelected ? Color.accentColor : (isToday ? Color.accentColor.opacity(0.15) : Color.clear))
                    .clipShape(Circle())

                Circle()
                    .fill(hasData ? Color.accentColor : .clear)
                    .frame(width: 6, height: 6)
            }
            .frame(height: 50)
        }
        .buttonStyle(.plain)
        .disabled(isInFuture)
    }

    // MARK: - Metric Helpers

    private func exerciseMinutes(_ timeline: DayTimeline) -> String {
        let minutes = timeline.entries.reduce(0.0) { partial, event in
            switch event.kind {
            case .workout, .activeWalk, .commute, .userAnnotated:
                return partial + max(event.duration / 60, 1)
            default:
                return partial
            }
        }
        let rounded = max(Int(minutes.rounded()), 0)
        if rounded >= 60 {
            let hours = rounded / 60
            let remainder = rounded % 60
            return remainder == 0 ? "\(hours)h" : "\(hours)h\(remainder)m"
        }
        return "\(rounded)m"
    }

    private func sleepHoursFormatted(_ timeline: DayTimeline) -> String {
        let hours = sleepHours(in: timeline)
        guard hours > 0 else { return "--" }
        return String(format: "%.1fh", hours)
    }

    private func stepCountFormatted(_ timeline: DayTimeline) -> String {
        let total = totalSteps(in: timeline)
        guard total > 0 else { return "--" }
        if total >= 10000 {
            return String(format: "%.1f万", Double(total) / 10000)
        }
        return "\(total)"
    }

    private func shutterCount(_ timeline: DayTimeline) -> String {
        let count = timeline.entries.reduce(0) { partial, event in
            partial + (event.associatedMetrics?.photos?.count ?? 0)
        }
        guard count > 0 else { return "--" }
        return "\(count)"
    }

    private func eventTimeText(_ event: InferredEvent) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: event.startDate)) - \(formatter.string(from: event.endDate))"
    }

    // MARK: - Existing Metric Computation

    private func sleepHours(in timeline: DayTimeline) -> Double {
        timeline.entries
            .filter { $0.kind == .sleep }
            .reduce(0.0) { $0 + $1.duration / 3600 }
    }

    private func totalSteps(in timeline: DayTimeline?) -> Int {
        guard let timeline else { return 0 }
        return timeline.entries.reduce(0) { partial, event in
            partial + (event.associatedMetrics?.stepCount ?? 0)
        }
    }

    // MARK: - Data Helpers

    private func hasDayData(for date: Date) -> Bool {
        let day = calendar.startOfDay(for: date)
        if viewModel.historyDigests.first(where: { calendar.isDate($0.date, inSameDayAs: day) }) != nil {
            return true
        }
        return false
    }

    // MARK: - Data Loading

    private func loadSelectedDay() async {
        isLoadingSelectedDay = true
        defer { isLoadingSelectedDay = false }
        selectedTimeline = await viewModel.loadTimeline(for: selectedDate)
    }

    // MARK: - Calendar Helpers

    private var monthGrid: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: visibleMonth) else { return [] }
        let firstDay = monthInterval.start
        let numberOfDays = calendar.range(of: .day, in: .month, for: firstDay)?.count ?? 0
        let weekdayOffset = (calendar.component(.weekday, from: firstDay) - calendar.firstWeekday + 7) % 7

        var result = Array<Date?>(repeating: nil, count: weekdayOffset)
        result.append(contentsOf: (0..<numberOfDays).compactMap {
            calendar.date(byAdding: .day, value: $0, to: firstDay)
        })

        while result.count % 7 != 0 {
            result.append(nil)
        }

        return result
    }

    private var monthTitle: String {
        visibleMonth.formatted(.dateTime.year().month(.wide).locale(chineseLocale))
    }

    private var weekdayTitles: [String] {
        ["日", "一", "二", "三", "四", "五", "六"]
    }

    private var canAdvanceMonth: Bool {
        visibleMonth < calendar.todayMonthAnchor
    }

    private func shiftMonth(by value: Int) {
        guard let month = calendar.date(byAdding: .month, value: value, to: visibleMonth) else { return }
        if month <= calendar.todayMonthAnchor {
            visibleMonth = month
        }
    }
}

// MARK: - Badge Row (used by HistoryDayDetailScreen)

struct HistoryBadgeRow: View {
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
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(AppColor.surface.opacity(0.72))
            .clipShape(Capsule())
    }
}

// MARK: - Calendar Extensions

private extension Calendar {
    var todayMonthAnchor: Date {
        startOfMonth(for: Date())
    }

    func startOfMonth(for value: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: value)) ?? startOfDay(for: value)
    }

    func enumeratedDays(in interval: DateInterval) -> [Date] {
        var days: [Date] = []
        var cursor = interval.start

        while cursor < interval.end {
            days.append(cursor)
            guard let next = date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        return days
    }
}
