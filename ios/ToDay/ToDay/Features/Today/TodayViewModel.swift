import Combine
import Foundation
import SwiftData

@MainActor
final class TodayViewModel: ObservableObject {
    // MARK: - Published State (observed by SwiftUI)

    @Published private(set) var timeline: DayTimeline?
    @Published private(set) var insightSummary: TodayInsightSummary?
    @Published private(set) var weeklyInsight: WeeklyInsightSummary?
    @Published private(set) var recentDigests: [RecentDayDigest] = []
    @Published private(set) var historyDigests: [RecentDayDigest] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var showQuickRecord = false
    @Published var showShutterPanel = false
    @Published var isRecordingVoice = false
    @Published private(set) var quickRecordMode: QuickRecordSheetMode = .flexible

    // MARK: - Managers

    private let recordManager: MoodRecordManager
    private let shutterManager: ShutterManager
    private let annotationStore: AnnotationStore
    private let insightComposer: TodayInsightComposer
    #if os(iOS)
    private let watchSync: WatchSyncHelper
    #endif

    // MARK: - Timeline State

    private let provider: any TimelineDataProviding
    private let modelContainer: ModelContainer
    private let calendar: Calendar
    private var hasLoadedOnce = false
    private var currentBaseTimeline: DayTimeline?
    private var timelineCache: [Date: DayTimeline] = [:]
    private var connectivityCancellable: AnyCancellable?

    private static let maxCachedTimelines = 30

    // MARK: - Init

    init(
        provider: any TimelineDataProviding,
        recordStore: any MoodRecordStoring,
        shutterRecordStore: any ShutterRecordStoring = SwiftDataShutterRecordStore(container: AppContainer.modelContainer),
        insightComposer: TodayInsightComposer = TodayInsightComposer(),
        phoneConnectivityManager: PhoneConnectivityManager? = nil,
        modelContainer: ModelContainer,
        calendar: Calendar = .current
    ) {
        self.provider = provider
        self.modelContainer = modelContainer
        self.calendar = calendar
        self.insightComposer = insightComposer
        self.recordManager = MoodRecordManager(recordStore: recordStore, calendar: calendar)
        self.shutterManager = ShutterManager(recordStore: shutterRecordStore, calendar: calendar)
        self.annotationStore = AnnotationStore(calendar: calendar)
        #if os(iOS)
        self.watchSync = WatchSyncHelper(connectivityManager: phoneConnectivityManager, calendar: calendar)
        #endif

        self.connectivityCancellable = phoneConnectivityManager?.recordsDidChange.sink { [weak self] in
            Task { @MainActor in
                self?.handleExternalRecordsUpdate()
            }
        }

        refreshDerivedState(referenceDate: Date())
    }

    // MARK: - Loading

    func loadIfNeeded() async {
        guard !hasLoadedOnce else { return }
        await load(forceReload: false)
    }

