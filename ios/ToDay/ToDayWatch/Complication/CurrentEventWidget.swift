import SwiftUI
import WidgetKit

struct CurrentEventEntry: TimelineEntry {
    let date: Date
    let snapshot: CurrentEventSnapshot?
}

struct ToDayTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> CurrentEventEntry {
        CurrentEventEntry(
            date: .now,
            snapshot: CurrentEventSnapshot(
                eventName: "今日画卷",
                eventKind: "placeholder",
                startDate: .now.addingTimeInterval(-45 * 60),
                durationMinutes: 45,
                iconName: "sparkles"
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CurrentEventEntry) -> Void) {
        completion(CurrentEventEntry(date: .now, snapshot: loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CurrentEventEntry>) -> Void) {
        let entry = CurrentEventEntry(date: .now, snapshot: loadSnapshot())
        completion(
            Timeline(
                entries: [entry],
                policy: .after(Date().addingTimeInterval(15 * 60))
            )
        )
    }

    private func loadSnapshot() -> CurrentEventSnapshot? {
        guard let defaults = UserDefaults(suiteName: SharedAppGroup.identifier) else {
            return nil
        }

        if let data = defaults.data(forKey: SharedAppGroup.currentEventSnapshotKey),
           let snapshot = try? JSONDecoder().decode(CurrentEventSnapshot.self, from: data) {
            return snapshot
        }

        guard let timelineData = defaults.data(forKey: SharedAppGroup.watchTimelineSnapshotKey),
              let timeline = try? JSONDecoder().decode(WatchTimelineSnapshot.self, from: timelineData) else {
            return nil
        }

        let now = Date()
        guard let event = timeline.events
            .sorted(by: { $0.startDate < $1.startDate })
            .last(where: { $0.startDate <= now && ($0.endDate >= now || $0.isLive) }) else {
            return nil
        }

        return CurrentEventSnapshot(
            eventName: event.resolvedName,
            eventKind: event.kindRawValue,
            startDate: event.startDate,
            durationMinutes: max(1, Int(max(now.timeIntervalSince(event.startDate), 60)) / 60),
            iconName: iconName(for: event)
        )
    }

    private func iconName(for event: WatchTimelineEventSnapshot) -> String {
        switch event.kindRawValue {
        case "sleep":
            return "bed.double.fill"
        case "workout":
            return event.resolvedName.contains("跑") ? "figure.run" : "figure.strengthtraining.traditional"
        case "commute":
            return "tram.fill"
        case "activeWalk":
            return "figure.walk"
        case "userAnnotated":
            return "pencil.and.scribble"
        case "mood":
            return "heart.circle.fill"
        default:
            return "sparkles.rectangle.stack"
        }
    }
}

struct CurrentEventWidget: Widget {
    private let kind = "CurrentEventWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ToDayTimelineProvider()) { entry in
            CurrentEventWidgetView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("当前事件")
        .description("抬手就能看到你现在正在做的事。")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

private struct CurrentEventWidgetView: View {
    @Environment(\.widgetFamily) private var widgetFamily

    let entry: CurrentEventEntry

    var body: some View {
        switch widgetFamily {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            inlineView
        case .accessoryCorner:
            cornerView
        default:
            rectangularView
        }
    }

    private var snapshot: CurrentEventSnapshot {
        entry.snapshot ?? CurrentEventSnapshot(
            eventName: "今日画卷",
            eventKind: "placeholder",
            startDate: entry.date,
            durationMinutes: 0,
            iconName: "sparkles"
        )
    }

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: snapshot.iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(snapshot.eventName)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
            Text(durationText(snapshot.durationMinutes))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var inlineView: some View {
        Text("\(snapshot.eventName) · \(durationText(snapshot.durationMinutes))")
    }

    private var cornerView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Image(systemName: snapshot.iconName)
            Text(shortDurationText(snapshot.durationMinutes))
                .font(.system(size: 10, weight: .medium))
        }
    }

    private func durationText(_ minutes: Int) -> String {
        guard minutes > 0 else { return "刚刚开始" }

        let hours = minutes / 60
        let remaining = minutes % 60
        if hours == 0 {
            return "\(minutes) 分钟"
        }
        if remaining == 0 {
            return "\(hours) 小时"
        }
        return "\(hours) 小时 \(remaining) 分钟"
    }

    private func shortDurationText(_ minutes: Int) -> String {
        guard minutes > 0 else { return "刚刚" }
        if minutes >= 60 {
            return "\(minutes / 60)小时"
        }
        return "\(minutes)分"
    }
}
