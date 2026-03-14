import Combine
import Foundation
import WidgetKit

@MainActor
final class WatchViewModel: ObservableObject {
    @Published private(set) var activeSession: MoodRecord?
    @Published private(set) var currentEvent: CurrentEventSnapshot?
    @Published private(set) var phoneTimelineSnapshot: WatchTimelineSnapshot?

    private let connectivityManager: WatchConnectivityManager
    private let transitionNotifier: EventTransitionNotifier
    private var cancellables = Set<AnyCancellable>()
    private var currentAnnotationTargetID: UUID?

    convenience init() {
        self.init(connectivityManager: .shared, transitionNotifier: EventTransitionNotifier())
    }

    init(connectivityManager: WatchConnectivityManager, transitionNotifier: EventTransitionNotifier) {
        self.connectivityManager = connectivityManager
        self.transitionNotifier = transitionNotifier
        activeSession = connectivityManager.activeSession
        currentAnnotationTargetID = connectivityManager.currentEventID
        currentEvent = connectivityManager.currentEventSnapshot ?? Self.snapshot(from: connectivityManager.activeSession)
        phoneTimelineSnapshot = connectivityManager.timelineSnapshot

        Publishers.CombineLatest3(
            connectivityManager.$activeSession,
            connectivityManager.$currentEventSnapshot,
            connectivityManager.$currentEventID
        )
        .sink { [weak self] session, snapshot, eventID in
            guard let self else { return }
            let previous = self.currentEvent
            self.activeSession = session
            self.currentAnnotationTargetID = eventID
            self.currentEvent = snapshot ?? Self.snapshot(from: session)
            self.transitionNotifier.checkTransition(previous: previous, current: self.currentEvent)
        }
        .store(in: &cancellables)

        connectivityManager.$complicationRefreshDate
            .sink { refreshDate in
                guard refreshDate != nil else { return }
                WidgetCenter.shared.reloadAllTimelines()
            }
            .store(in: &cancellables)

        connectivityManager.$timelineSnapshot
            .sink { [weak self] snapshot in
                self?.phoneTimelineSnapshot = snapshot
            }
            .store(in: &cancellables)
    }

    func recordPoint(mood: MoodRecord.Mood) {
        connectivityManager.sendMoodRecord(mood: mood, timestamp: Date())
    }

    func startSession(mood: MoodRecord.Mood) {
        connectivityManager.startSession(
            MoodRecord.active(mood: mood, createdAt: Date())
        )
    }

    func endSession() {
        guard let activeSession else { return }
        connectivityManager.endSession(recordID: activeSession.id, endedAt: Date())
    }

    var canAnnotate: Bool {
        annotationTargetID != nil
    }

    func annotateCurrentEvent(title: String) {
        guard let annotationTargetID else { return }
        connectivityManager.sendAnnotation(eventID: annotationTargetID, title: title, timestamp: Date())
    }

    private static func snapshot(from record: MoodRecord?) -> CurrentEventSnapshot? {
        guard let record else { return nil }

        return CurrentEventSnapshot(
            eventName: record.mood.rawValue,
            eventKind: "session",
            startDate: record.createdAt,
            durationMinutes: max(0, Int(Date().timeIntervalSince(record.createdAt)) / 60),
            iconName: iconName(for: record.mood)
        )
    }

    private static func iconName(for mood: MoodRecord.Mood) -> String {
        switch mood {
        case .happy:
            return "sun.max.fill"
        case .calm:
            return "leaf.fill"
        case .focused:
            return "scope"
        case .grateful:
            return "hands.sparkles.fill"
        case .excited:
            return "sparkles"
        case .tired, .sleepy:
            return "bed.double.fill"
        case .anxious:
            return "waveform.path.ecg"
        case .sad:
            return "cloud.rain.fill"
        case .irritated:
            return "flame.fill"
        case .bored:
            return "ellipsis.circle.fill"
        case .satisfied:
            return "checkmark.seal.fill"
        }
    }

    private var annotationTargetID: UUID? {
        currentAnnotationTargetID
    }
}
