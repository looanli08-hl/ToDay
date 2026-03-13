import CryptoKit
import Foundation

/// 推理出的事件类型
enum EventKind: String, Codable, CaseIterable, Sendable {
    case sleep
    case workout
    case commute
    case activeWalk
    case quietTime
    case userAnnotated
    case mood
}

/// 置信度等级
enum EventConfidence: Int, Codable, Comparable, Sendable {
    case low
    case medium
    case high

    static func < (lhs: EventConfidence, rhs: EventConfidence) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct HeartRateSample: Codable, Hashable, Sendable {
    let date: Date
    let value: Double
}

/// 事件关联的数据指标
struct EventMetrics: Codable, Hashable, Sendable {
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    var minHeartRate: Double?
    var heartRateSamples: [HeartRateSample]?
    var weather: HourlyWeather?
    var location: LocationVisit?
    var photos: [PhotoReference]?
    var sleepStages: [SleepStageSegment]?
    var stepCount: Int?
    var activeEnergy: Double?
    var distance: Double?
    var workoutType: String?
}

/// 推理出的单个事件
struct InferredEvent: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let kind: EventKind
    let startDate: Date
    let endDate: Date
    let confidence: EventConfidence
    let isLive: Bool
    var displayName: String
    var userAnnotation: String?
    var subtitle: String?
    var associatedMetrics: EventMetrics?
    var photoAttachments: [MoodPhotoAttachment]

    init(
        id: UUID? = nil,
        kind: EventKind,
        startDate: Date,
        endDate: Date,
        confidence: EventConfidence,
        isLive: Bool = false,
        displayName: String,
        userAnnotation: String? = nil,
        subtitle: String? = nil,
        associatedMetrics: EventMetrics? = nil,
        photoAttachments: [MoodPhotoAttachment] = []
    ) {
        self.id = id ?? Self.derivedID(
            kind: kind,
            startDate: startDate,
            endDate: endDate,
            displayName: displayName
        )
        self.kind = kind
        self.startDate = startDate
        self.endDate = endDate
        self.confidence = confidence
        self.isLive = isLive
        self.displayName = displayName
        self.userAnnotation = userAnnotation
        self.subtitle = subtitle
        self.associatedMetrics = associatedMetrics
        self.photoAttachments = photoAttachments
    }

    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    var resolvedName: String {
        userAnnotation ?? displayName
    }

    func applyingAnnotation(_ annotation: String) -> InferredEvent {
        InferredEvent(
            id: id,
            kind: .userAnnotated,
            startDate: startDate,
            endDate: endDate,
            confidence: .high,
            isLive: isLive,
            displayName: displayName,
            userAnnotation: annotation,
            subtitle: subtitle,
            associatedMetrics: associatedMetrics,
            photoAttachments: photoAttachments
        )
    }

    private static func derivedID(
        kind: EventKind,
        startDate: Date,
        endDate: Date,
        displayName: String
    ) -> UUID {
        let rawValue = [
            kind.rawValue,
            String(startDate.timeIntervalSince1970),
            String(endDate.timeIntervalSince1970),
            displayName
        ].joined(separator: "|")
        let digest = SHA256.hash(data: Data(rawValue.utf8))
        let bytes = Array(digest.prefix(16))
        let uuid = uuid_t(
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: uuid)
    }
}
