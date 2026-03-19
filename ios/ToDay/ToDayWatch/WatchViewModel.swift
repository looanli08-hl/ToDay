import Combine
import Foundation
import WidgetKit

@MainActor
final class WatchViewModel: ObservableObject {
    enum TimelineDataSource: String {
        case phone
        case local
        case sessionFallback
        case waiting

        var label: String {
            switch self {
            case .phone:
                return "手机同步"
            case .local:
                return "手表推理"
            case .sessionFallback:
                return "当前状态"
            case .waiting:
                return "等待同步"
            }
        }
    }

    @Published private(set) var activeSession: MoodRecord?
    @Published private(set) var currentEvent: CurrentEventSnapshot?
    @Published private(set) var currentHeartRate: Int?
    @Published private(set) var currentTimelineSnapshot: WatchTimelineSnapshot?
    @Published private(set) var dataSource: TimelineDataSource = .waiting
    @Published private(set) var healthKitAuthorized = false

    private let connectivityManager: WatchConnectivityManager
    private let transitionNotifier: EventTransitionNotifier
    private let localHealthProvider: WatchHealthKitProvider
    private let localInferenceEngine: WatchEventInferenceEngine
    private let sharedDefaults: UserDefaults?
    private let localRefreshInterval: TimeInterval = 5 * 60
    private let phoneFreshnessInterval: TimeInterval = 10 * 60

    private var cancellables = Set<AnyCancellable>()
    private var currentAnnotationTargetID: UUID?
    private var phoneTimelineSnapshot: WatchTimelineSnapshot?
    private var phoneCurrentEvent: CurrentEventSnapshot?
    private var phoneCurrentEventID: UUID?
    private var localTimelineSnapshot: WatchTimelineSnapshot?
    private var lastLocalRefreshDate: Date?
    private var refreshLoopTask: Task<Void, Never>?
    private var isAppActive = false
    private var lastComplicationKey: PersistedComplicationKey?

    convenience init() {
        self.init(
            connectivityManager: .shared,
            transitionNotifier: EventTransitionNotifier(),
            localHealthProvider: WatchHealthKitProvider(),
            localInferenceEngine: WatchEventInferenceEngine()
        )
    }

    init(
        connectivityManager: WatchConnectivityManager,
        transitionNotifier: EventTransitionNotifier,
        localHealthProvider: WatchHealthKitProvider,
        localInferenceEngine: WatchEventInferenceEngine,
        sharedDefaults: UserDefaults? = UserDefaults(suiteName: SharedAppGroup.identifier)
    ) {
        self.connectivityManager = connectivityManager
        self.transitionNotifier = transitionNotifier
        self.localHealthProvider = localHealthProvider
        self.localInferenceEngine = localInferenceEngine
        self.sharedDefaults = sharedDefaults

        activeSession = connectivityManager.activeSession
        phoneCurrentEvent = connectivityManager.currentEventSnapshot
        phoneCurrentEventID = connectivityManager.currentEventID
        phoneTimelineSnapshot = connectivityManager.timelineSnapshot
        currentHeartRate = localHealthProvider.latestHeartRate.map { Int($0.rounded()) }

        observeConnectivity()
        localHealthProvider.onHealthDataUpdate = { [weak self] in
            guard let self else { return }
            Task { @MainActor [weak self] in
                await self?.refreshLocalTimeline(force: true)
            }
        }
        refreshPresentationState(referenceDate: Date())
    }

    var canAnnotate: Bool {
        annotationTargetID != nil
    }

    var timelineEvents: [WatchTimelineEventSnapshot] {
        if let currentTimelineSnapshot {
            return currentTimelineSnapshot.events.sorted(by: { $0.startDate < $1.startDate })
        }

        if let activeSession {
            return [makeSessionEventSnapshot(from: activeSession)]
        }

        return []
    }

    var currentEventIdentifier: UUID? {
        currentAnnotationTargetID
    }

    var timelineSummary: String {
        if let summary = currentTimelineSnapshot?.summary, !summary.isEmpty {
            return summary
        }

        switch dataSource {
        case .phone:
            return "手机端已同步今天的主线。"
        case .local:
            return "手机长时间未刷新，手表正在用本地健康数据补全今天。"
        case .sessionFallback:
            return "先记住当前状态，稍后会并回完整时间线。"
        case .waiting:
            return "活动一会儿，手表会慢慢拼出今天的片段。"
        }
    }

