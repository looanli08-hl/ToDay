import Combine
import Foundation
import WatchConnectivity
#if os(watchOS)
import WidgetKit
#endif

private enum ConnectivityCoding {
    static let envelopeIDKey = "envelopeID"
    static let payloadKey = "payload"
    static let phoneContextKey = "phoneContext"

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    static func userInfo(for envelope: WatchEnvelope) -> [String: Any] {
        [
            envelopeIDKey: envelope.id.uuidString,
            payloadKey: (try? encoder.encode(envelope.message)) ?? Data()
        ]
    }

    static func decodeEnvelope(from userInfo: [String: Any]) -> WatchEnvelope? {
        guard let idString = userInfo[envelopeIDKey] as? String,
              let id = UUID(uuidString: idString),
              let payload = userInfo[payloadKey] as? Data,
              let message = try? decoder.decode(WatchMessage.self, from: payload) else {
            return nil
        }

        return WatchEnvelope(id: id, message: message)
    }

    static func contextDictionary(for context: PhoneContext) -> [String: Any]? {
        guard let data = try? encoder.encode(context) else { return nil }
        return [phoneContextKey: data]
    }

    static func decodePhoneContext(from context: [String: Any]) -> PhoneContext? {
        guard let payload = context[phoneContextKey] as? Data else { return nil }
        return try? decoder.decode(PhoneContext.self, from: payload)
    }
}

private struct WatchEnvelope: Codable {
    let id: UUID
    let message: WatchMessage

    init(id: UUID = UUID(), message: WatchMessage) {
        self.id = id
        self.message = message
    }
}

#if os(iOS)
final class PhoneConnectivityManager: NSObject, WCSessionDelegate {
    static let shared = PhoneConnectivityManager()

    let recordsDidChange = PassthroughSubject<Void, Never>()

    private let queue = DispatchQueue(label: "com.looanli.today.phone-connectivity")
    private let sharedDefaults = UserDefaults(suiteName: SharedAppGroup.identifier)
    private var recordStore: (any MoodRecordStoring)?
    private weak var todayViewModel: TodayViewModel?
    private lazy var session: WCSession? = {
        guard WCSession.isSupported() else { return nil }
        return WCSession.default
    }()

    private override init() {
        super.init()
        session?.delegate = self
        session?.activate()
    }

    func configure(recordStore: any MoodRecordStoring) {
        self.recordStore = recordStore
    }

    func bind(todayViewModel: TodayViewModel) {
        self.todayViewModel = todayViewModel
    }

    func updatePhoneContext(
        activeSession: MoodRecord?,
        currentEvent: CurrentEventSnapshot?,
        currentEventID: UUID?
    ) {
        guard let session,
              let dictionary = ConnectivityCoding.contextDictionary(
                for: PhoneContext(
                    activeSession: activeSession,
                    currentEvent: currentEvent,
                    currentEventID: currentEventID
                )
              ) else {
            return
        }

        try? session.updateApplicationContext(dictionary)
    }

    func storeCurrentEventSnapshot(_ snapshot: CurrentEventSnapshot?) {
        if let snapshot,
           let data = try? ConnectivityCoding.encoder.encode(snapshot) {
            sharedDefaults?.set(data, forKey: SharedAppGroup.currentEventSnapshotKey)
        } else {
            sharedDefaults?.removeObject(forKey: SharedAppGroup.currentEventSnapshotKey)
        }
    }

    func sendCurrentEventUpdate(_ snapshot: CurrentEventSnapshot) {
        sendMessageOrFallback(.currentEventUpdate(snapshot))
    }

    func sendComplicationRefresh() {
        sendMessageOrFallback(.complicationRefresh)
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handleIncomingPayload(userInfo)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleIncomingPayload(message)
    }

    private func handleIncomingPayload(_ payload: [String: Any]) {
        guard let envelope = ConnectivityCoding.decodeEnvelope(from: payload) else { return }

        queue.async { [weak self] in
            self?.apply(envelope: envelope)
        }
    }

