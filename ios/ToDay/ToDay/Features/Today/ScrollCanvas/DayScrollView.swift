import SwiftUI

struct DayScrollView: View {
    let timeline: DayTimeline
    let onEventTap: (InferredEvent) -> Void
    let onBlankTap: (InferredEvent) -> Void
    let showsCurrentTimeNeedle: Bool

    init(
        timeline: DayTimeline,
        onEventTap: @escaping (InferredEvent) -> Void,
        onBlankTap: @escaping (InferredEvent) -> Void,
        showsCurrentTimeNeedle: Bool = true
    ) {
        self.timeline = timeline
        self.onEventTap = onEventTap
        self.onBlankTap = onBlankTap
        self.showsCurrentTimeNeedle = showsCurrentTimeNeedle
    }

    var body: some View {
        DayVerticalTimelineContent(
            timeline: timeline,
            onEventTap: onEventTap,
            onBlankTap: onBlankTap,
            showsCurrentTimeNeedle: showsCurrentTimeNeedle
        )
    }
}

struct DayVerticalTimelineContent: View {
    let timeline: DayTimeline
    let onEventTap: (InferredEvent) -> Void
    let onBlankTap: (InferredEvent) -> Void
    let showsCurrentTimeNeedle: Bool

    private let calendar = Calendar.current
    private let canvasEvents: [InferredEvent]
    private let moodEvents: [InferredEvent]
    private let allTimelineItems: [TimelineItem]