    func load(forceReload: Bool) async {
        guard !isLoading else { return }
        if hasLoadedOnce && !forceReload { return }

        isLoading = true
        errorMessage = nil
        recordManager.reloadFromStore()
        shutterManager.reloadFromStore()
        rebuildTimeline(referenceDate: currentBaseTimeline?.date ?? Date())

        do {
            let base = try await loadBaseTimeline(for: Date(), forceReload: forceReload)
            currentBaseTimeline = base
            rebuildTimeline(referenceDate: base.date)
            hasLoadedOnce = true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Mood Records

    var manualRecords: [MoodRecord] { recordManager.records }
    var activeRecord: MoodRecord? { recordManager.activeRecord }

    var todayManualRecordCount: Int {
        recordManager.records(on: timeline?.date ?? Date()).count
    }

    var todayNoteCount: Int {
        recordManager.noteCount(on: timeline?.date ?? Date())
    }

    func startMoodRecord(_ record: MoodRecord) {
        guard recordManager.startRecord(record) else {
            showQuickRecord = false
            return
        }
        showQuickRecord = false
        rebuildTimeline(referenceDate: currentBaseTimeline?.date ?? Date())
    }

    func finishActiveMoodRecord(at date: Date = Date()) {
        recordManager.finishActiveRecord(at: date)
        rebuildTimeline(referenceDate: currentBaseTimeline?.date ?? date)
    }

    func removeMoodRecord(id: UUID) {
        let orphanedAttachments = recordManager.removeRecord(id: id)
        recordManager.deleteOrphanedPhotos(attachments: orphanedAttachments)
        rebuildTimeline(referenceDate: currentBaseTimeline?.date ?? Date())
    }

    // MARK: - Quick Record Sheet

    func handleQuickRecordTap() {
        if recordManager.activeRecord != nil {
            openPointComposer()
        } else {
            openQuickRecordComposer()
        }
    }

    func openQuickRecordComposer() {
        quickRecordMode = recordManager.activeRecord != nil ? .pointOnly : .flexible
        showQuickRecord = true
    }

    func openPointComposer() {
        quickRecordMode = .pointOnly
        showQuickRecord = true
    }

    // MARK: - UI Computed Properties

    var quickRecordButtonTitle: String { "记录此刻" }
    var quickRecordButtonSystemImage: String { "plus.circle.fill" }

    var quickRecordButtonCaption: String? {
        recordManager.activeRecord != nil ? "当前已有进行中的状态" : "打点或开始一段状态"
    }

    var activeSessionTitle: String? {
        guard let active = recordManager.activeRecord else { return nil }
        return "\(active.mood.rawValue) 正在进行"
    }

    var activeSessionDetail: String? {
        guard let active = recordManager.activeRecord else { return nil }
        let startTime = Self.clockFormatter.string(from: active.createdAt)
        let note = active.note.trimmingCharacters(in: .whitespacesAndNewlines)
        if note.isEmpty {
            return "开始于 \(startTime)，你可以继续补打点，最后再结束这段状态。"
        }
        return "开始于 \(startTime) · \(note)"
    }

    // MARK: - Annotations

    func annotateEvent(_ event: InferredEvent, title: String) {
        annotationStore.annotate(event, title: title)
        rebuildTimeline(referenceDate: currentBaseTimeline?.date ?? event.startDate)
    }

    func annotateEvent(id: UUID, title: String) {
        let allTimelines = [timeline, currentBaseTimeline] + timelineCache.values.map(Optional.some)
        guard let event = allTimelines
            .compactMap({ $0 })
            .flatMap(\.entries)
            .first(where: { $0.id == id }) else { return }
        annotateEvent(event, title: title)
    }

    // MARK: - Shutter Records

    var shutterRecords: [ShutterRecord] { shutterManager.records }

    func todayShutterCount(on date: Date? = nil) -> Int {
        shutterManager.records(on: date ?? timeline?.date ?? Date()).count
    }

    func saveShutterRecord(_ record: ShutterRecord) {
        shutterManager.save(record)
        showShutterPanel = false
        isRecordingVoice = false
        rebuildTimeline(referenceDate: currentBaseTimeline?.date ?? Date())
    }

    func deleteShutterRecord(id: UUID) {
        shutterManager.delete(id: id)
        rebuildTimeline(referenceDate: currentBaseTimeline?.date ?? Date())
    }

    // MARK: - History

    func historyDetail(for date: Date) -> HistoryDayDetail? {
        insightComposer.buildHistoryDetail(for: date, manualRecords: recordManager.records)
    }

    func cachedTimeline(for date: Date) -> DayTimeline? {
        let day = calendar.startOfDay(for: date)
        if let currentBaseTimeline, calendar.isDate(currentBaseTimeline.date, inSameDayAs: day) {
            return mergedTimeline(base: currentBaseTimeline)
        }
        guard let cached = timelineCache[day] else { return nil }
        return mergedTimeline(base: cached)
    }

    func loadTimeline(for date: Date, forceReload: Bool = false) async -> DayTimeline? {
        do {
            let base = try await loadBaseTimeline(for: calendar.startOfDay(for: date), forceReload: forceReload)
            return mergedTimeline(base: base)
        } catch {
            return nil
        }
    }

    func loadTimelines(for dates: [Date], forceReload: Bool = false) async -> [DayTimeline] {
        var result: [DayTimeline] = []
        for date in dates {
            if let tl = await loadTimeline(for: date, forceReload: forceReload) {
                result.append(tl)
            }
        }
        return result.sorted { $0.date < $1.date }
    }

    // MARK: - Timeline Merge

    private func mergedTimeline(base: DayTimeline) -> DayTimeline {
        let recordsForDay = recordManager.records(on: base.date)
        let manualEntries = recordsForDay.map { $0.toInferredEvent(referenceDate: Date(), calendar: calendar) }
        let shutterEntries = shutterManager.inferredEvents(on: base.date)
        let annotationsForDay = annotationStore.annotations(on: base.date)
        let notesCount = recordsForDay.filter(MoodRecordManager.hasNote).count

        var stats = base.stats
        stats.append(TimelineStat(title: "记录", value: "\(recordsForDay.count)"))
        if !annotationsForDay.isEmpty {
            stats.append(TimelineStat(title: "标注", value: "\(annotationsForDay.count)"))
        }
        if notesCount > 0 {
            stats.append(TimelineStat(title: "备注", value: "\(notesCount)"))
        }
        if let active = recordManager.activeRecord {
            stats.append(TimelineStat(title: "当前", value: active.mood.rawValue))
        }

        var matchedIDs = Set<UUID>()
        let annotatedBase = base.entries.map { event -> InferredEvent in
            guard let annotation = annotationStore.annotation(for: event.id) else { return event }
            matchedIDs.insert(annotation.id)
            return event.applyingAnnotation(annotation.title)
        }
        let syntheticEntries = annotationsForDay
            .filter { !matchedIDs.contains($0.id) }
            .map(\.asEvent)

        let entries = (manualEntries + shutterEntries + syntheticEntries + annotatedBase).sorted { lhs, rhs in
            lhs.startDate == rhs.startDate
                ? lhs.id.uuidString < rhs.id.uuidString
                : lhs.startDate < rhs.startDate
        }

        return DayTimeline(date: base.date, summary: base.summary, source: base.source, stats: stats, entries: entries)
    }

    private func rebuildTimeline(referenceDate: Date) {
        if let currentBaseTimeline {
            timeline = mergedTimeline(base: currentBaseTimeline)
            refreshDerivedState(referenceDate: currentBaseTimeline.date)
        } else {
            timeline = nil
            refreshDerivedState(referenceDate: referenceDate)
        }

        #if os(iOS)
        let records = recordManager.records(on: referenceDate)
        watchSync.persistDailySummary(timeline: timeline, records: records, referenceDate: referenceDate)
        #endif
    }

    private func refreshDerivedState(referenceDate: Date) {
        let recordsForDay = recordManager.records(on: referenceDate)

        historyDigests = insightComposer.buildHistoryDigests(
            from: recordManager.records,
            timelines: timelineCache,
            limit: 21
        )
        recentDigests = Array(historyDigests.prefix(7))

        insightSummary = insightComposer.buildTodaySummary(
            referenceDate: referenceDate,
            timeline: timeline,
            recordsForDay: recordsForDay
        )
        weeklyInsight = insightComposer.buildWeeklyInsight(
            referenceDate: referenceDate,
            manualRecords: recordManager.records
        )

        #if os(iOS)
        watchSync.sync(
            timeline: timeline,
            activeRecord: recordManager.activeRecord,
            records: recordsForDay,
            referenceDate: referenceDate
        )
        #endif
    }

    // MARK: - Timeline Cache

    private func loadBaseTimeline(for date: Date, forceReload: Bool) async throws -> DayTimeline {
        let day = calendar.startOfDay(for: date)

        if !forceReload {
            if let currentBaseTimeline, calendar.isDate(currentBaseTimeline.date, inSameDayAs: day) {
                return currentBaseTimeline
            }
            if let cached = timelineCache[day] { return cached }
            if let disk = loadFromDiskCache(for: day) {
                cacheTimeline(disk)
                return disk
            }
        }

        let tl = try await provider.loadTimeline(for: day)
        cacheTimeline(tl)
        saveToDiskCache(tl)
        return tl
    }

    private func cacheTimeline(_ timeline: DayTimeline) {
        timelineCache[calendar.startOfDay(for: timeline.date)] = timeline
        let keys = timelineCache.keys.sorted()
        let overflow = max(0, keys.count - Self.maxCachedTimelines)
        for key in keys.prefix(overflow) {
            timelineCache.removeValue(forKey: key)
        }
    }

    private func saveToDiskCache(_ timeline: DayTimeline) {
        let context = ModelContext(modelContainer)
        let key = DayTimelineEntity.dateKey(for: timeline.date)
        var descriptor = FetchDescriptor<DayTimelineEntity>(predicate: #Predicate { $0.dateKey == key })
        descriptor.fetchLimit = 1

        do {
            if let existing = try context.fetch(descriptor).first {
                existing.update(from: timeline)
            } else {
                context.insert(DayTimelineEntity(timeline: timeline))
            }
            try context.save()
        } catch {
            // Disk cache failure is non-critical
        }
    }

    private func loadFromDiskCache(for date: Date) -> DayTimeline? {
        let context = ModelContext(modelContainer)
        let key = DayTimelineEntity.dateKey(for: date)
        var descriptor = FetchDescriptor<DayTimelineEntity>(predicate: #Predicate { $0.dateKey == key })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first?.toDayTimeline()
    }

    // MARK: - External Updates

    private func handleExternalRecordsUpdate() {
        recordManager.reloadFromStore()
        shutterManager.reloadFromStore()
        rebuildTimeline(referenceDate: currentBaseTimeline?.date ?? Date())
    }

    // MARK: - Formatters

    static let clockFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "HH:mm"
        return f
    }()
}
