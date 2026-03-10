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
    @Published private(set) var activeRecord: MoodRecord?
    @Published var showQuickRecord = false

    private let provider: any TimelineDataProviding
    private let recordStore: any MoodRecordStoring
    private let insightComposer: TodayInsightComposer
    private let calendar: Calendar
    private var hasLoadedOnce = false
    private var currentBaseTimeline: DayTimeline?
    private var timelineCache: [Date: DayTimeline] = [:]
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
        reloadManualRecords()
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
        reloadManualRecords()
        rebuildTimeline(referenceDate: currentBaseTimeline?.date ?? Date())

        do {
            let base = try await provider.loadTimeline(for: Date())
            currentBaseTimeline = base
            timelineCache[calendar.startOfDay(for: base.date)] = base
            rebuildTimeline(referenceDate: base.date)
            hasLoadedOnce = true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        isLoading = false
    }

    func startMoodRecord(_ record: MoodRecord) {
        guard !containsDuplicateRecord(record) else {
            showQuickRecord = false
            return
        }

        if activeRecord != nil {
            errorMessage = "先结束当前状态，再开始新的一段。"
            return
        }

        manualRecords.insert(record, at: 0)
        manualRecords.sort { $0.createdAt > $1.createdAt }
        activeRecord = record.isOngoing ? record : nil
        persistRecords()
        rebuildTimeline(referenceDate: currentBaseTimeline?.date ?? Date())
    }

    func finishActiveMoodRecord(at date: Date = Date()) {
        guard let activeRecord,
              let index = manualRecords.firstIndex(where: { $0.id == activeRecord.id }) else { return }

        let completedRecord = activeRecord.completed(at: date)
        manualRecords[index] = completedRecord
        manualRecords.sort { $0.createdAt > $1.createdAt }
        self.activeRecord = nil
        persistRecords()
        rebuildTimeline(referenceDate: currentBaseTimeline?.date ?? date)
    }

    func handleQuickRecordTap() {
        if activeRecord != nil {
            finishActiveMoodRecord()
        } else {
            showQuickRecord = true
        }
    }

    var todayManualRecordCount: Int {
        records(on: timeline?.date ?? Date()).count
    }

    var todayNoteCount: Int {
        records(on: timeline?.date ?? Date()).filter(hasNote).count
    }

    var quickRecordButtonTitle: String {
        activeRecord == nil ? "记录此刻" : "完成这段状态"
    }

    var quickRecordButtonSystemImage: String {
        activeRecord == nil ? "plus.circle.fill" : "stop.circle.fill"
    }

    var quickRecordButtonCaption: String? {
        guard let activeRecord else { return nil }
        return "\(activeRecord.mood.rawValue) 正在进行"
    }

    func historyDetail(for date: Date) -> HistoryDayDetail? {
        insightComposer.buildHistoryDetail(for: date, manualRecords: manualRecords)
    }

    private func mergedTimeline(base: DayTimeline) -> DayTimeline {
        let recordsForDay = records(on: base.date)
        let manualEntries = recordsForDay.map { $0.toTimelineEntry(referenceDate: Date(), calendar: calendar) }
        let notesCount = recordsForDay.filter(hasNote).count

        var mergedStats = base.stats
        mergedStats.append(TimelineStat(title: "记录", value: "\(recordsForDay.count)"))

        if notesCount > 0 {
            mergedStats.append(TimelineStat(title: "备注", value: "\(notesCount)"))
        }

        if let activeRecord {
            mergedStats.append(TimelineStat(title: "当前", value: activeRecord.mood.rawValue))
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

    private func rebuildTimeline(referenceDate: Date) {
        if let currentBaseTimeline {
            timeline = mergedTimeline(base: currentBaseTimeline)
            refreshDerivedState(referenceDate: currentBaseTimeline.date)
        } else {
            timeline = nil
            refreshDerivedState(referenceDate: referenceDate)
        }
    }

    private func refreshDerivedState(referenceDate: Date) {
        let recordsForDay = records(on: referenceDate)
        activeRecord = manualRecords.first(where: \.isOngoing)
        historyDigests = insightComposer.buildHistoryDigests(
            from: manualRecords,
            timelines: timelineCache,
            limit: 21
        )
        recentDigests = Array(historyDigests.prefix(7))
        insightSummary = insightComposer.buildTodaySummary(
            referenceDate: referenceDate,
            timeline: timeline,
            recordsForDay: recordsForDay
        )
        weeklyInsight = insightComposer.buildWeeklyInsight(referenceDate: referenceDate, manualRecords: manualRecords)
    }

    private func reloadManualRecords() {
        let loadedRecords = recordStore.loadRecords()
        let sanitizedRecords = sanitizeRecords(loadedRecords)
        manualRecords = sanitizedRecords
        activeRecord = sanitizedRecords.first(where: \.isOngoing)

        if sanitizedRecords.count != loadedRecords.count {
            persistRecords()
        }
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

    private func containsDuplicateRecord(_ candidate: MoodRecord) -> Bool {
        let candidateSignature = ManualRecordSignature(record: candidate)
        return manualRecords.contains { ManualRecordSignature(record: $0) == candidateSignature }
    }

    private func sanitizeRecords(_ records: [MoodRecord]) -> [MoodRecord] {
        var seen = Set<ManualRecordSignature>()

        return records
            .sorted { $0.createdAt > $1.createdAt }
            .filter { record in
                seen.insert(ManualRecordSignature(record: record)).inserted
            }
    }
}

private struct ManualRecordSignature: Hashable {
    let mood: MoodRecord.Mood
    let note: String
    let createdAt: Date
    let endedAt: Date?
    let isTracking: Bool

    init(record: MoodRecord) {
        mood = record.mood
        note = record.note
        createdAt = record.createdAt
        endedAt = record.endedAt
        isTracking = record.isTracking
    }
}
