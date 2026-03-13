import Foundation

struct MoodRecord: Identifiable, Codable {
    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id
        case mood
        case note
        case createdAt
        case endedAt
        case isTracking
        case captureMode
        case photoAttachments
    }

    static let schemaVersion = 1

    enum CaptureMode: String, Codable {
        case point
        case session
    }

    enum Mood: String, CaseIterable, Identifiable, Codable {
        case happy = "开心"
        case calm = "平静"
        case focused = "专注"
        case grateful = "感恩"
        case excited = "兴奋"
        case tired = "疲惫"
        case anxious = "焦虑"
        case sad = "难过"
        case irritated = "烦躁"
        case bored = "无聊"
        case sleepy = "困倦"
        case satisfied = "满足"

        var id: String { rawValue }

        var emoji: String {
            switch self {
            case .happy: return "😊"
            case .calm: return "🌿"
            case .focused: return "🎯"
            case .grateful: return "🙏"
            case .excited: return "🤩"
            case .tired: return "😴"
            case .anxious: return "😰"
            case .sad: return "😔"
            case .irritated: return "😤"
            case .bored: return "🥱"
            case .sleepy: return "😪"
            case .satisfied: return "☺️"
            }
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            if let mood = Self(storedValue: rawValue) {
                self = mood
                return
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "不支持的 Mood 值：\(rawValue)"
            )
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }

        init?(storedValue: String) {
            switch storedValue {
            case Self.happy.rawValue:
                self = .happy
            case Self.calm.rawValue:
                self = .calm
            case Self.focused.rawValue:
                self = .focused
            case Self.grateful.rawValue:
                self = .grateful
            case Self.excited.rawValue:
                self = .excited
            case Self.tired.rawValue:
                self = .tired
            case Self.anxious.rawValue:
                self = .anxious
            case Self.sad.rawValue:
                self = .sad
            case Self.irritated.rawValue:
                self = .irritated
            case Self.bored.rawValue, "放空":
                self = .bored
            case Self.sleepy.rawValue:
                self = .sleepy
            case Self.satisfied.rawValue:
                self = .satisfied
            default:
                return nil
            }
        }
    }

    let id: UUID
    let mood: Mood
    let note: String
    let createdAt: Date
    let endedAt: Date?
    let isTracking: Bool
    let captureMode: CaptureMode
    let photoAttachments: [MoodPhotoAttachment]

    init(
        id: UUID = UUID(),
        mood: Mood,
        note: String = "",
        createdAt: Date = Date(),
        endedAt: Date? = nil,
        isTracking: Bool = false,
        captureMode: CaptureMode? = nil,
        photoAttachments: [MoodPhotoAttachment] = []
    ) {
        let resolvedCaptureMode = captureMode ?? {
            if isTracking { return .session }
            if let endedAt, endedAt > createdAt { return .session }
            return .point
        }()

        self.id = id
        self.mood = mood
        self.note = note
        self.createdAt = createdAt
        self.captureMode = resolvedCaptureMode
        self.endedAt = endedAt ?? (resolvedCaptureMode == .session ? (isTracking ? nil : createdAt) : createdAt)
        self.isTracking = resolvedCaptureMode == .session ? isTracking : false
        self.photoAttachments = photoAttachments
    }

    static func active(
        id: UUID = UUID(),
        mood: Mood,
        note: String = "",
        createdAt: Date = Date(),
        photoAttachments: [MoodPhotoAttachment] = []
    ) -> MoodRecord {
        MoodRecord(
            id: id,
            mood: mood,
            note: note,
            createdAt: createdAt,
            endedAt: nil,
            isTracking: true,
            captureMode: .session,
            photoAttachments: photoAttachments
        )
    }

    var isOngoing: Bool {
        captureMode == .session && isTracking && endedAt == nil
    }

    func completed(at date: Date) -> MoodRecord {
        MoodRecord(
            id: id,
            mood: mood,
            note: note,
            createdAt: createdAt,
            endedAt: max(date, createdAt),
            isTracking: false,
            captureMode: .session,
            photoAttachments: photoAttachments
        )
    }

    func displayEndDate(referenceDate: Date = Date(), calendar: Calendar = .current) -> Date {
        if isOngoing && calendar.isDate(createdAt, inSameDayAs: referenceDate) {
            return max(referenceDate, createdAt)
        }

        return endedAt ?? createdAt
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0

        switch version {
        case 0:
            id = try container.decode(UUID.self, forKey: .id)
            mood = try container.decode(Mood.self, forKey: .mood)
            note = try container.decode(String.self, forKey: .note)
            createdAt = try container.decode(Date.self, forKey: .createdAt)
            endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
            isTracking = try container.decodeIfPresent(Bool.self, forKey: .isTracking) ?? false
            photoAttachments = try container.decodeIfPresent([MoodPhotoAttachment].self, forKey: .photoAttachments) ?? []

            if let decodedCaptureMode = try container.decodeIfPresent(CaptureMode.self, forKey: .captureMode) {
                captureMode = decodedCaptureMode
            } else if isTracking {
                captureMode = .session
            } else if let endedAt, endedAt > createdAt {
                captureMode = .session
            } else {
                captureMode = .point
            }
        case Self.schemaVersion:
            id = try container.decode(UUID.self, forKey: .id)
            mood = try container.decode(Mood.self, forKey: .mood)
            note = try container.decode(String.self, forKey: .note)
            createdAt = try container.decode(Date.self, forKey: .createdAt)
            endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
            isTracking = try container.decode(Bool.self, forKey: .isTracking)
            captureMode = try container.decode(CaptureMode.self, forKey: .captureMode)
            photoAttachments = try container.decodeIfPresent([MoodPhotoAttachment].self, forKey: .photoAttachments) ?? []
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "不支持的 MoodRecord 数据版本：\(version)"
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.schemaVersion, forKey: .schemaVersion)
        try container.encode(id, forKey: .id)
        try container.encode(mood, forKey: .mood)
        try container.encode(note, forKey: .note)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(endedAt, forKey: .endedAt)
        try container.encode(isTracking, forKey: .isTracking)
        try container.encode(captureMode, forKey: .captureMode)
        try container.encode(photoAttachments, forKey: .photoAttachments)
    }
}
