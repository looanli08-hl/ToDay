import CryptoKit
import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

protocol EventInferring {
    func inferEvents(from rawData: DayRawData, on date: Date) async throws -> [InferredEvent]
}

struct DayRawData: Sendable {
    let date: Date
    let activitySummary: ActivitySummaryData?
    let hourlyWeather: [HourlyWeather]
    let locationVisits: [LocationVisit]
    let photos: [PhotoReference]
    let heartRateSamples: [DateValueSample]
    let stepSamples: [DateValueSample]
    let sleepSamples: [SleepSample]
    let workouts: [WorkoutSample]
    let activeEnergySamples: [DateValueSample]
    let moodRecords: [MoodRecord]

    init(
        date: Date,
        activitySummary: ActivitySummaryData? = nil,
        hourlyWeather: [HourlyWeather] = [],
        locationVisits: [LocationVisit] = [],
        photos: [PhotoReference] = [],
        heartRateSamples: [DateValueSample] = [],
        stepSamples: [DateValueSample] = [],
        sleepSamples: [SleepSample] = [],
        workouts: [WorkoutSample] = [],
        activeEnergySamples: [DateValueSample] = [],
        moodRecords: [MoodRecord] = []
    ) {
        self.date = date
        self.activitySummary = activitySummary
        self.hourlyWeather = hourlyWeather
        self.locationVisits = locationVisits
        self.photos = photos
        self.heartRateSamples = heartRateSamples
        self.stepSamples = stepSamples
        self.sleepSamples = sleepSamples
        self.workouts = workouts
        self.activeEnergySamples = activeEnergySamples
        self.moodRecords = moodRecords
    }
}

struct ActivitySummaryData: Sendable {
    let activeEnergyBurned: Double
    let activeEnergyGoal: Double
    let exerciseMinutes: Double
    let exerciseGoal: Double
    let standHours: Int
    let standGoal: Int
}

struct DateValueSample: Identifiable, Hashable, Sendable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let value: Double

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        value: Double
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.value = value
    }
}

struct SleepSample: Identifiable, Hashable, Sendable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let stage: SleepStage

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        stage: SleepStage
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.stage = stage
    }
}

enum SleepStage: String, Codable, Hashable, Sendable {
    case awake
    case rem
    case light
    case deep
    case unknown
}

struct SleepStageSegment: Codable, Hashable, Sendable {
    let start: Date
    let end: Date
    let stage: SleepStage
}

struct WorkoutSample: Identifiable, Hashable, Sendable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let activityType: UInt
    let activeEnergy: Double?
    let distance: Double?

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        activityType: UInt,
        activeEnergy: Double? = nil,
        distance: Double? = nil
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.activityType = activityType
        self.activeEnergy = activeEnergy
        self.distance = distance
    }

    var displayName: String {
        #if canImport(HealthKit)
        HKWorkoutActivityType(rawValue: activityType)?.todayDisplayName ?? "训练"
        #else
        "训练"
        #endif
    }
}

struct HourlyWeather: Sendable, Codable, Hashable {
    let date: Date
    let temperature: Double
    let condition: WeatherCondition
    let symbolName: String
}

enum WeatherCondition: String, Codable, Sendable {
    case clear
    case cloudy
    case rain
    case snow
    case fog
    case wind
    case thunderstorm
    case unknown
}

struct CoordinateValue: Sendable, Codable, Hashable {
    let latitude: Double
    let longitude: Double
}

struct LocationVisit: Identifiable, Sendable, Codable, Hashable {
    let id: UUID
    let coordinate: CoordinateValue
    let arrivalDate: Date
    let departureDate: Date
    let placeName: String?

    init(
        id: UUID = UUID(),
        coordinate: CoordinateValue,
        arrivalDate: Date,
        departureDate: Date,
        placeName: String? = nil
    ) {
        self.id = id
        self.coordinate = coordinate
        self.arrivalDate = arrivalDate
        self.departureDate = departureDate
        self.placeName = placeName
    }
}

