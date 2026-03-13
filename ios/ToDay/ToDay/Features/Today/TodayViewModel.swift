import Combine
import Foundation

@MainActor
final class TodayViewModel: ObservableObject {
    enum RecordingState {
        case idle
        case recording(MoodRecord)
    }

    @Published private(set) var timeline: DayTimeline?
    @Published private(set) var insightSummary: TodayInsightSummary?
    @Published private(set) var weeklyInsight: WeeklyInsightSummary?
    @Published private(set) var recentDigests: [RecentDayDigest] = []
    @Published private(set) var historyDigests: [RecentDayDigest] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var recordingState: RecordingState = .idle
    @Published var showQuickRecord = false
    @Published private(set) var quickRecordMode: QuickRecordSheetMode = .flexible

    private let provider: any TimelineDataProviding
    private let recordStore: any MoodRecordStoring
    private let insightComposer: TodayInsightComposer
    private let calendar: Calendar
    private let phoneConnectivityManager: PhoneConnectivityManager?
    private var hasLoadedOnce = false
    private var currentBaseTimeline: DayTimeline?
    private var timelineCache: [Date: DayTimeline] = [:]
    private var storedAnnotations: [UUID: StoredAnnotation] = [:]
    private var lastSubmittedFingerprint: DuplicateSubmissionFingerprint?
    private var connectivityCancellable: AnyCancellable?
    private(set) var manualRecords: [MoodRecord] = []

    init(
        provider: any TimelineDataProviding,
        recordStore: any MoodRecordStoring,
        insightComposer: TodayInsightComposer = TodayInsightComposer(),
        phoneConnectivityManager: PhoneConnectivityManager? = nil,
        calendar: Calendar = .current
    ) {
        self.provider = provider
        self.recordStore = recordStore
        self.insightComposer = insightComposer
        self.phoneConnectivityManager = phoneConnectivityManager
        self.calendar = calendar
        self.connectivityCancellable = phoneConnectivityManager?.recordsDidChange.sink { [weak self] in
            Task { @MainActor in
                self?.handleExternalRecordsUpdate()
            }
        }
        loadStoredAnnotations()
        reloadManualRecords()
        refreshDerivedState(referenceDate: Date())
        phoneConnectivityManager?.updatePhoneContext(activeSession: activeRecord)
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
            cacheTimeline(base)
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

        if case .recording = recordingState, record.captureMode == .session {
            errorMessage = "先结束当前状态，再开始新的一段。"
            return
        }

        manualRecords.insert(record, at: 0)
        manualRecords.sort { $0.createdAt > $1.createdAt }
        lastSubmittedFingerprint = DuplicateSubmissionFingerprint(record: record)
        if record.isOngoing {
            setRecordingState(from: record)
        }
        showQuickRecord = false
        persistRecords()
        rebuildTimeline(referenceDate: currentBaseTimeline?.date ?? Date())
    }

    func finishActiveMoodRecord(at date: Date = Date()) {
        guard case let .recording(activeRecord) = recordingState,
              let index = manualRecords.firstIndex(where: { $0.id == activeRecord.id }) else { return }

        let completedRecord = activeRecord.completed(at: date)
        manualRecords[index] = completedRecord
        manualRecords.sort { $0.createdAt > $1.createdAt }
        setRecordingState(from: nil)
        persistRecords()
        rebuildTimeline(referenceDate: currentBaseTimeline?.date ?? date)
    }

    func handleQuickRecordTap() {
        switch recordingState {
        case .idle:
            openQuickRecordComposer()
        case .recording:
            openPointComposer()
        }
    }

    func openQuickRecordComposer() {
        switch recordingState {
        case .idle:
            quickRecordMode = .flexible
        case .recording:
            quickRecordMode = .pointOnly
        }
        showQuickRecord = true
    }

    func openPointComposer() {
        quickRecordMode = .pointOnly
        showQuickRecord = true
    }

    func removeMoodRecord(id: UUID) {
        guard let index = manualRecords.firstIndex(where: { $0.id == id }) else { return }

        let removedRecord = manualRecords.remove(at: index)
        deleteOrphanedPhotos(for: removedRecord.photoAttachments, remainingRecords: manualRecords)

        if case let .recording(activeRecord) = recordingState, activeRecord.id == id {
            setRecordingState(from: nil)
        }

        persistRecords()
        rebuildTimeline(referenceDate: currentBaseTimeline?.date ?? Date())
    }

