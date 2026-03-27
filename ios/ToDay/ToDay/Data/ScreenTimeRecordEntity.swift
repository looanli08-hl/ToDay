import Foundation
import SwiftData

@Model
final class ScreenTimeRecordEntity {
    @Attribute(.unique) var id: UUID
    var dateKey: String
    var totalScreenTime: Double
    var appUsagesData: Data
    var pickupCount: Int

    init(record: ScreenTimeRecord) {
        id = record.id
        dateKey = record.dateKey
        totalScreenTime = record.totalScreenTime
        appUsagesData = (try? JSONEncoder().encode(record.appUsages)) ?? Data()
        pickupCount = record.pickupCount
    }

    func update(from record: ScreenTimeRecord) {
        dateKey = record.dateKey
        totalScreenTime = record.totalScreenTime
        appUsagesData = (try? JSONEncoder().encode(record.appUsages)) ?? Data()
        pickupCount = record.pickupCount
    }

    func toScreenTimeRecord() -> ScreenTimeRecord {
        let appUsages = (try? JSONDecoder().decode([AppUsage].self, from: appUsagesData)) ?? []
        return ScreenTimeRecord(
            id: id,
            dateKey: dateKey,
            totalScreenTime: totalScreenTime,
            appUsages: appUsages,
            pickupCount: pickupCount
        )
    }
}
