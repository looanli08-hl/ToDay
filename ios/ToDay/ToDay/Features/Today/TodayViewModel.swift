import Foundation

@MainActor
final class TodayViewModel: ObservableObject {
    @Published private(set) var timeline: DayTimeline?
    @Published private(set) var insightSummary: TodayInsightSummary?
    @Published private(set) var weeklyInsight: WeeklyInsightSummary?
    @Published private(set) var recentDigests: [RecentDayDigest] = []
    @Published private(set) var historyDigests: [RecentDayDigest] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var showQuickRecord = false

    private let provider: any TimelineDataProviding
    private let recordStore: any MoodRecordStoring
    private let insightComposer: TodayInsightComposer
    private let calendar: Calendar
    private var hasLoadedOnce = false
    private(set) var manualRecords: [MoodRecord] = []

    init(
        provider: any TimelineDataProviding,
        recordStore: any MoodRecordStoring,
        insightComposer: TodayInsightComposer = TodayInsightComposer(),
        calendar: Calendar = .current
    ) {
        self.provider = provider
        self.recordStore = recordStore
        self.insightComposer = insightComposer
        self.calendar = calendar
        self.manualRecords = recordStore.loadRecords()
        refreshDerivedState(referenceDate: Date())
    }

    func loadIfNeeded() async {
        guard !hasLoadedOnce else { return }
        await load(forceReload: false)
    }

    func load(forceReload: Bool) async {
        guard !isLoading else { return }
        if hasLoadedOnce && !forceReload { return }

        isLoading = true
        errorMessage = nil
        manualRecords = recordStore.loadRecords()
        refreshDerivedState(referenceDate: Date())

        do {
            let base = try await provider.loadTimeline(for: Date())
            let merged = mergedTimeline(base: base)
            timeline = merged
            refreshDerivedState(referenceDate: merged.date)
            hasLoadedOnce = true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        isLoading = false
    }

    func addMoodRecord(_ record: MoodRecord) {
        manualRecords.insert(record, at: 0)
        manualRecords.sort { $0.createdAt > $1.createdAt }
        persistRecords()

        if let base = timeline {
            let merged = mergedTimeline(base: base)
            timeline = merged
            refreshDerivedState(referenceDate: merged.date)
        } else {
            refreshDerivedState(referenceDate: Date())
        }
    }

    var todayManualRecordCount: Int {
        records(on: timeline?.date ?? Date()).count
    }

    var todayNoteCount: Int {
        records(on: timeline?.date ?? Date()).filter(hasNote).count
    }

    func historyDetail(for date: Date) -> HistoryDayDetail? {
        insightComposer.buildHistoryDetail(for: date, manualRecords: manualRecords)
    }

    private func mergedTimeline(base: DayTimeline) -> DayTimeline {
        let recordsForDay = records(on: base.date)
        let manualEntries = recordsForDay.map { $0.toTimelineEntry() }
        let notesCount = recordsForDay.filter(hasNote).count

        var mergedStats = base.stats
        mergedStats.append(TimelineStat(title: "记录", value: "\(recordsForDay.count)"))

        if notesCount > 0 {
            mergedStats.append(TimelineStat(title: "备注", value: "\(notesCount)"))
        }

        let mergedEntries = (manualEntries + base.entries).sorted { lhs, rhs in
            if lhs.moment.startMinuteOfDay == rhs.moment.startMinuteOfDay {
                return lhs.id < rhs.id
            }

            return lhs.moment.startMinuteOfDay < rhs.moment.startMinuteOfDay
        }

        return DayTimeline(
            date: base.date,
            summary: base.summary,
            source: base.source,
            stats: mergedStats,
            entries: mergedEntries
        )
    }

    private func refreshDerivedState(referenceDate: Date) {
        let recordsForDay = records(on: referenceDate)
        historyDigests = insightComposer.buildHistoryDigests(from: manualRecords, limit: 21)
        recentDigests = Array(historyDigests.prefix(7))
        insightSummary = insightComposer.buildTodaySummary(
            referenceDate: referenceDate,
            timeline: timeline,
            recordsForDay: recordsForDay
        )
        weeklyInsight = insightComposer.buildWeeklyInsight(referenceDate: referenceDate, manualRecords: manualRecords)
    }

    private func records(on date: Date) -> [MoodRecord] {
        manualRecords
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func hasNote(_ record: MoodRecord) -> Bool {
        !record.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func persistRecords() {
        do {
            try recordStore.saveRecords(manualRecords)
        } catch {
            errorMessage = "本地记录保存失败：\(error.localizedDescription)"
        }
    }
}