    var activeRecord: MoodRecord? {
        switch recordingState {
        case .idle:
            return nil
        case let .recording(record):
            return record
        }
    }

    var todayManualRecordCount: Int {
        records(on: timeline?.date ?? Date()).count
    }

    var todayNoteCount: Int {
        records(on: timeline?.date ?? Date()).filter(hasNote).count
    }

    var quickRecordButtonTitle: String {
        "记录此刻"
    }

    var quickRecordButtonSystemImage: String {
        "plus.circle.fill"
    }

    var quickRecordButtonCaption: String? {
        switch recordingState {
        case .idle:
            return "打点或开始一段状态"
        case .recording:
            return "当前已有进行中的状态"
        }
    }

    var activeSessionTitle: String? {
        guard case let .recording(activeRecord) = recordingState else { return nil }
        return "\(activeRecord.mood.rawValue) 正在进行"
    }

    var activeSessionDetail: String? {
        guard case let .recording(activeRecord) = recordingState else { return nil }
        let startTime = Self.clockFormatter.string(from: activeRecord.createdAt)
        let note = activeRecord.note.trimmingCharacters(in: .whitespacesAndNewlines)

        if note.isEmpty {
            return "开始于 \(startTime)，你可以继续补打点，最后再结束这段状态。"
        }

        return "开始于 \(startTime) · \(note)"
    }

    func historyDetail(for date: Date) -> HistoryDayDetail? {
        insightComposer.buildHistoryDetail(for: date, manualRecords: manualRecords)
    }

    func annotateEvent(_ event: InferredEvent, title: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let annotation = StoredAnnotation(
            id: event.id,
            startDate: event.startDate,
            endDate: event.endDate,
            title: trimmedTitle
        )
        storedAnnotations[event.id] = annotation
        persistStoredAnnotations()
        rebuildTimeline(referenceDate: currentBaseTimeline?.date ?? event.startDate)
    }

