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
    @Published var selectedDate: Date = Date()
    @Published var showCalendar = false

    // MARK: - Dependencies

    private let timelineProvider: any TimelineDataProviding
    private let moodRecordManager: MoodRecordManager
    private let shutterManager: ShutterManager
    private let annotationStore: AnnotationStore
    private let echoMessageManager: EchoMessageManager?

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
        await loadTimeline(for: selectedDate)
    }

    func refresh() async {
        await loadTimeline(for: selectedDate)
    }

    func loadTimeline(for date: Date) async {
        guard !isLoading else { return }
        selectedDate = date
        isLoading = true
        errorMessage = nil

        do {
            let baseTimeline = try await timelineProvider.loadTimeline(for: date)
            let mergedTimeline = mergedTimeline(base: baseTimeline, date: date)
            timeline = mergedTimeline
            hasLoadedOnce = true

            if isToday {
                BackgroundTaskManager.updateTodayEventCount(mergedTimeline.entries.count)
                loadAISummary()
            } else {
                aiSummary = nil
                patternInsight = nil
            }
        } catch {
            if !hasLoadedOnce {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    // MARK: - Memo

    func saveMemo(_ note: String) {
        let record = MoodRecord(
            mood: .calm,
            note: note,
            endedAt: Date(),
            captureMode: .point
        )
        _ = moodRecordManager.startRecord(record)
        moodRecordManager.finishActiveRecord()
        Task { await loadTimeline(for: selectedDate) }
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
        selectedDate
    }

    var isToday: Bool {
        calendar.isDateInToday(selectedDate)
    }

    // MARK: - Date Navigation

    var recentDateRange: [Date] {
        (0..<30).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: Date()))
        }.reversed()
    }

    func selectDate(_ date: Date) {
        Task { await loadTimeline(for: date) }
    }

    func returnToToday() {
        let today = Date()
        showCalendar = false
        Task { await loadTimeline(for: today) }
    }

    // MARK: - Private

    private func mergedTimeline(base: DayTimeline, date: Date) -> DayTimeline {
        let moodEvents = moodRecordManager.records(on: date)
            .map { $0.toInferredEvent(referenceDate: Date(), calendar: calendar) }

        let shutterEvents = shutterManager.inferredEvents(on: date)

        let annotations = annotationStore.annotations(on: date).map(\.asEvent)

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

        // Read cached summary first (instant display)
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

        // Trigger background regeneration (30-min throttle in EchoScheduler)
        let summary = timelineDataSummary
        let memos = moodRecordManager.records(on: selectedDate).compactMap { record in
            let note = record.note.trimmingCharacters(in: .whitespacesAndNewlines)
            return note.isEmpty ? nil : note
        }
        Task {
            let scheduler = AppContainer.getEchoScheduler()
            await scheduler.onAppBackground(
                todayDataSummary: summary,
                shutterTexts: [],
                moodNotes: memos
            )
            // Reload after generation
            let updated = manager.allMessages
            if let newInsight = updated.first(where: { $0.messageType == .dailyInsight }) {
                await MainActor.run {
                    aiSummary = newInsight.preview
                }
            }
        }
    }

    /// Formatted timeline data for AI prompts.
    private var timelineDataSummary: String {
        guard let timeline else { return "" }
        let events = timeline.entries.filter { $0.kind != .mood }
        if events.isEmpty { return "" }
        return events.map { "\($0.kindBadgeTitle): \($0.resolvedName) (\($0.scrollDurationText))" }
            .joined(separator: "\n")
    }
}
