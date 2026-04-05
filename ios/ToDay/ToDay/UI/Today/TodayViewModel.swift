import Foundation
import SwiftUI
import SwiftData

@MainActor
final class TodayViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var timeline: DayTimeline?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var aiSummary: String?
    @Published private(set) var patternInsight: String?
    @Published var showQuickRecord = false
    @Published var selectedEvent: InferredEvent?

    // MARK: - Dependencies

    private let timelineProvider: any TimelineDataProviding
    private let moodRecordManager: MoodRecordManager
    private let shutterManager: ShutterManager
    private let annotationStore: AnnotationStore
    private let echoMessageManager: EchoMessageManager?

    private var displayDate: Date = Date()
    private let calendar = Calendar.current
    private var hasLoadedOnce = false

    // MARK: - Init

    init(
        timelineProvider: any TimelineDataProviding,
        moodRecordManager: MoodRecordManager,
        shutterManager: ShutterManager,
        annotationStore: AnnotationStore,
        echoMessageManager: EchoMessageManager? = nil
    ) {
        self.timelineProvider = timelineProvider
        self.moodRecordManager = moodRecordManager
        self.shutterManager = shutterManager
        self.annotationStore = annotationStore
        self.echoMessageManager = echoMessageManager
    }

    // MARK: - Data Loading

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            let baseTimeline = try await timelineProvider.loadTimeline(for: displayDate)
            let mergedTimeline = mergedTimeline(base: baseTimeline)
            timeline = mergedTimeline
            hasLoadedOnce = true
            BackgroundTaskManager.updateTodayEventCount(mergedTimeline.entries.count)

            // Load daily insight from Echo messages
            loadAISummary()
        } catch {
            if !hasLoadedOnce {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    func refresh() async {
        await load()
    }

    func setDate(_ date: Date) {
        displayDate = date
    }

    // MARK: - Mood Record

    func saveMoodRecord(mood: MoodRecord.Mood, note: String) {
        let record = MoodRecord(mood: mood, note: note)
        moodRecordManager.startRecord(record)
        Task { await load() }
    }

    func openQuickRecordComposer() {
        showQuickRecord = true
    }

    // MARK: - Recording State

    var hasActiveSession: Bool {
        moodRecordManager.activeRecord != nil
    }

    var activeRecord: MoodRecord? {
        moodRecordManager.activeRecord
    }

    func finishActiveRecord() {
        moodRecordManager.finishActiveRecord()
        Task { await load() }
    }

    // MARK: - Stats

    var stats: [TimelineStat] {
        timeline?.stats ?? []
    }

    var entries: [InferredEvent] {
        timeline?.entries ?? []
    }

    var currentDate: Date {
        displayDate
    }

    var isToday: Bool {
        calendar.isDateInToday(displayDate)
    }

    // MARK: - Private

    private func mergedTimeline(base: DayTimeline) -> DayTimeline {
        let moodEvents = moodRecordManager.records(on: displayDate)
            .map { $0.toInferredEvent(referenceDate: Date(), calendar: calendar) }

        let shutterEvents = shutterManager.inferredEvents(on: displayDate)

        let annotations = annotationStore.annotations(on: displayDate).map(\.asEvent)

        var allEntries = base.entries + moodEvents + shutterEvents + annotations
        allEntries.sort { $0.startDate < $1.startDate }

        return DayTimeline(
            date: base.date,
            summary: base.summary,
            source: base.source,
            stats: base.stats,
            entries: allEntries
        )
    }

    private func loadAISummary() {
        guard let manager = echoMessageManager else { return }
        let messages = manager.allMessages
        if let dailyInsight = messages.first(where: { $0.messageType == .dailyInsight }) {
            aiSummary = dailyInsight.preview
        }

        // Load pattern insight
        if let pattern = messages.first(where: {
            $0.messageType == .dailyInsight && $0.title.contains("规律")
        }) {
            patternInsight = pattern.preview
        }
    }
}
