import Combine
import Foundation

@MainActor
final class WatchViewModel: ObservableObject {
    @Published private(set) var activeSession: MoodRecord?

    private let connectivityManager: WatchConnectivityManager
    private var cancellables = Set<AnyCancellable>()

    convenience init() {
        self.init(connectivityManager: .shared)
    }

    init(connectivityManager: WatchConnectivityManager) {
        self.connectivityManager = connectivityManager
        activeSession = connectivityManager.activeSession

        connectivityManager.$activeSession
            .sink { [weak self] session in
                self?.activeSession = session
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
}
