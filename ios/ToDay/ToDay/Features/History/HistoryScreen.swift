import SwiftUI

struct HistoryScreen: View {
    @ObservedObject var viewModel: TodayViewModel
    @ObservedObject var monetizationViewModel: MonetizationViewModel

    let onOpenPro: () -> Void

    @State private var visibleMonth = Calendar.current.todayMonthAnchor
    @State private var monthTimelines: [Date: DayTimeline] = [:]
    @State private var weeklyTimelines: [DayTimeline] = []
    @State private var isMonthLoading = false

    private let calendar = Calendar.current
    private let chineseLocale = Locale(identifier: "zh_CN")

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    weeklyInsightSection
                    calendarSection
                }
                .padding(.vertical, 20)
            }
            .background(TodayTheme.background)
            .navigationTitle("回看")
            .task {
                await loadWeeklyInsights()
            }
            .task(id: visibleMonth) {
                await loadMonthTimelines()
            }
        }
    }

    @ViewBuilder
    private var weeklyInsightSection: some View {
        if monetizationViewModel.isProUnlocked {
            WeeklyInsightView(timelines: weeklyTimelines)
                .padding(.horizontal, 20)
        } else {
            LockedInsightCard(
                title: "一周洞察",
                detail: "免费版先开放当天画卷回看，Pro 会把最近 7 天的运动、睡眠和心情波动整理成连续洞察。",
                buttonTitle: "前往会员页",
                action: onOpenPro
            )
        }
    }

    private var calendarSection: some View {
        ContentCard {
            EyebrowLabel("MONTHLY SCROLL")

            HStack {
                Button {
                    shiftMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(TodayTheme.inkSoft)
                        .frame(width: 34, height: 34)
                        .background(TodayTheme.elevatedCard.opacity(0.72))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 4) {
                    Text(monthTitle)
                        .font(.system(size: 23, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(TodayTheme.ink)

                    Text("每天的色块会先预览当天事件分布，再点进单日画卷。")
                        .font(.system(size: 12))
                        .foregroundStyle(TodayTheme.inkMuted)
                }

                Spacer()

                Button {
                    shiftMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(canAdvanceMonth ? TodayTheme.inkSoft : TodayTheme.inkFaint)
                        .frame(width: 34, height: 34)
                        .background(TodayTheme.elevatedCard.opacity(0.72))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canAdvanceMonth)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(weekdayTitles, id: \.self) { title in
                    Text(title)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(TodayTheme.inkMuted)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(monthGrid.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(for: day)
                    } else {
                        Color.clear
                            .frame(height: 74)
                    }
                }
            }

            if isMonthLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .tint(TodayTheme.teal)
            }
        }
        .padding(.horizontal, 20)
    }

    private func dayCell(for date: Date) -> some View {
        let selectable = isSelectable(date)
        let dayNumber = calendar.component(.day, from: date)

        return Group {
            if selectable {
                NavigationLink {
                    HistoryDayDetailScreen(viewModel: viewModel, date: date)
                } label: {
                    HistoryCalendarDayCell(
                        date: date,
                        dayNumber: dayNumber,
                        previewColors: previewColors(for: date),
                        isToday: calendar.isDateInToday(date),
                        isInFuture: date > Date()
                    )
                }
                .buttonStyle(.plain)
            } else {
                HistoryCalendarDayCell(
                    date: date,
                    dayNumber: dayNumber,
                    previewColors: previewColors(for: date),
                    isToday: calendar.isDateInToday(date),
                    isInFuture: date > Date()
                )
            }
        }
    }

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

    private func previewColors(for date: Date) -> [Color] {
        if let timeline = monthTimelines[calendar.startOfDay(for: date)] {
            let entries = timeline.entries
                .filter { $0.kind != .mood }
                .sorted { $0.startDate < $1.startDate }
                .prefix(6)

            let colors = entries.map(\.cardStroke)
            if !colors.isEmpty {
                return colors
            }
        }

        if let digest = viewModel.historyDigests.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            return Array(repeating: digestColor(for: digest.mood), count: max(1, min(digest.recordCount, 4)))
        }

        return []
    }

    private func isSelectable(_ date: Date) -> Bool {
        let day = calendar.startOfDay(for: date)
        if day > calendar.startOfDay(for: Date()) {
            return false
        }

        return monthTimelines[day] != nil || viewModel.historyDetail(for: date) != nil
    }

    private func digestColor(for mood: MoodRecord.Mood?) -> Color {
        switch mood {
        case .happy:
            return TodayTheme.accent
        case .calm:
            return TodayTheme.teal
        case .focused:
            return TodayTheme.teal
        case .grateful:
            return TodayTheme.scrollGold
        case .excited:
            return TodayTheme.workoutOrange
        case .tired:
            return TodayTheme.blue
        case .anxious:
            return TodayTheme.scrollViolet
        case .sad:
            return TodayTheme.sleepIndigo
        case .irritated:
            return TodayTheme.rose
        case .bored:
            return TodayTheme.inkFaint
        case .sleepy:
            return TodayTheme.blue
        case .satisfied:
            return TodayTheme.scrollSunrise
        case .none:
            return TodayTheme.inkFaint
        }
    }

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
    }
}

private struct HistoryCalendarDayCell: View {
    let date: Date
    let dayNumber: Int
    let previewColors: [Color]
    let isToday: Bool
    let isInFuture: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(dayNumber)")
                .font(.system(size: 15, weight: isToday ? .bold : .medium, design: .rounded))
                .foregroundStyle(isInFuture ? TodayTheme.inkFaint : TodayTheme.inkSoft)

            HStack(spacing: 3) {
                ForEach(0..<6, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(index < previewColors.count ? previewColors[index] : TodayTheme.border.opacity(0.45))
                        .frame(height: 8)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(height: 74)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(isToday ? TodayTheme.accentSoft : TodayTheme.card.opacity(isInFuture ? 0.35 : 1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isToday ? TodayTheme.accent : TodayTheme.border, lineWidth: isToday ? 1.4 : 1)
        )
    }
}

private struct LockedInsightCard: View {
    let title: String
    let detail: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        ContentCard {
            EyebrowLabel("PRO")

            HStack {
                Text(title)
                    .font(.system(size: 23, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(TodayTheme.ink)
                Spacer()
                Text("Pro")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .foregroundStyle(TodayTheme.accent)
                    .background(TodayTheme.accentSoft)
                    .clipShape(Capsule())
            }

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(TodayTheme.inkMuted)

            Button(action: action) {
                Text(buttonTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(TodayTheme.teal)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }
}

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
            .foregroundStyle(TodayTheme.inkSoft)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(TodayTheme.card.opacity(0.72))
            .clipShape(Capsule())
    }
}

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
