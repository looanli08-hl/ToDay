import Foundation

/// Manages CRUD, deduplication, and sanitization of mood records.
/// Owned by TodayViewModel; not an ObservableObject itself.
@MainActor
final class MoodRecordManager {
    private(set) var records: [MoodRecord] = []
    private(set) var recordingState: RecordingState = .idle

    private let recordStore: any MoodRecordStoring
    private let calendar: Calendar
    private var lastSubmittedFingerprint: SubmissionFingerprint?

    enum RecordingState {
        case idle
        case recording(MoodRecord)
    }

    init(recordStore: any MoodRecordStoring, calendar: Calendar = .current) {
        self.recordStore = recordStore
        self.calendar = calendar
        reloadFromStore()
    }

    // MARK: - Queries

    var activeRecord: MoodRecord? {
        switch recordingState {
        case .idle: nil
        case let .recording(record): record
        }
    }

    func records(on date: Date) -> [MoodRecord] {
        records
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func noteCount(on date: Date) -> Int {
        records(on: date).filter(Self.hasNote).count
    }

    // MARK: - Mutations

    /// Returns `false` if the record was rejected as a duplicate.
    @discardableResult
    func startRecord(_ record: MoodRecord) -> Bool {
        guard !isDuplicate(record) else { return false }

        if case .recording = recordingState, record.captureMode == .session {
            return false
        }

        records.insert(record, at: 0)
        records.sort { $0.createdAt > $1.createdAt }
        lastSubmittedFingerprint = SubmissionFingerprint(record: record)

        if record.isOngoing {
            recordingState = .recording(record)
        }

        persistRecords()
        return true
    }

    func finishActiveRecord(at date: Date = Date()) {
        guard case let .recording(activeRecord) = recordingState,
              let index = records.firstIndex(where: { $0.id == activeRecord.id }) else { return }

        records[index] = activeRecord.completed(at: date)
        records.sort { $0.createdAt > $1.createdAt }
        recordingState = .idle
        persistRecords()
    }

    func removeRecord(id: UUID) -> [MoodPhotoAttachment] {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return [] }

        let removed = records.remove(at: index)

        if case let .recording(activeRecord) = recordingState, activeRecord.id == id {
            recordingState = .idle
        }

        persistRecords()
        return removed.photoAttachments
    }

    func reloadFromStore() {
        let loaded = recordStore.loadRecords()
        let sanitized = sanitize(loaded)
        records = sanitized
        recordingState = sanitized.first(where: \.isOngoing).map { .recording($0) } ?? .idle

        let removedAttachments = removedRecords(from: loaded, keeping: sanitized)
            .flatMap(\.photoAttachments)
        if !removedAttachments.isEmpty {
            deleteOrphanedPhotos(attachments: removedAttachments)
        }

        if sanitized.count != loaded.count {
            persistRecords()
        }
    }

    // MARK: - Orphan Cleanup

    func deleteOrphanedPhotos(attachments: [MoodPhotoAttachment]) {
        let remaining = Set(records.flatMap(\.photoAttachments))
        let orphaned = attachments.filter { !remaining.contains($0) }
        guard !orphaned.isEmpty else { return }
        MoodPhotoLibrary.deletePhotos(for: orphaned)
    }

    // MARK: - Private

    private func persistRecords() {
        try? recordStore.saveRecords(records)
    }

    private func isDuplicate(_ candidate: MoodRecord) -> Bool {
        let sig = RecordSignature(record: candidate)
        if records.contains(where: { RecordSignature(record: $0) == sig }) { return true }
        return lastSubmittedFingerprint == SubmissionFingerprint(record: candidate)
    }

    private func sanitize(_ records: [MoodRecord]) -> [MoodRecord] {
        var seen = Set<RecordSignature>()
        return records
            .sorted { $0.createdAt > $1.createdAt }
            .filter { seen.insert(RecordSignature(record: $0)).inserted }
    }

    private func removedRecords(from original: [MoodRecord], keeping sanitized: [MoodRecord]) -> [MoodRecord] {
        let keptIDs = Set(sanitized.map(\.id))
        return original.filter { !keptIDs.contains($0.id) }
    }

    static func hasNote(_ record: MoodRecord) -> Bool {
        !record.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Deduplication Types

private struct RecordSignature: Hashable {
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

private struct SubmissionFingerprint: Hashable {
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