    private func apply(envelope: WatchEnvelope) {
        guard let recordStore else { return }

        var records = recordStore.loadRecords()

        switch envelope.message {
        case let .pointRecord(record), let .startSession(record):
            upsert(record, into: &records)
        case let .endSession(recordID, endedAt):
            guard let index = records.firstIndex(where: { $0.id == recordID }) else { break }
            records[index] = records[index].completed(at: endedAt)
        case let .annotation(eventID, title, _):
            Task { @MainActor [weak self] in
                self?.todayViewModel?.annotateEvent(id: eventID, title: title)
            }
            return
        case let .moodRecord(mood, timestamp):
            Task { @MainActor [weak self] in
                guard let resolvedMood = MoodRecord.Mood(storedValue: mood) else { return }
                self?.todayViewModel?.startMoodRecord(
                    MoodRecord(
                        mood: resolvedMood,
                        createdAt: timestamp,
                        isTracking: false,
                        captureMode: .point
                    )
                )
            }
            return
        case .currentEventUpdate, .complicationRefresh:
            return
        }

        records.sort { $0.createdAt > $1.createdAt }

        do {
            try recordStore.saveRecords(records)
            let activeSession = records.first(where: \.isOngoing)
            DispatchQueue.main.async { [weak self] in
                self?.updatePhoneContext(activeSession: activeSession, currentEvent: nil, currentEventID: nil)
                self?.recordsDidChange.send()
            }
        } catch {
            return
        }
    }

