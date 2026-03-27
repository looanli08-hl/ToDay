import Foundation
import SwiftData

@Model
final class SpendingRecordEntity {
    @Attribute(.unique) var id: UUID
    var amount: Double
    var categoryRawValue: String
    var note: String?
    var createdAt: Date
    var latitude: Double?
    var longitude: Double?

    init(record: SpendingRecord) {
        id = record.id
        amount = record.amount
        categoryRawValue = record.category.rawValue
        note = record.note
        createdAt = record.createdAt
        latitude = record.latitude
        longitude = record.longitude
    }

    func update(from record: SpendingRecord) {
        amount = record.amount
        categoryRawValue = record.category.rawValue
        note = record.note
        createdAt = record.createdAt
        latitude = record.latitude
        longitude = record.longitude
    }

    func toSpendingRecord() -> SpendingRecord {
        SpendingRecord(
            id: id,
            amount: amount,
            category: SpendingCategory(rawValue: categoryRawValue) ?? .other,
            note: note,
            createdAt: createdAt,
            latitude: latitude,
            longitude: longitude
        )
    }
}
