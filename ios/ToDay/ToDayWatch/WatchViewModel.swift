import Combine
import Foundation

@MainActor
final class WatchViewModel: ObservableObject {
    @Published private(set) var activeSession: MoodRecord?
    @Published private(set) var currentEvent: CurrentEventSnapshot?

    private let connectivityManager: WatchConnectivityManager
    private let transitionNotifier: EventTransitionNotifier
    private var cancellables = Set<AnyCancellable>()

    convenience init() {
        self.init(connectivityManager: .shared, transitionNotifier: EventTransitionNotifier())
    }

    init(connectivityManager: WatchConnectivityManager, transitionNotifier: EventTransitionNotifier) {
        self.connectivityManager = connectivityManager
        self.transitionNotifier = transitionNotifier
        activeSession = connectivityManager.activeSession
        currentEvent = Self.snapshot(from: connectivityManager.activeSession)

        connectivityManager.$activeSession
            .sink { [weak self] session in
                let previous = self?.currentEvent
                let next = Self.snapshot(from: session)
                self?.activeSession = session
                self?.currentEvent = next
                self?.transitionNotifier.checkTransition(previous: previous, current: next)
            }
            .store(in: &cancellables)
    }

    func recordPoint(mood: MoodRecord.Mood) {
        connectivityManager.sendPointRecord(
            MoodRecord(mood: mood, createdAt: Date(), isTracking: false)
        )
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
        activeSession?.id
    }
}
