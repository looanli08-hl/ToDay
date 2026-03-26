import Charts
import SwiftUI

struct HistoryScreen: View {
    @ObservedObject var viewModel: TodayViewModel

    @State private var selectedPeriod: Period = .week
    @State private var visibleMonth = Calendar.current.todayMonthAnchor
    @State private var monthTimelines: [Date: DayTimeline] = [:]
    @State private var weeklyTimelines: [DayTimeline] = []
    @State private var isMonthLoading = false
    @State private var cachedTimelineDates: Set<Date> = []

    private let calendar = Calendar.current
    private let chineseLocale = Locale(identifier: "zh_CN")

    private enum Period: String, CaseIterable {
        case day = "日"
        case week = "周"
        case month = "月"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    periodPicker

                    if selectedPeriod != .day {
                        summaryCards
                    }

                    calendarSection
                }
                .padding(.vertical, AppSpacing.md)
            }
            .background(AppColor.background)
            .navigationTitle("回看")
            .task {
                await loadWeeklyInsights()
            }
            .task(id: visibleMonth) {
                await loadMonthTimelines()
            }
        }
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("时间范围", selection: $selectedPeriod) {
            ForEach(Period.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, AppSpacing.md)
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                summaryCard(
                    icon: "figure.run",
                    iconColor: AppColor.workout,
                    label: "运动",
                    value: formattedActiveMinutes,
                    unit: "",
                    trend: movementTrend
                )
                summaryCard(
                    icon: "bed.double.fill",
                    iconColor: AppColor.sleep,
                    label: "睡眠",
                    value: formattedSleepHours,
                    unit: "",
                    trend: sleepTrend
                )
                summaryCard(
                    icon: "figure.walk",
                    iconColor: AppColor.walk,
                    label: "步数",
                    value: formattedStepCount,
                    unit: "",
                    trend: stepsTrend
                )
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }

    private func summaryCard(
        icon: String,
        iconColor: Color,
        label: String,
        value: String,
        unit: String,
        trend: [SparklinePoint]
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.xxs) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(iconColor)
                Text(label)
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.labelSecondary)
            }

            Text(value)
                .font(.title2.bold())
                .foregroundStyle(AppColor.label)

            Chart(trend) { point in
                AreaMark(
                    x: .value("日", point.index),
                    y: .value("值", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [iconColor.opacity(0.4), iconColor.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("日", point.index),
                    y: .value("值", point.value)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .foregroundStyle(iconColor)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .frame(height: 36)
        }
        .padding(AppSpacing.md)
        .frame(width: 160, alignment: .leading)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
    }

    // MARK: - Calendar Section

    private var calendarSection: some View {
        VStack(spacing: AppSpacing.md) {
            // Month navigation header
            HStack {
                Button {
                    shiftMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColor.labelSecondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthTitle)
                    .font(AppFont.headline)
                    .foregroundStyle(AppColor.label)

                Spacer()

                Button {
                    shiftMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(canAdvanceMonth ? AppColor.labelSecondary : AppColor.labelQuaternary)
                }
                .buttonStyle(.plain)
                .disabled(!canAdvanceMonth)
            }
            .padding(.horizontal, AppSpacing.md)

            // Weekday headers
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: AppSpacing.xs) {
                ForEach(weekdayTitles, id: \.self) { title in
                    Text(title)
                        .font(AppFont.caption)
                        .foregroundStyle(AppColor.labelTertiary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(monthGrid.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(for: day)
                    } else {
                        Color.clear
                            .frame(height: 50)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)

            if isMonthLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, AppSpacing.xs)
                    .tint(AppColor.accent)
            }
        }
    }

    private func dayCell(for date: Date) -> some View {
        let selectable = isSelectable(date)
        let dayNumber = calendar.component(.day, from: date)
        let hasData = hasDayData(for: date)
        let isToday = calendar.isDateInToday(date)
        let isInFuture = date > Date()

        return Group {
            if selectable {
                NavigationLink {
                    HistoryDayDetailScreen(viewModel: viewModel, date: date)
                } label: {
                    HistoryCalendarDayCell(
                        dayNumber: dayNumber,
                        hasData: hasData,
                        isToday: isToday,
                        isInFuture: isInFuture
                    )
                }
                .buttonStyle(.plain)
            } else {
                HistoryCalendarDayCell(
                    dayNumber: dayNumber,
                    hasData: hasData,
                    isToday: isToday,
                    isInFuture: isInFuture
                )
            }
        }
    }

    // MARK: - Data Helpers

    private func hasDayData(for date: Date) -> Bool {
        let day = calendar.startOfDay(for: date)
        if monthTimelines[day] != nil { return true }
        if cachedTimelineDates.contains(day) { return true }
        if viewModel.historyDigests.first(where: { calendar.isDate($0.date, inSameDayAs: day) }) != nil { return true }
        return false
    }

    private var timelineLookup: [Date: DayTimeline] {
        Dictionary(uniqueKeysWithValues: weeklyTimelines.map { (calendar.startOfDay(for: $0.date), $0) })
    }

    private var referenceDate: Date {
        calendar.startOfDay(for: weeklyTimelines.last?.date ?? Date())
    }

    private var currentWeekDates: [Date] {
        (-6...0).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: referenceDate)
        }
    }

    private var currentWeek: [DayTimeline] {
        currentWeekDates.compactMap { timelineLookup[$0] }
    }

    // Trend computations

    private var movementTrend: [SparklinePoint] {
        currentWeekDates.enumerated().map { index, date in
            SparklinePoint(
                index: index,
                value: timelineLookup[date].map { totalActiveMinutes(in: [$0]) } ?? 0
            )
        }
    }

    private var sleepTrend: [SparklinePoint] {
        currentWeekDates.enumerated().map { index, date in
            SparklinePoint(
                index: index,
                value: timelineLookup[date].map { sleepHours(in: $0) } ?? 0
            )
        }
    }

    private var stepsTrend: [SparklinePoint] {
        currentWeekDates.enumerated().map { index, date in
            SparklinePoint(
                index: index,
                value: Double(totalSteps(in: timelineLookup[date]))
            )
        }
    }

    // Formatted values

    private var formattedActiveMinutes: String {
        let minutes = totalActiveMinutes(in: currentWeek)
        let rounded = max(Int(minutes.rounded()), 0)
        let hours = rounded / 60
        let remainder = rounded % 60
        if hours > 0 {
            return remainder == 0 ? "\(hours) \u{5c0f}\u{65f6}" : "\(hours) \u{5c0f}\u{65f6} \(remainder) \u{5206}\u{949f}"
        }
        return "\(rounded) \u{5206}\u{949f}"
    }

    private var formattedSleepHours: String {
        let hours = averageSleepHours(in: currentWeek)
        guard hours > 0 else { return "-- \u{5c0f}\u{65f6}" }
        return String(format: "%.1f \u{5c0f}\u{65f6}", hours)
    }

    private var formattedStepCount: String {
        let total = currentWeek.reduce(0) { $0 + totalSteps(in: $1) }
        let daily = currentWeek.isEmpty ? 0 : total / currentWeek.count
        if daily >= 10000 {
            return String(format: "%.1f \u{4e07}", Double(daily) / 10000)
        }
        return "\(daily)"
    }

    // Metric computation

    private func totalActiveMinutes(in timelines: [DayTimeline]) -> Double {
        timelines.reduce(0) { partial, timeline in
            partial + timeline.entries.reduce(0) { subtotal, event in
                switch event.kind {
                case .workout, .activeWalk, .commute, .userAnnotated:
                    return subtotal + max(event.duration / 60, 1)
                default:
                    return subtotal
                }
            }
        }
    }

    private func sleepHours(in timeline: DayTimeline) -> Double {
        timeline.entries
            .filter { $0.kind == .sleep }
            .reduce(0.0) { $0 + $1.duration / 3600 }
    }

    private func averageSleepHours(in timelines: [DayTimeline]) -> Double {
        let sleepDurations = timelines.map(sleepHours(in:))
        let validDurations = sleepDurations.filter { $0 > 0 }
        guard !validDurations.isEmpty else { return 0 }
        return validDurations.reduce(0, +) / Double(validDurations.count)
    }

    private func totalSteps(in timeline: DayTimeline?) -> Int {
        guard let timeline else { return 0 }
        return timeline.entries.reduce(0) { partial, event in
            partial + (event.associatedMetrics?.stepCount ?? 0)
        }
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
        ["\u{65e5}", "\u{4e00}", "\u{4e8c}", "\u{4e09}", "\u{56db}", "\u{4e94}", "\u{516d}"]
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

    private func isSelectable(_ date: Date) -> Bool {
        let day = calendar.startOfDay(for: date)
        if day > calendar.startOfDay(for: Date()) {
            return false
        }

        return monthTimelines[day] != nil || cachedTimelineDates.contains(day) || viewModel.historyDetail(for: date) != nil
    }

    // MARK: - Data Loading

    private func loadWeeklyInsights() async {
        let dates = (0..<14).compactMap { offset in
            calendar.date(byAdding: .day, value: -13 + offset, to: calendar.startOfDay(for: Date()))
        }
        weeklyTimelines = await viewModel.loadTimelines(for: dates)
    }

    private func loadMonthTimelines() async {
        isMonthLoading = true
        defer { isMonthLoading = false }

        guard let monthInterval = calendar.dateInterval(of: .month, for: visibleMonth) else { return }
        let monthDates = calendar.enumeratedDays(in: monthInterval)
            .filter { $0 <= Date() }
        let loadedTimelines = await viewModel.loadTimelines(for: monthDates)
        monthTimelines = Dictionary(uniqueKeysWithValues: loadedTimelines.map { (calendar.startOfDay(for: $0.date), $0) })
        cachedTimelineDates = Set(loadedTimelines.map { calendar.startOfDay(for: $0.date) })
    }
}

// MARK: - Sparkline Data

private struct SparklinePoint: Identifiable {
    let index: Int
    let value: Double

    var id: Int { index }
}

// MARK: - Day Cell

private struct HistoryCalendarDayCell: View {
    let dayNumber: Int
    let hasData: Bool
    let isToday: Bool
    let isInFuture: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text("\(dayNumber)")
                .font(.body)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(isToday ? Color.white : (isInFuture ? Color(UIColor.quaternaryLabel) : Color.primary))
                .frame(width: 36, height: 36)
                .background(isToday ? Color.accentColor : Color.clear)
                .clipShape(Circle())

            Circle()
                .fill(hasData ? Color.accentColor : .clear)
                .frame(width: 6, height: 6)
        }
        .frame(height: 50)
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
            .background(Color(UIColor.secondarySystemGroupedBackground).opacity(0.72))
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
