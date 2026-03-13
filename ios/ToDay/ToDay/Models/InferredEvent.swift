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
        id: UUID = UUID(),
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
        self.id = id
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
}
