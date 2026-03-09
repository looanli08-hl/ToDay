import Foundation

protocol MoodRecordStoring {
    func loadRecords() -> [MoodRecord]
    func saveRecords(_ records: [MoodRecord]) throws
}

struct UserDefaultsMoodRecordStore: MoodRecordStoring {
    private let defaults: UserDefaults
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard, key: String = "today.manualRecords") {
        self.defaults = defaults
        self.key = key
    }

    func loadRecords() -> [MoodRecord] {
        guard let data = defaults.data(forKey: key),
              let records = try? decoder.decode([MoodRecord].self, from: data) else {
            return []
        }

        return records.sorted { $0.createdAt > $1.createdAt }
    }

    func saveRecords(_ records: [MoodRecord]) throws {
        let data = try encoder.encode(records)
        defaults.set(data, forKey: key)
    }
}
