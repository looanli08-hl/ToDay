import Foundation

/// Manages CRUD for spending records. Owned by TodayViewModel.
@MainActor
final class SpendingManager {
    private(set) var records: [SpendingRecord] = []

    private let recordStore: any SpendingRecordStoring
    private let calendar: Calendar

    init(recordStore: any SpendingRecordStoring, calendar: Calendar = .current) {
        self.recordStore = recordStore
        self.calendar = calendar
        reloadFromStore()
    }

    // MARK: - Queries

    func records(on date: Date) -> [SpendingRecord] {
        records
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func todayTotal(on date: Date) -> Double {
        records(on: date).reduce(0) { $0 + $1.amount }
    }

    // MARK: - Mutations

    func addRecord(_ record: SpendingRecord) {
        records.insert(record, at: 0)
        records.sort { $0.createdAt > $1.createdAt }
        persistRecord(record)
    }

    func removeRecord(id: UUID) {
        records.removeAll { $0.id == id }
        try? recordStore.delete(id)
    }

    func reloadFromStore() {
        records = recordStore.loadAll()
    }

    // MARK: - Private

    private func persistRecord(_ record: SpendingRecord) {
        try? recordStore.save(record)
    }
}