    func setAppActive(_ isActive: Bool) {
        guard isActive != isAppActive else { return }
        isAppActive = isActive

        if isActive {
            startLocalRefreshLoopIfNeeded()
            return
        }

        stopLocalRefreshLoop()
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

    func annotateCurrentEvent(title: String) {
        guard let annotationTargetID else { return }
        connectivityManager.sendAnnotation(eventID: annotationTargetID, title: title, timestamp: Date())
    }

    func annotate(_ event: WatchTimelineEventSnapshot, title: String) {
        connectivityManager.sendAnnotation(eventID: event.id, title: title, timestamp: Date())
    }

    func registerBackgroundDelivery() async {
        await localHealthProvider.registerBackgroundDelivery()
    }

    func requestHealthKitAuthorization() async -> Bool {
        let authorized = await localHealthProvider.requestAuthorizationIfNeeded()
        healthKitAuthorized = authorized
        return authorized
    }

    private func observeConnectivity() {
        Publishers.CombineLatest4(
            connectivityManager.$activeSession,
            connectivityManager.$currentEventSnapshot,
            connectivityManager.$currentEventID,
            connectivityManager.$timelineSnapshot
        )
        .sink { [weak self] activeSession, currentEventSnapshot, currentEventID, timelineSnapshot in
            guard let self else { return }
            self.activeSession = activeSession
            self.phoneCurrentEvent = currentEventSnapshot
            self.phoneCurrentEventID = currentEventID
            self.phoneTimelineSnapshot = timelineSnapshot
            self.refreshPresentationState(referenceDate: Date())
        }
        .store(in: &cancellables)

        connectivityManager.$complicationRefreshDate
            .sink { refreshDate in
                guard refreshDate != nil else { return }
                WidgetCenter.shared.reloadAllTimelines()
            }
            .store(in: &cancellables)

        localHealthProvider.$latestHeartRate
            .sink { [weak self] latestHeartRate in
                self?.currentHeartRate = latestHeartRate.map { Int($0.rounded()) }
            }
            .store(in: &cancellables)
    }

    private func startLocalRefreshLoopIfNeeded() {
        guard refreshLoopTask == nil else { return }

        refreshLoopTask = Task { [weak self] in
            guard let self else { return }
            await self.localHealthProvider.startLiveHeartRateStream()
            await self.refreshLocalTimeline(force: true)

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { break }
                await self.tick()
            }
        }
    }

    private func stopLocalRefreshLoop() {
        refreshLoopTask?.cancel()
        refreshLoopTask = nil
        localHealthProvider.stopLiveHeartRateStream()
    }

    private func tick() async {
        let now = Date()

        if shouldRefreshLocalTimeline(at: now) {
            await refreshLocalTimeline(force: false)
        } else {
            refreshPresentationState(referenceDate: now)
        }
    }

    private func shouldRefreshLocalTimeline(at date: Date) -> Bool {
        guard let lastLocalRefreshDate else { return true }
        return date.timeIntervalSince(lastLocalRefreshDate) >= localRefreshInterval
    }

    private func refreshLocalTimeline(force: Bool) async {
        guard force || shouldRefreshLocalTimeline(at: Date()) else {
            refreshPresentationState(referenceDate: Date())
            return
        }

        let now = Date()
        let rawData = await localHealthProvider.loadRawData(for: now)

        do {
            let timeline = try await localInferenceEngine.inferTimeline(from: rawData, on: now)
            localTimelineSnapshot = makeLocalTimelineSnapshot(from: timeline, generatedAt: now)
            lastLocalRefreshDate = now
            currentHeartRate = localHealthProvider.latestHeartRate.map { Int($0.rounded()) }
        } catch {
            localTimelineSnapshot = nil
        }

        refreshPresentationState(referenceDate: now)
    }

    private func refreshPresentationState(referenceDate: Date) {
        let previousEvent = currentEvent
        let selection = preferredSelection(referenceDate: referenceDate)

        currentEvent = selection.snapshot
        currentTimelineSnapshot = selection.timelineSnapshot
        currentAnnotationTargetID = selection.eventID
        dataSource = selection.source

        persistComplicationState(for: selection)
        transitionNotifier.checkTransition(previous: previousEvent, current: selection.snapshot)
    }

    private func preferredSelection(referenceDate: Date) -> EventSelection {
        if let phoneSelection = phoneSelection(referenceDate: referenceDate) {
            return phoneSelection
        }

        if let localSelection = localSelection(referenceDate: referenceDate) {
            return localSelection
        }

        if let fallbackSnapshot = Self.snapshot(from: activeSession) {
            return EventSelection(
                source: .sessionFallback,
                snapshot: fallbackSnapshot,
                eventID: activeSession?.id,
                timelineSnapshot: nil
            )
        }

        return EventSelection(source: .waiting, snapshot: nil, eventID: nil, timelineSnapshot: nil)
    }

    private func phoneSelection(referenceDate: Date) -> EventSelection? {
        guard let phoneTimelineSnapshot,
              referenceDate.timeIntervalSince(phoneTimelineSnapshot.generatedAt) <= phoneFreshnessInterval else {
            return nil
        }

        if let phoneCurrentEvent {
            return EventSelection(
                source: .phone,
                snapshot: phoneCurrentEvent,
                eventID: phoneCurrentEventID,
                timelineSnapshot: phoneTimelineSnapshot
            )
        }

        let derived = Self.currentEventSnapshot(
            from: phoneTimelineSnapshot,
            referenceDate: referenceDate
        )

        return EventSelection(
            source: .phone,
            snapshot: derived.snapshot,
            eventID: derived.eventID,
            timelineSnapshot: phoneTimelineSnapshot
        )
    }