    private func upsert(_ record: MoodRecord, into records: inout [MoodRecord]) {
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            records[index] = record
        } else {
            records.append(record)
        }
    }

    private func sendMessageOrFallback(_ message: WatchMessage) {
        guard let session,
              session.activationState == .activated,
              session.isWatchAppInstalled else {
            return
        }

        let envelope = WatchEnvelope(message: message)
        let payload = ConnectivityCoding.userInfo(for: envelope)

        guard session.isReachable else {
            session.transferUserInfo(payload)
            return
        }

        session.sendMessage(payload, replyHandler: nil) { [weak session] _ in
            session?.transferUserInfo(payload)
        }
    }
}
#elseif os(watchOS)
@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    @Published private(set) var activeSession: MoodRecord?
    @Published private(set) var currentEventSnapshot: CurrentEventSnapshot?
    @Published private(set) var currentEventID: UUID?
    @Published private(set) var complicationRefreshDate: Date?

    private let defaults = UserDefaults.standard
    private let sharedDefaults = UserDefaults(suiteName: SharedAppGroup.identifier)
    private let pendingMessagesKey = "watch.pendingMessages"
    private lazy var session: WCSession? = {
        guard WCSession.isSupported() else { return nil }
        return WCSession.default
    }()

    private override init() {
        super.init()
        session?.delegate = self
        session?.activate()
        loadInitialContext()
    }

    func sendPointRecord(_ record: MoodRecord) {
        enqueueTransfer(for: .pointRecord(record))
    }

    func sendMoodRecord(mood: MoodRecord.Mood, timestamp: Date) {
        sendMessageOrFallback(.moodRecord(mood: mood.rawValue, timestamp: timestamp))
    }

    func startSession(_ record: MoodRecord) {
        activeSession = record
        sendMessageOrFallback(.startSession(record))
    }

    func endSession(recordID: UUID, endedAt: Date) {
        activeSession = nil
        sendMessageOrFallback(.endSession(recordID: recordID, endedAt: endedAt))
    }

    func sendAnnotation(eventID: UUID, title: String, timestamp: Date) {
        sendMessageOrFallback(.annotation(eventID: eventID, title: title, timestamp: timestamp))
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        loadInitialContext()
        flushPendingTransfers()
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let phoneContext = ConnectivityCoding.decodePhoneContext(from: applicationContext) else { return }
        Task { @MainActor in
            self.activeSession = phoneContext.activeSession
            self.currentEventSnapshot = phoneContext.currentEvent
            self.currentEventID = phoneContext.currentEventID
            self.persistCurrentEventSnapshot(phoneContext.currentEvent)
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handleIncomingPayload(userInfo)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleIncomingPayload(message)
    }

    func session(
        _ session: WCSession,
        didFinish userInfoTransfer: WCSessionUserInfoTransfer,
        error: (any Error)?
    ) {
        guard error == nil,
              let envelope = ConnectivityCoding.decodeEnvelope(from: userInfoTransfer.userInfo) else {
            return
        }

        removePendingEnvelope(id: envelope.id)
    }

    private func loadInitialContext() {
        guard let session else { return }
        guard let phoneContext = ConnectivityCoding.decodePhoneContext(from: session.receivedApplicationContext) else {
            return
        }
        activeSession = phoneContext.activeSession
        currentEventSnapshot = phoneContext.currentEvent
        currentEventID = phoneContext.currentEventID
        persistCurrentEventSnapshot(phoneContext.currentEvent)
    }

    private func sendMessageOrFallback(_ message: WatchMessage) {
        guard let session,
              session.activationState == .activated,
              session.isReachable else {
            enqueueTransfer(for: message)
            return
        }

        let envelope = WatchEnvelope(message: message)
        let payload = ConnectivityCoding.userInfo(for: envelope)

        session.sendMessage(payload, replyHandler: nil) { [weak self] _ in
            Task { @MainActor in
                self?.enqueueTransfer(envelope: envelope)
            }
        }
    }

    private func enqueueTransfer(for message: WatchMessage) {
        enqueueTransfer(envelope: WatchEnvelope(message: message))
    }

    private func enqueueTransfer(envelope: WatchEnvelope) {
        persistPendingEnvelope(envelope)
        session?.transferUserInfo(ConnectivityCoding.userInfo(for: envelope))
    }

    private func flushPendingTransfers() {
        guard let session else { return }

        for envelope in pendingEnvelopes() {
            session.transferUserInfo(ConnectivityCoding.userInfo(for: envelope))
        }
    }

    private func persistPendingEnvelope(_ envelope: WatchEnvelope) {
        var items = pendingEnvelopes()
        items.append(envelope)
        savePendingEnvelopes(items)
    }

    private func removePendingEnvelope(id: UUID) {
        var items = pendingEnvelopes()
        items.removeAll { $0.id == id }
        savePendingEnvelopes(items)
    }

    private func pendingEnvelopes() -> [WatchEnvelope] {
        guard let payloads = defaults.array(forKey: pendingMessagesKey) as? [Data] else {
            return []
        }

        return payloads.compactMap { try? ConnectivityCoding.decoder.decode(WatchEnvelope.self, from: $0) }
    }

    private func savePendingEnvelopes(_ envelopes: [WatchEnvelope]) {
        let payloads = envelopes.compactMap { try? ConnectivityCoding.encoder.encode($0) }
        defaults.set(payloads, forKey: pendingMessagesKey)
    }

    private func handleIncomingPayload(_ payload: [String: Any]) {
        guard let envelope = ConnectivityCoding.decodeEnvelope(from: payload) else { return }
        apply(envelope: envelope)
    }

    private func apply(envelope: WatchEnvelope) {
        switch envelope.message {
        case let .currentEventUpdate(snapshot):
            currentEventSnapshot = snapshot
            persistCurrentEventSnapshot(snapshot)
        case .complicationRefresh:
            complicationRefreshDate = Date()
            WidgetCenter.shared.reloadAllTimelines()
        case .pointRecord, .startSession, .endSession, .annotation, .moodRecord:
            break
        }
    }

    private func persistCurrentEventSnapshot(_ snapshot: CurrentEventSnapshot?) {
        if let snapshot,
           let data = try? ConnectivityCoding.encoder.encode(snapshot) {
            sharedDefaults?.set(data, forKey: SharedAppGroup.currentEventSnapshotKey)
        } else {
            sharedDefaults?.removeObject(forKey: SharedAppGroup.currentEventSnapshotKey)
        }
    }
}
#endif
