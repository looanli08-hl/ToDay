import Foundation

/// Encapsulates all Watch-sync logic: event snapshots, timeline snapshots,
/// daily summary persistence, and complication refresh.
#if os(iOS)
@MainActor
final class WatchSyncHelper {
    private let connectivityManager: PhoneConnectivityManager?
    private let calendar: Calendar
    private var lastSharedEventState = SharedEventState(snapshot: nil, eventID: nil)

    init(connectivityManager: PhoneConnectivityManager?, calendar: Calendar = .current) {
        self.connectivityManager = connectivityManager
        self.calendar = calendar
    }

    func sync(
        timeline: DayTimeline?,
        activeRecord: MoodRecord?,
        records: [MoodRecord],
        referenceDate: Date
    ) {
        let eventState = currentEventState(
            timeline: timeline,
            activeRecord: activeRecord,
            referenceDate: referenceDate
        )
        let timelineSnapshot = makeTimelineSnapshot(from: timeline, referenceDate: referenceDate)

        connectivityManager?.updatePhoneContext(
            activeSession: activeRecord,
            currentEvent: eventState.snapshot,
            currentEventID: eventState.eventID,
            timelineSnapshot: timelineSnapshot
        )
        connectivityManager?.storeTimelineSnapshot(timelineSnapshot)

        guard eventState != lastSharedEventState else { return }
        lastSharedEventState = eventState
        connectivityManager?.storeCurrentEventSnapshot(eventState.snapshot)

        if let snapshot = eventState.snapshot {
            connectivityManager?.sendCurrentEventUpdate(snapshot)
        }

        connectivityManager?.sendComplicationRefresh()
    }

    func persistDailySummary(timeline: DayTimeline?, records: [MoodRecord], referenceDate: Date) {
        let shared = UserDefaults(suiteName: SharedAppGroup.identifier) ?? .standard
        guard let timeline else {
            shared.removeObject(forKey: SharedAppGroup.dailySummaryKey)
            return
        }

        let exerciseMinutes = timeline.entries
            .filter { [.workout, .activeWalk, .commute].contains($0.kind) }
            .reduce(0) { $0 + max(0, Int($1.endDate.timeIntervalSince($1.startDate)) / 60) }

        let snapshot = DailySummarySnapshot(
            exerciseMinutes: exerciseMinutes,
            moodCount: records.count,
            eventCount: timeline.entries.count
        )

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        shared.set(data, forKey: SharedAppGroup.dailySummaryKey)
    }

    // MARK: - Private

    private func currentEventState(
        timeline: DayTimeline?,
        activeRecord: MoodRecord?,
        referenceDate: Date
    ) -> SharedEventState {
        if let event = timeline?.entries
            .sorted(by: { $0.startDate < $1.startDate })
            .last(where: { $0.startDate <= referenceDate && ($0.endDate >= referenceDate || $0.isLive) }) {
            return SharedEventState(snapshot: snapshot(for: event, at: referenceDate), eventID: event.id)
        }

        guard let activeRecord else {
            return SharedEventState(snapshot: nil, eventID: nil)
        }

        let fallbackEvent = activeRecord.toInferredEvent(referenceDate: referenceDate, calendar: calendar)
        return SharedEventState(snapshot: snapshot(for: fallbackEvent, at: referenceDate), eventID: fallbackEvent.id)
    }

    private func makeTimelineSnapshot(from timeline: DayTimeline?, referenceDate: Date) -> WatchTimelineSnapshot? {
        guard let timeline else { return nil }
        return WatchTimelineSnapshot(
            date: timeline.date,
            summary: timeline.summary,
            sourceRawValue: timeline.source.rawValue,
            generatedAt: referenceDate,
            events: timeline.entries.map(WatchTimelineEventSnapshot.init(event:))
        )
    }

    private func snapshot(for event: InferredEvent, at referenceDate: Date) -> CurrentEventSnapshot {
        CurrentEventSnapshot(
            eventName: event.resolvedName,
            eventKind: event.kind.rawValue,
            startDate: event.startDate,
            durationMinutes: max(1, Int(max(referenceDate.timeIntervalSince(event.startDate), 60)) / 60),
            iconName: Self.iconName(for: event)
        )
    }

    static func iconName(for event: InferredEvent) -> String {
        switch event.kind {
        case .sleep:
            return "bed.double.fill"
        case .workout:
            if let workoutType = event.associatedMetrics?.workoutType {
                if workoutType.contains("跑") { return "figure.run" }
                if workoutType.contains("骑") { return "bicycle" }
            }
            return "figure.strengthtraining.traditional"
        case .commute:
            return "tram.fill"
        case .activeWalk:
            return "figure.walk"
        case .quietTime:
            return "sparkles.rectangle.stack"
        case .userAnnotated:
            return "pencil.and.scribble"
        case .mood:
            switch MoodRecord.Mood(storedValue: event.displayName) {
            case .happy: return "sun.max.fill"
            case .calm: return "leaf.fill"
            case .focused: return "scope"
            case .grateful: return "hands.sparkles.fill"
            case .excited: return "sparkles"
            case .tired, .sleepy: return "bed.double.fill"
            case .anxious: return "waveform.path.ecg"
            case .sad: return "cloud.rain.fill"
            case .irritated: return "flame.fill"
            case .bored: return "ellipsis.circle.fill"
            case .satisfied: return "checkmark.seal.fill"
            case nil: return "face.smiling"
            }
        case .shutter:
            return "camera.fill"
        case .screenTime:
            return "iphone"
        case .spending:
            return "creditcard.fill"
        case .dataGap:
            return "minus"
        }
    }
}

private struct SharedEventState: Equatable {
    let snapshot: CurrentEventSnapshot?
    let eventID: UUID?
}
#endif
