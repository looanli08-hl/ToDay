import Foundation

enum SpendingCategory: String, Codable, CaseIterable, Sendable {
    case food
    case transport
    case shopping
    case entertainment
    case daily
    case health
    case education
    case other

    var displayName: String {
        switch self {
        case .food:          return "餐饮"
        case .transport:     return "交通"
        case .shopping:      return "购物"
        case .entertainment: return "娱乐"
        case .daily:         return "日用"
        case .health:        return "医疗"
        case .education:     return "教育"
        case .other:         return "其他"
        }
    }

    var iconName: String {
        switch self {
        case .food:          return "fork.knife"
        case .transport:     return "car.fill"
        case .shopping:      return "bag.fill"
        case .entertainment: return "gamecontroller.fill"
        case .daily:         return "house.fill"
        case .health:        return "heart.fill"
        case .education:     return "book.fill"
        case .other:         return "ellipsis.circle.fill"
        }
    }
}

struct SpendingRecord: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let amount: Double
    let category: SpendingCategory
    var note: String?
    let createdAt: Date
    var latitude: Double?
    var longitude: Double?

    init(
        id: UUID = UUID(),
        amount: Double,
        category: SpendingCategory,
        note: String? = nil,
        createdAt: Date = Date(),
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = id
        self.amount = amount
        self.category = category
        self.note = note
        self.createdAt = createdAt
        self.latitude = latitude
        self.longitude = longitude
    }

    func toInferredEvent() -> InferredEvent {
        let displayName = "\(category.displayName) ¥\(String(format: "%.0f", amount))"
        var metrics = EventMetrics()
        if let lat = latitude, let lon = longitude {
            metrics.location = LocationVisit(
                coordinate: CoordinateValue(latitude: lat, longitude: lon),
                arrivalDate: createdAt,
                departureDate: createdAt
            )
        }
        return InferredEvent(
            id: id,
            kind: .spending,
            startDate: createdAt,
            endDate: createdAt,
            confidence: .high,
            displayName: displayName,
            subtitle: note,
            associatedMetrics: metrics
        )
    }
}