    init(
        timeline: DayTimeline,
        onEventTap: @escaping (InferredEvent) -> Void,
        onBlankTap: @escaping (InferredEvent) -> Void,
        showsCurrentTimeNeedle: Bool = true
    ) {
        self.timeline = timeline
        self.onEventTap = onEventTap
        self.onBlankTap = onBlankTap
        self.showsCurrentTimeNeedle = showsCurrentTimeNeedle
        self.moodEvents = Self.makeMoodEvents(from: timeline)
        self.canvasEvents = Self.makeCanvasEvents(for: timeline, calendar: .current)
        self.allTimelineItems = Self.makeTimelineItems(
            canvasEvents: self.canvasEvents,
            moodEvents: self.moodEvents
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            verticalGradientBackground

            VStack(alignment: .leading, spacing: 0) {
                ForEach(allTimelineItems) { item in
                    timelineRow(for: item)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 16)

            if showsCurrentTimeNeedle, let currentTimeOffset {
                currentTimeIndicator
                    .padding(.leading, 46)
                    .padding(.trailing, 12)
                    .offset(y: currentTimeOffset)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(UIColor.separator), lineWidth: 0.5)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("今日时间轴")
    }

    @ViewBuilder
    private func timelineRow(for item: TimelineItem) -> some View {
        switch item.content {
        case let .event(event):
            eventRow(event: event, startTime: item.startTime, endTime: item.endTime)
        case let .quietGap(event, label, durationMinutes):
            quietGapRow(
                event: event,
                label: label,
                durationMinutes: durationMinutes,
                startTime: item.startTime
            )
        case let .mood(event):
            moodRow(event: event, time: item.startTime)
        }
    }

    private var verticalGradientBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(
                LinearGradient(
                    stops: gradientStops,
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    private func eventRow(event: InferredEvent, startTime: Date, endTime: Date) -> some View {
        if event.kind == .dataGap {
            return AnyView(gapIndicatorRow(event: event, startTime: startTime, endTime: endTime))
        }
        return AnyView(standardEventRow(event: event, startTime: startTime, endTime: endTime))
    }

    private func standardEventRow(event: InferredEvent, startTime: Date, endTime: Date) -> some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatTime(startTime))
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(AppColor.label.opacity(0.60))

                Text(formatTime(endTime))
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(AppColor.label.opacity(0.35))
            }
            .frame(width: 44, alignment: .trailing)

            VStack(spacing: 0) {
                Circle()
                    .fill(event.cardFill)
                    .frame(width: 8, height: 8)

                Rectangle()
                    .fill(AppColor.label.opacity(0.1))
                    .frame(width: 1.5)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 20)

            EventCardView(event: event)
                .onTapGesture {
                    onEventTap(event)
                }
        }
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, minHeight: eventRowHeight(for: event), alignment: .topLeading)
    }

    private func gapIndicatorRow(event: InferredEvent, startTime: Date, endTime: Date) -> some View {
        let durationMinutes = Int(event.duration / 60)
        let durationText = durationMinutes >= 60
            ? "\(durationMinutes / 60)h \(durationMinutes % 60)m"
            : "\(durationMinutes)m"

        return HStack(alignment: .center, spacing: 0) {
            Text(formatTime(startTime))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(UIColor.quaternaryLabel))
                .frame(width: 44, alignment: .trailing)

            Rectangle()
                .fill(Color(UIColor.separator))
                .frame(width: 20, height: 1)

            HStack(spacing: 4) {
                Image(systemName: "minus")
                    .font(.system(size: 9))
                    .foregroundStyle(Color(UIColor.quaternaryLabel))
                Text("这段时间没有记录 · \(durationText)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color(UIColor.quaternaryLabel))
                Image(systemName: "minus")
                    .font(.system(size: 9))
                    .foregroundStyle(Color(UIColor.quaternaryLabel))
            }
            .padding(.horizontal, 8)

            Spacer()
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func quietGapRow(
        event: InferredEvent,
        label: String,
        durationMinutes: Int,
        startTime: Date
    ) -> some View {
        HStack(alignment: .center, spacing: 0) {
            Text(formatTime(startTime))
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(AppColor.label.opacity(0.3))
                .frame(width: 44, alignment: .trailing)

            VStack(spacing: 0) {
                Rectangle()
                    .fill(AppColor.label.opacity(0.08))
                    .frame(width: 1, height: gapHeight(durationMinutes))
            }
            .frame(width: 20)

            if durationMinutes >= 15 {
                Button {
                    onBlankTap(event)
                } label: {
                    Text("\(label) · \(durationText(durationMinutes))")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColor.label.opacity(0.3))
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            } else {
                Color.clear
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: gapHeight(durationMinutes))
        .contentShape(Rectangle())
        .onTapGesture {
            onBlankTap(event)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label)，\(durationText(durationMinutes))")
    }

    private func moodRow(event: InferredEvent, time: Date) -> some View {
        HStack(alignment: .center, spacing: 0) {
            Text(formatTime(time))
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(AppColor.label.opacity(0.4))
                .frame(width: 44, alignment: .trailing)

            VStack(spacing: 0) {
                Circle()
                    .fill(event.cardStroke)
                    .frame(width: 7, height: 7)

                Rectangle()
                    .fill(AppColor.label.opacity(0.08))
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 20)

            EventCardView(event: event)
                .onTapGesture {
                    onEventTap(event)
                }
        }
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
    }

    private var currentTimeIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 6, height: 6)
                .shadow(color: Color.accentColor.opacity(0.4), radius: 6)

            Rectangle()
                .fill(AppColor.label.opacity(0.5))
                .frame(height: 1.5)
        }
        .allowsHitTesting(false)
        .accessibilityLabel("当前时间")
        .accessibilityHidden(!calendar.isDateInToday(timeline.date))
    }

    private var currentTimeOffset: CGFloat? {
        guard calendar.isDateInToday(timeline.date) else { return nil }

        let now = Date()
        let currentMinute = minuteOffset(for: now)
        var offset: CGFloat = 16

        for item in allTimelineItems {
            let itemStartMinute = minuteOffset(for: item.startTime)
            let itemEndMinute = max(itemStartMinute + 1, minuteOffset(for: item.endTime))
            let rowHeight = rowHeight(for: item)

            if currentMinute >= itemStartMinute && currentMinute <= itemEndMinute {
                let progress = CGFloat(currentMinute - itemStartMinute) / CGFloat(max(itemEndMinute - itemStartMinute, 1))
                return offset + max(6, rowHeight * progress)
            }

            offset += rowHeight
        }

        return nil
    }

    private func formatTime(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }

    private func durationText(_ durationMinutes: Int) -> String {
        if durationMinutes >= 60 {
            let hours = durationMinutes / 60
            let minutes = durationMinutes % 60
            return minutes == 0 ? "\(hours) 小时" : "\(hours) 小时 \(minutes) 分钟"
        }
        return "\(durationMinutes) 分钟"
    }

    private func gapHeight(_ durationMinutes: Int) -> CGFloat {
        switch durationMinutes {
        case ..<15:
            return 8
        case 15..<60:
            return 24
        case 60..<180:
            return 36
        default:
            return 48
        }
    }

    private func eventRowHeight(for event: InferredEvent) -> CGFloat {
        if event.kind == .sleep,
           let sleepStages = event.associatedMetrics?.sleepStages,
           !sleepStages.isEmpty {
            return 92
        }
        return 76
    }

    private func rowHeight(for item: TimelineItem) -> CGFloat {
        switch item.content {
        case let .event(event):
            return eventRowHeight(for: event) + 6
        case let .quietGap(_, _, durationMinutes):
            return gapHeight(durationMinutes)
        case .mood:
            return 44
        }
    }

    private func minuteOffset(for date: Date) -> Int {
        let startOfDay = calendar.startOfDay(for: timeline.date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        let boundedDate = min(max(date, startOfDay), endOfDay)
        return max(Int(boundedDate.timeIntervalSince(startOfDay) / 60), 0)
    }

    private var gradientStops: [Gradient.Stop] {
        [
            .init(color: TodayTheme.scrollNight, location: 0.0),
            .init(color: TodayTheme.scrollNight, location: 5.0 / 24.0),
            .init(color: TodayTheme.scrollSunrise, location: 7.0 / 24.0),
            .init(color: TodayTheme.scrollGold, location: 12.0 / 24.0),
            .init(color: TodayTheme.scrollNoon, location: 14.0 / 24.0),
            .init(color: TodayTheme.scrollSunset, location: 18.0 / 24.0),
            .init(color: TodayTheme.scrollViolet, location: 20.0 / 24.0),
            .init(color: TodayTheme.scrollNight, location: 1.0)
        ]
    }

    private static func makeMoodEvents(from timeline: DayTimeline) -> [InferredEvent] {
        timeline.entries
            .filter { $0.kind == .mood }
            .sorted { $0.startDate < $1.startDate }
    }

    private static func makeCanvasEvents(for timeline: DayTimeline, calendar: Calendar) -> [InferredEvent] {
        let intervalStart = calendar.startOfDay(for: timeline.date)
        let intervalEnd = calendar.date(byAdding: .day, value: 1, to: intervalStart) ?? intervalStart
        let sortedEvents = timeline.entries
            .filter { $0.kind != .mood && $0.endDate > $0.startDate }
            .sorted { $0.startDate < $1.startDate }

        var result: [InferredEvent] = []
        var cursor = intervalStart

        for event in sortedEvents {
            let boundedStart = max(event.startDate, intervalStart)
            let boundedEnd = min(event.endDate, intervalEnd)
            guard boundedEnd > boundedStart else { continue }

            if boundedStart > cursor {
                result.append(blankEvent(start: cursor, end: boundedStart, calendar: calendar))
            }

            result.append(event)
            cursor = max(cursor, boundedEnd)
        }

        if cursor < intervalEnd {
            result.append(blankEvent(start: cursor, end: intervalEnd, calendar: calendar))
        }

        return result
    }

    private static func makeTimelineItems(
        canvasEvents: [InferredEvent],
        moodEvents: [InferredEvent]
    ) -> [TimelineItem] {
        let sortedMoodEvents = moodEvents.sorted { $0.startDate < $1.startDate }
        var items: [TimelineItem] = []
        var moodIndex = 0

        for event in canvasEvents.sorted(by: { $0.startDate < $1.startDate }) {
            var eventMoodEvents: [InferredEvent] = []

            while moodIndex < sortedMoodEvents.count,
                  sortedMoodEvents[moodIndex].startDate < event.endDate {
                if sortedMoodEvents[moodIndex].startDate >= event.startDate {
                    eventMoodEvents.append(sortedMoodEvents[moodIndex])
                }
                moodIndex += 1
            }

            if event.isBlankCandidate {
                items.append(contentsOf: makeQuietGapItems(from: event, moods: eventMoodEvents))
            } else {
                items.append(
                    TimelineItem(
                        startTime: event.startDate,
                        endTime: event.endDate,
                        content: .event(event)
                    )
                )

                for moodEvent in eventMoodEvents {
                    items.append(
                        TimelineItem(
                            startTime: moodEvent.startDate,
                            endTime: max(moodEvent.endDate, moodEvent.startDate.addingTimeInterval(60)),
                            content: .mood(moodEvent)
                        )
                    )
                }
            }
        }

        while moodIndex < sortedMoodEvents.count {
            let moodEvent = sortedMoodEvents[moodIndex]
            items.append(
                TimelineItem(
                    startTime: moodEvent.startDate,
                    endTime: max(moodEvent.endDate, moodEvent.startDate.addingTimeInterval(60)),
                    content: .mood(moodEvent)
                )
            )
            moodIndex += 1
        }

        return items.sorted { lhs, rhs in
            if lhs.startTime == rhs.startTime {
                return lhs.sortOrder < rhs.sortOrder
            }
            return lhs.startTime < rhs.startTime
        }
    }

    private static func makeQuietGapItems(from event: InferredEvent, moods: [InferredEvent]) -> [TimelineItem] {
        guard !moods.isEmpty else {
            return [quietGapItem(from: event, start: event.startDate, end: event.endDate)]
        }

        var items: [TimelineItem] = []
        var cursor = event.startDate

        for mood in moods.sorted(by: { $0.startDate < $1.startDate }) {
            let moodStart = max(mood.startDate, cursor)

            if moodStart > cursor {
                items.append(quietGapItem(from: event, start: cursor, end: moodStart))
            }

            items.append(
                TimelineItem(
                    startTime: mood.startDate,
                    endTime: max(mood.endDate, mood.startDate.addingTimeInterval(60)),
                    content: .mood(mood)
                )
            )

            cursor = max(cursor, mood.endDate)
        }

        if cursor < event.endDate {
            items.append(quietGapItem(from: event, start: cursor, end: event.endDate))
        }

        return items
    }

    private static func quietGapItem(from event: InferredEvent, start: Date, end: Date) -> TimelineItem {
        let gapEvent = InferredEvent(
            kind: event.kind,
            startDate: start,
            endDate: end,
            confidence: event.confidence,
            isLive: event.isLive,
            displayName: event.displayName,
            userAnnotation: event.userAnnotation,
            subtitle: event.subtitle,
            associatedMetrics: event.associatedMetrics,
            photoAttachments: event.photoAttachments
        )

        let durationMinutes = max(Int(end.timeIntervalSince(start) / 60), 1)
        return TimelineItem(
            startTime: start,
            endTime: end,
            content: .quietGap(event: gapEvent, label: gapEvent.resolvedName, durationMinutes: durationMinutes)
        )
    }

    private static func blankEvent(start: Date, end: Date, calendar: Calendar) -> InferredEvent {
        InferredEvent(
            kind: .quietTime,
            startDate: start,
            endDate: end,
            confidence: .low,
            displayName: quietDisplayName(for: start, calendar: calendar),
            subtitle: "这段时间还没有被明确命名。"
        )
    }

    private static func quietDisplayName(for date: Date, calendar: Calendar) -> String {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 0..<5:
            return "未记夜色"
        case 5..<7:
            return "晨起留白"
        case 7..<12:
            return "上午留白"
        case 12..<14:
            return "午间留白"
        case 14..<18:
            return "下午留白"
        case 18..<20:
            return "傍晚留白"
        default:
            return "夜晚留白"
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

private struct TimelineItem: Identifiable {
    let id: UUID
    let startTime: Date
    let endTime: Date
    let content: TimelineItemContent

    init(
        id: UUID = UUID(),
        startTime: Date,
        endTime: Date,
        content: TimelineItemContent
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.content = content
    }

    var sortOrder: Int {
        switch content {
        case .event:
            return 0
        case .mood:
            return 1
        case .quietGap:
            return 2
        }
    }
}

private enum TimelineItemContent {
    case event(InferredEvent)
    case quietGap(event: InferredEvent, label: String, durationMinutes: Int)
    case mood(InferredEvent)
}

private extension InferredEvent {
    func minuteOfDay(calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: startDate)
        return ((components.hour ?? 0) * 60) + (components.minute ?? 0)
    }
}
