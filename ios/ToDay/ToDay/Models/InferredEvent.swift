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

/// 事件关联的数据指标
struct EventMetrics: Equatable, Hashable, Sendable {
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    var minHeartRate: Double?
    var heartRateSamples: [(date: Date, value: Double)]?
    var stepCount: Int?
    var activeEnergy: Double?
    var distance: Double?
    var workoutType: String?

    static func == (lhs: EventMetrics, rhs: EventMetrics) -> Bool {
        lhs.averageHeartRate == rhs.averageHeartRate &&
        lhs.maxHeartRate == rhs.maxHeartRate &&
        lhs.minHeartRate == rhs.minHeartRate &&
        lhs.stepCount == rhs.stepCount &&
        lhs.activeEnergy == rhs.activeEnergy &&
        lhs.distance == rhs.distance &&
        lhs.workoutType == rhs.workoutType &&
        heartRateSamplesEqual(lhs.heartRateSamples, rhs.heartRateSamples)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(averageHeartRate)
        hasher.combine(maxHeartRate)
        hasher.combine(minHeartRate)
        hasher.combine(stepCount)
        hasher.combine(activeEnergy)
        hasher.combine(distance)
        hasher.combine(workoutType)
    }

    private static func heartRateSamplesEqual(
        _ lhs: [(date: Date, value: Double)]?,
        _ rhs: [(date: Date, value: Double)]?
    ) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (left?, right?):
            guard left.count == right.count else { return false }
            return zip(left, right).allSatisfy { lhsSample, rhsSample in
                lhsSample.date == rhsSample.date && lhsSample.value == rhsSample.value
            }
        default:
            return false
        }
    }
}

/// 推理出的单个事件
struct InferredEvent: Identifiable, Hashable, Sendable {
    let id: UUID
    let kind: EventKind
    let startDate: Date
    let endDate: Date
    let confidence: EventConfidence
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