struct PhotoReference: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let creationDate: Date
    let location: CoordinateValue?
    let pixelWidth: Int
    let pixelHeight: Int
}

enum EventKind: String, Codable, CaseIterable, Sendable {
    case sleep
    case workout
    case commute
    case activeWalk
    case quietTime
    case userAnnotated
    case mood
    case shutter
    case screenTime
    case spending
}

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

struct InferredEvent: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let kind: EventKind
    let startDate: Date
    let endDate: Date
    let confidence: EventConfidence
    let isLive: Bool
    let displayName: String
    let userAnnotation: String?
    let subtitle: String?
    let associatedMetrics: EventMetrics?
    let photoAttachments: [MoodPhotoAttachment]

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

    // MARK: - Convenience Copying

    func withInterval(_ interval: DateInterval) -> InferredEvent {
        InferredEvent(
            id: id, kind: kind,
            startDate: interval.start, endDate: interval.end,
            confidence: confidence, isLive: isLive,
            displayName: displayName, userAnnotation: userAnnotation,
            subtitle: subtitle, associatedMetrics: associatedMetrics,
            photoAttachments: photoAttachments
        )
    }

    func withSubtitle(_ newSubtitle: String?) -> InferredEvent {
        InferredEvent(
            id: id, kind: kind,
            startDate: startDate, endDate: endDate,
            confidence: confidence, isLive: isLive,
            displayName: displayName, userAnnotation: userAnnotation,
            subtitle: newSubtitle, associatedMetrics: associatedMetrics,
            photoAttachments: photoAttachments
        )
    }

    func withMetrics(_ newMetrics: EventMetrics?) -> InferredEvent {
        InferredEvent(
            id: id, kind: kind,
            startDate: startDate, endDate: endDate,
            confidence: confidence, isLive: isLive,
            displayName: displayName, userAnnotation: userAnnotation,
            subtitle: subtitle, associatedMetrics: newMetrics,
            photoAttachments: photoAttachments
        )
    }

    func applyingAnnotation(_ annotation: String) -> InferredEvent {
        InferredEvent(
            id: id, kind: .userAnnotated,
            startDate: startDate, endDate: endDate,
            confidence: .high, isLive: isLive,
            displayName: displayName, userAnnotation: annotation,
            subtitle: subtitle, associatedMetrics: associatedMetrics,
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

struct DayTimeline: Codable, Sendable {
    let date: Date
    let summary: String
    let source: TimelineSource
    let stats: [TimelineStat]
    let entries: [InferredEvent]
}

enum TimelineSource: String, Codable, Sendable {
    case mock
    case healthKit

    var badgeTitle: String {
        switch self {
        case .mock:
            return "模拟"
        case .healthKit:
            return "HealthKit"
        }
    }

    var helperText: String {
        switch self {
        case .mock:
            return "当前是模拟模式，适合先把记录、回看和付费路径做顺。"
        case .healthKit:
            return "正在读取这台设备上的 HealthKit 数据。"
        }
    }
}

struct TimelineStat: Identifiable, Codable, Sendable {
    let id: String
    let title: String
    let value: String

    init(id: String? = nil, title: String, value: String) {
        self.id = id ?? title
        self.title = title
        self.value = value
    }
}

#if canImport(HealthKit)
private extension HKWorkoutActivityType {
    var todayDisplayName: String {
        switch self {
        case .running:
            return "跑步"
        case .walking:
            return "走路"
        case .hiking:
            return "徒步"
        case .cycling:
            return "骑行"
        case .traditionalStrengthTraining, .functionalStrengthTraining:
            return "力量训练"
        case .mindAndBody:
            return "身心训练"
        case .swimming:
            return "游泳"
        case .yoga:
            return "瑜伽"
        default:
            return "训练"
        }
    }
}
#endif