    private func mergedTimeline(base: DayTimeline) -> DayTimeline {
        let recordsForDay = records(on: base.date)
        let manualEntries = recordsForDay.map { $0.toInferredEvent(referenceDate: Date(), calendar: calendar) }
        let annotationsForDay = annotations(on: base.date)
        let notesCount = recordsForDay.filter(hasNote).count

        var mergedStats = base.stats
        mergedStats.append(TimelineStat(title: "记录", value: "\(recordsForDay.count)"))
        if !annotationsForDay.isEmpty {
            mergedStats.append(TimelineStat(title: "标注", value: "\(annotationsForDay.count)"))
        }

        if notesCount > 0 {
            mergedStats.append(TimelineStat(title: "备注", value: "\(notesCount)"))
        }

        if let activeRecord {
            mergedStats.append(TimelineStat(title: "当前", value: activeRecord.mood.rawValue))
        }

        var matchedAnnotationIDs = Set<UUID>()
        let annotatedBaseEntries = base.entries.map { event in
            guard let annotation = storedAnnotations[event.id] else { return event }
            matchedAnnotationIDs.insert(annotation.id)
            return event.applyingAnnotation(annotation.title)
        }
        let syntheticAnnotationEntries = annotationsForDay
            .filter { !matchedAnnotationIDs.contains($0.id) }
            .map(\.asEvent)

        let mergedEntries = (manualEntries + syntheticAnnotationEntries + annotatedBaseEntries).sorted { lhs, rhs in
            if lhs.startDate == rhs.startDate {
                return lhs.id.uuidString < rhs.id.uuidString
            }

            return lhs.startDate < rhs.startDate
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
        setRecordingState(from: manualRecords.first(where: \.isOngoing))
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
        let removedRecords = removedRecords(from: loadedRecords, keeping: sanitizedRecords)
        manualRecords = sanitizedRecords
        setRecordingState(from: sanitizedRecords.first(where: \.isOngoing))

        if !removedRecords.isEmpty {
            deleteOrphanedPhotos(
                for: removedRecords.flatMap(\.photoAttachments),
                remainingRecords: sanitizedRecords
            )
        }

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
        if manualRecords.contains(where: { ManualRecordSignature(record: $0) == candidateSignature }) {
            return true
        }

        return lastSubmittedFingerprint == DuplicateSubmissionFingerprint(record: candidate)
    }

    private func sanitizeRecords(_ records: [MoodRecord]) -> [MoodRecord] {
        var seen = Set<ManualRecordSignature>()

        return records
            .sorted { $0.createdAt > $1.createdAt }
            .filter { record in
                seen.insert(ManualRecordSignature(record: record)).inserted
            }
    }

    private func cacheTimeline(_ timeline: DayTimeline) {
        timelineCache[calendar.startOfDay(for: timeline.date)] = timeline

        let sortedKeys = timelineCache.keys.sorted()
        let overflow = max(0, sortedKeys.count - Self.maxCachedTimelines)

        if overflow > 0 {
            for key in sortedKeys.prefix(overflow) {
                timelineCache.removeValue(forKey: key)
            }
        }
    }

    private func setRecordingState(from record: MoodRecord?) {
        if let record {
            recordingState = .recording(record)
        } else {
            recordingState = .idle
        }

        phoneConnectivityManager?.updatePhoneContext(activeSession: activeRecord)
    }

    private func removedRecords(from original: [MoodRecord], keeping sanitized: [MoodRecord]) -> [MoodRecord] {
        let keptIDs = Set(sanitized.map(\.id))
        return original.filter { !keptIDs.contains($0.id) }
    }

    private func deleteOrphanedPhotos(for attachments: [MoodPhotoAttachment], remainingRecords: [MoodRecord]) {
        let remainingAttachments = Set(remainingRecords.flatMap(\.photoAttachments))
        let orphanedAttachments = attachments.filter { !remainingAttachments.contains($0) }

        guard !orphanedAttachments.isEmpty else { return }
        MoodPhotoLibrary.deletePhotos(for: orphanedAttachments)
    }

    private static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let maxCachedTimelines = 30
    private static let annotationStorageKey = "today.eventAnnotations"

    private func handleExternalRecordsUpdate() {
        reloadManualRecords()
        rebuildTimeline(referenceDate: currentBaseTimeline?.date ?? Date())
    }

    private func annotations(on date: Date) -> [StoredAnnotation] {
        storedAnnotations.values
            .filter { calendar.isDate($0.startDate, inSameDayAs: date) }
            .sorted { $0.startDate < $1.startDate }
    }

    private func loadStoredAnnotations() {
        guard let data = UserDefaults.standard.data(forKey: Self.annotationStorageKey) else {
            storedAnnotations = [:]
            return
        }

        do {
            let annotations = try JSONDecoder().decode([StoredAnnotation].self, from: data)
            storedAnnotations = Dictionary(uniqueKeysWithValues: annotations.map { ($0.id, $0) })
        } catch {
            storedAnnotations = [:]
        }
    }

    private func persistStoredAnnotations() {
        do {
            let data = try JSONEncoder().encode(storedAnnotations.values.sorted { $0.startDate < $1.startDate })
            UserDefaults.standard.set(data, forKey: Self.annotationStorageKey)
        } catch {
            errorMessage = "留白标注保存失败：\(error.localizedDescription)"
        }
    }
}

private struct ManualRecordSignature: Hashable {
    let id: UUID
    let mood: MoodRecord.Mood
    let note: String
    let createdAt: Date
    let endedAt: Date?
    let isTracking: Bool
    let captureMode: MoodRecord.CaptureMode

    init(record: MoodRecord) {
        id = record.id
        mood = record.mood
        note = record.note
        createdAt = record.createdAt
        endedAt = record.endedAt
        isTracking = record.isTracking
        captureMode = record.captureMode
    }
}

private struct DuplicateSubmissionFingerprint: Hashable {
    let mood: MoodRecord.Mood
    let note: String
    let createdAt: Date
    let endedAt: Date?
    let isTracking: Bool
    let captureMode: MoodRecord.CaptureMode
    let photoAttachments: [MoodPhotoAttachment]

    init(record: MoodRecord) {
        mood = record.mood
        note = record.note
        createdAt = record.createdAt
        endedAt = record.endedAt
        isTracking = record.isTracking
        captureMode = record.captureMode
        photoAttachments = record.photoAttachments
    }
}

private struct StoredAnnotation: Codable, Hashable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let title: String

    var asEvent: InferredEvent {
        InferredEvent(
            id: id,
            kind: .userAnnotated,
            startDate: startDate,
            endDate: endDate,
            confidence: .high,
            displayName: title,
            userAnnotation: title,
            subtitle: "你补上了这段时间的名字。"
        )
    }
}
