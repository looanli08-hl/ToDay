import SwiftUI

enum ScrollCanvasMetrics {
    static let pointsPerMinute: CGFloat = 1.4
    static let moodPointsPerMinute: CGFloat = 1.1
    static let hourWidth: CGFloat = 60 * pointsPerMinute
    static let totalWidth: CGFloat = 24 * hourWidth
    static let moodLaneHeight: CGFloat = 38
    static let cardLaneHeight: CGFloat = 136
    static let canvasHeight: CGFloat = moodLaneHeight + cardLaneHeight
}

struct DayScrollView: View {
    let timeline: DayTimeline
    let onEventTap: (InferredEvent) -> Void
    let onBlankTap: (InferredEvent) -> Void

    private let calendar = Calendar.current

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    ZStack(alignment: .topLeading) {
                        canvasBackground

                        LazyHStack(alignment: .bottom, spacing: 0) {
                            ForEach(canvasEvents) { event in
                                Button {
                                    if event.isBlankCandidate {
                                        onBlankTap(event)
                                    } else {
                                        onEventTap(event)
                                    }
                                } label: {
                                    EventCardView(event: event)
                                        .frame(width: width(for: event), height: event.cardHeight, alignment: .bottomLeading)
                                        .padding(.top, ScrollCanvasMetrics.canvasHeight - ScrollCanvasMetrics.cardLaneHeight + (ScrollCanvasMetrics.cardLaneHeight - event.cardHeight))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        moodOverlay

                        currentTimeNeedle
                    }
                    .frame(width: ScrollCanvasMetrics.totalWidth, height: ScrollCanvasMetrics.canvasHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(TodayTheme.border, lineWidth: 1)
                    )

                    timeAxis
                }
                .padding(.vertical, 8)
            }
            .task(id: timeline.date) {
                try? await Task.sleep(for: .milliseconds(120))
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo(currentHourAnchorID, anchor: .center)
                }
            }
        }
    }

    private var canvasBackground: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                stops: gradientStops,
                startPoint: .leading,
                endPoint: .trailing
            )

            LazyHStack(spacing: 0) {
                ForEach(0..<24, id: \.self) { hour in
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: ScrollCanvasMetrics.hourWidth)
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(Color.white.opacity(hour % 6 == 0 ? 0.2 : 0.1))
                                .frame(width: 1)
                        }
                        .id("hour-\(hour)")
                }
            }
        }
    }

    private var timeAxis: some View {
        LazyHStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                VStack(alignment: .leading, spacing: 4) {
                    Rectangle()
                        .fill(TodayTheme.border)
                        .frame(width: 1, height: hour % 6 == 0 ? 12 : 8)

                    Text("\(hour):00")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(TodayTheme.inkMuted)
                        .minimumScaleFactor(0.7)
                }
                .frame(width: ScrollCanvasMetrics.hourWidth, alignment: .leading)
            }
        }
        .frame(width: ScrollCanvasMetrics.totalWidth, alignment: .leading)
    }

    private var moodOverlay: some View {
        ZStack(alignment: .topLeading) {
            ForEach(moodEvents) { event in
                Button {
                    onEventTap(event)
                } label: {
                    EventCardView(event: event)
                        .frame(width: moodWidth(for: event), height: event.cardHeight)
                }
                .buttonStyle(.plain)
                .position(
                    x: xPosition(for: event),
                    y: moodYPosition(for: event)
                )
            }
        }
        .frame(width: ScrollCanvasMetrics.totalWidth, height: ScrollCanvasMetrics.moodLaneHeight, alignment: .topLeading)
    }

    private var currentTimeNeedle: some View {
        let minute = currentMinuteOfDay
        let x = CGFloat(minute) * ScrollCanvasMetrics.pointsPerMinute

        return Rectangle()
            .fill(Color.white.opacity(calendar.isDateInToday(timeline.date) ? 0.68 : 0))
            .frame(width: 2, height: ScrollCanvasMetrics.canvasHeight)
            .offset(x: x)
            .allowsHitTesting(false)
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

    private var moodEvents: [InferredEvent] {
        timeline.entries
            .filter { $0.kind == .mood }
            .sorted { $0.startDate < $1.startDate }
    }

    private var canvasEvents: [InferredEvent] {
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
                result.append(blankEvent(start: cursor, end: boundedStart))
            }

            result.append(event)
            cursor = max(cursor, boundedEnd)
        }

        if cursor < intervalEnd {
            result.append(blankEvent(start: cursor, end: intervalEnd))
        }

        return result
    }

    private func blankEvent(start: Date, end: Date) -> InferredEvent {
        InferredEvent(
            kind: .quietTime,
            startDate: start,
            endDate: end,
            confidence: .low,
            displayName: quietDisplayName(for: start),
            subtitle: "这段时间还没有被明确命名。"
        )
    }

    private func quietDisplayName(for date: Date) -> String {
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

    private func width(for event: InferredEvent) -> CGFloat {
        CGFloat(event.scrollCanvasDurationMinutes) * ScrollCanvasMetrics.pointsPerMinute
    }

    private func moodWidth(for event: InferredEvent) -> CGFloat {
        event.endDate > event.startDate
            ? max(28, CGFloat(event.scrollCanvasDurationMinutes) * ScrollCanvasMetrics.moodPointsPerMinute)
            : 28
    }

    private func xPosition(for event: InferredEvent) -> CGFloat {
        CGFloat(event.minuteOfDay(calendar: calendar)) * ScrollCanvasMetrics.pointsPerMinute
    }

    private func moodYPosition(for event: InferredEvent) -> CGFloat {
        event.endDate > event.startDate ? 18 : 14
    }

    private var currentMinuteOfDay: Int {
        guard calendar.isDateInToday(timeline.date) else { return 12 * 60 }
        let components = calendar.dateComponents([.hour, .minute], from: Date())
        return ((components.hour ?? 12) * 60) + (components.minute ?? 0)
    }

    private var currentHourAnchorID: String {
        let currentHour = min(max(currentMinuteOfDay / 60, 0), 23)
        return "hour-\(currentHour)"
    }
}

private extension InferredEvent {
    func minuteOfDay(calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: startDate)
        return ((components.hour ?? 0) * 60) + (components.minute ?? 0)
    }
}
