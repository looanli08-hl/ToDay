import Foundation

enum ShutterType: String, Codable, CaseIterable, Sendable {
    case text
    case voice
    case photo
    case video
}

enum EchoFrequency: String, Codable, CaseIterable, Sendable {
    case high    // 1d, 3d, 7d, 30d
    case medium  // 3d, 7d, 30d
    case low     // 7d, 30d
    case off

    var reminderDays: [Int] {
        switch self {
        case .high:   return [1, 3, 7, 30]
        case .medium: return [3, 7, 30]
        case .low:    return [7, 30]
        case .off:    return []
        }
    }
}

struct EchoConfig: Codable, Hashable, Sendable {
    var frequency: EchoFrequency
    var customRemindAt: Date?

    static let `default` = EchoConfig(frequency: .medium, customRemindAt: nil)
}

struct ShutterRecord: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let createdAt: Date
    let type: ShutterType
    var textContent: String?
    var mediaFilename: String?
    var voiceTranscript: String?
    var duration: TimeInterval?
    var latitude: Double?
    var longitude: Double?
    var echoConfig: EchoConfig

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        type: ShutterType,
        textContent: String? = nil,
        mediaFilename: String? = nil,
        voiceTranscript: String? = nil,
        duration: TimeInterval? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        echoConfig: EchoConfig = .default
    ) {
        self.id = id
        self.createdAt = createdAt
        self.type = type
        self.textContent = textContent
        self.mediaFilename = mediaFilename
        self.voiceTranscript = voiceTranscript
        self.duration = duration
        self.latitude = latitude
        self.longitude = longitude
        self.echoConfig = echoConfig
    }

    /// Display text for timeline: content preview or type label
    var displayText: String {
        if let text = textContent, !text.isEmpty {
            return String(text.prefix(50))
        }
        if let transcript = voiceTranscript, !transcript.isEmpty {
            return String(transcript.prefix(50))
        }
        switch type {
        case .text:  return "文字记录"
        case .voice: return "语音记录"
        case .photo: return "照片"
        case .video: return "视频"
        }
    }

    /// Convert to InferredEvent for timeline integration
    func toInferredEvent() -> InferredEvent {
        let endDate = createdAt.addingTimeInterval(duration ?? 0)
        var metrics = EventMetrics()
        if let lat = latitude, let lon = longitude {
            metrics.location = LocationVisit(
                coordinate: CoordinateValue(latitude: lat, longitude: lon),
                arrivalDate: createdAt,
                departureDate: endDate
            )
        }
        return InferredEvent(
            id: id,
            kind: .shutter,
            startDate: createdAt,
            endDate: endDate,
            confidence: .high,
            displayName: displayText,
            subtitle: type.rawValue,
            associatedMetrics: metrics
        )
    }
}