    private func localSelection(referenceDate: Date) -> EventSelection? {
        guard let localTimelineSnapshot else { return nil }
        let derived = Self.currentEventSnapshot(from: localTimelineSnapshot, referenceDate: referenceDate)

        return EventSelection(
            source: .local,
            snapshot: derived.snapshot,
            eventID: derived.eventID,
            timelineSnapshot: localTimelineSnapshot
        )
    }

    private func persistComplicationState(for selection: EventSelection) {
        let newKey = PersistedComplicationKey(selection: selection)

        if let snapshot = selection.snapshot,
           let data = try? JSONEncoder().encode(snapshot) {
            sharedDefaults?.set(data, forKey: SharedAppGroup.currentEventSnapshotKey)
        } else {
            sharedDefaults?.removeObject(forKey: SharedAppGroup.currentEventSnapshotKey)
        }

        if let timelineSnapshot = selection.timelineSnapshot,
           let data = try? JSONEncoder().encode(timelineSnapshot) {
            sharedDefaults?.set(data, forKey: SharedAppGroup.watchTimelineSnapshotKey)
        } else if selection.source != .phone {
            sharedDefaults?.removeObject(forKey: SharedAppGroup.watchTimelineSnapshotKey)
        }

        if newKey != lastComplicationKey {
            lastComplicationKey = newKey
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func makeLocalTimelineSnapshot(from timeline: DayTimeline, generatedAt: Date) -> WatchTimelineSnapshot {
        WatchTimelineSnapshot(
            date: timeline.date,
            summary: timeline.summary,
            sourceRawValue: "watchLocal",
            generatedAt: generatedAt,
            events: timeline.entries.map(WatchTimelineEventSnapshot.init(event:))
        )
    }

    private func makeSessionEventSnapshot(from record: MoodRecord) -> WatchTimelineEventSnapshot {
        WatchTimelineEventSnapshot(
            id: record.id,
            kindRawValue: "session",
            startDate: record.createdAt,
            endDate: record.endedAt ?? record.createdAt,
            displayName: record.mood.rawValue,
            userAnnotation: nil,
            confidenceRawValue: 2,
            isLive: true
        )
    }

    private static func currentEventSnapshot(
        from timelineSnapshot: WatchTimelineSnapshot,
        referenceDate: Date
    ) -> (snapshot: CurrentEventSnapshot?, eventID: UUID?) {
        guard let event = timelineSnapshot.events
            .sorted(by: { $0.startDate < $1.startDate })
            .last(where: { $0.startDate <= referenceDate && ($0.endDate >= referenceDate || $0.isLive) }) else {
            return (nil, nil)
        }

        return (
            CurrentEventSnapshot(
                eventName: event.resolvedName,
                eventKind: event.kindRawValue,
                startDate: event.startDate,
                durationMinutes: max(1, Int(max(referenceDate.timeIntervalSince(event.startDate), 60)) / 60),
                iconName: iconName(for: event)
            ),
            event.id
        )
    }

    private static func snapshot(from record: MoodRecord?) -> CurrentEventSnapshot? {
        guard let record else { return nil }

        return CurrentEventSnapshot(
            eventName: record.mood.rawValue,
            eventKind: "session",
            startDate: record.createdAt,
            durationMinutes: max(1, Int(max(Date().timeIntervalSince(record.createdAt), 60)) / 60),
            iconName: iconName(for: record.mood)
        )
    }

    private static func iconName(for event: WatchTimelineEventSnapshot) -> String {
        switch event.kindRawValue {
        case "sleep":
            return "bed.double.fill"
        case "workout":
            if event.resolvedName.contains("跑") {
                return "figure.run"
            }
            if event.resolvedName.contains("骑") {
                return "bicycle"
            }
            if event.resolvedName.contains("走") || event.resolvedName.contains("徒步") {
                return "figure.walk"
            }
            return "figure.strengthtraining.traditional"
        case "commute":
            return "tram.fill"
        case "activeWalk":
            return "figure.walk"
        case "quietTime":
            return "sparkles.rectangle.stack"
        case "userAnnotated":
            return "pencil.and.scribble"
        case "mood":
            return iconName(for: MoodRecord.Mood(storedValue: event.displayName) ?? .happy)
        default:
            return "circle.hexagongrid.fill"
        }
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

private struct EventSelection {
    let source: WatchViewModel.TimelineDataSource
    let snapshot: CurrentEventSnapshot?
    let eventID: UUID?
    let timelineSnapshot: WatchTimelineSnapshot?
}

private struct PersistedComplicationKey: Equatable {
    let source: WatchViewModel.TimelineDataSource
    let eventName: String?
    let eventKind: String?
    let startDate: Date?
    let iconName: String?

    init(selection: EventSelection) {
        source = selection.source
        eventName = selection.snapshot?.eventName
        eventKind = selection.snapshot?.eventKind
        startDate = selection.snapshot?.startDate
        iconName = selection.snapshot?.iconName
    }
}
