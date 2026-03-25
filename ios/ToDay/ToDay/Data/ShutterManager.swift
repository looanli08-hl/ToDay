import Foundation

@MainActor
final class ShutterManager {
    private(set) var records: [ShutterRecord] = []

    private let recordStore: any ShutterRecordStoring
    private let calendar: Calendar

    init(recordStore: any ShutterRecordStoring, calendar: Calendar = .current) {
        self.recordStore = recordStore
        self.calendar = calendar
        reloadFromStore()
    }

    // MARK: - Queries

    func records(on date: Date) -> [ShutterRecord] {
        records
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func inferredEvents(on date: Date) -> [InferredEvent] {
        records(on: date).map { $0.toInferredEvent() }
    }

    // MARK: - Mutations

    func save(_ record: ShutterRecord) {
        try? recordStore.save(record)
        records.append(record)
        records.sort { $0.createdAt > $1.createdAt }
    }

    func delete(id: UUID) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        let removed = records.remove(at: index)

        if let filename = removed.mediaFilename {
            ShutterMediaLibrary.deleteFile(filename: filename)
        }

        try? recordStore.delete(id)
    }

    func reloadFromStore() {
        records = recordStore.loadAll()
    }
}
