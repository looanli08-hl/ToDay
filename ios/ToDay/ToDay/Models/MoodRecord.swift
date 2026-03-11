import Foundation

struct MoodRecord: Identifiable, Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case mood
        case note
        case createdAt
        case endedAt
        case isTracking
        case captureMode
        case photoAttachments
    }

    enum CaptureMode: String, Codable {
        case point
        case session
    }

    enum Mood: String, CaseIterable, Identifiable, Codable {
        case happy = "开心"
        case calm = "平静"
        case tired = "疲惫"
        case irritated = "烦躁"
        case focused = "专注"
        case zoning = "放空"

        var id: String { rawValue }

        var emoji: String {
            switch self {
            case .happy: return "😊"
            case .calm: return "🌿"
            case .tired: return "😴"
            case .irritated: return "😤"
            case .focused: return "🎯"
            case .zoning: return "☁️"
            }
        }

        var timelineKind: TimelineEntry.Kind {
            switch self {
            case .happy, .calm: return .mood
            case .tired, .zoning: return .pause
            case .irritated: return .mood
            case .focused: return .focus
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

    func displayTimeLabel(referenceDate: Date = Date(), calendar: Calendar = .current) -> String {
        toTimelineEntry(referenceDate: referenceDate, calendar: calendar).moment.label
    }

    func toTimelineEntry(referenceDate: Date = Date(), calendar: Calendar = .current) -> TimelineEntry {
        let resolvedEndDate = displayEndDate(referenceDate: referenceDate, calendar: calendar)
        let durationMinutes = max(Int(resolvedEndDate.timeIntervalSince(createdAt) / 60), 1)
        let detailPrefix = note.isEmpty
            ? "\(mood.emoji) \(mood.rawValue)"
            : "\(mood.emoji) \(mood.rawValue) · \(note)"

        let detail: String
        if isOngoing {
            detail = "\(detailPrefix) · 正在进行，已持续 \(durationDescription(minutes: durationMinutes))"
        } else if captureMode == .session {
            detail = "\(detailPrefix) · 持续 \(durationDescription(minutes: durationMinutes))"
        } else {
            detail = detailPrefix
        }

        let startMinute = minuteOfDay(for: createdAt, calendar: calendar)
        let endMinute = minuteOfDay(for: resolvedEndDate, calendar: calendar)
        let boundedEndMinute = max(endMinute, startMinute + 1)
        let moment: TimelineMoment

        if isOngoing {
            moment = .active(startMinuteOfDay: startMinute, currentMinuteOfDay: boundedEndMinute)
        } else if captureMode == .session {
            moment = .range(startMinuteOfDay: startMinute, endMinuteOfDay: boundedEndMinute)
        } else {
            moment = .point(at: startMinute)
        }

        return TimelineEntry(
            id: id.uuidString,
            title: mood.rawValue,
            detail: detail,
            moment: moment,
            kind: mood.timelineKind,
            durationMinutes: captureMode == .session || isOngoing ? durationMinutes : nil,
            isLive: isOngoing,
            photoAttachments: photoAttachments
        )
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        mood = try container.decode(Mood.self, forKey: .mood)
        note = try container.decode(String.self, forKey: .note)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        isTracking = try container.decodeIfPresent(Bool.self, forKey: .isTracking) ?? false
        photoAttachments = try container.decodeIfPresent([MoodPhotoAttachment].self, forKey: .photoAttachments) ?? []
        let decodedCaptureMode = try container.decodeIfPresent(CaptureMode.self, forKey: .captureMode)
        if let decodedCaptureMode {
            captureMode = decodedCaptureMode
        } else if isTracking {
            captureMode = .session
        } else if let endedAt, endedAt > createdAt {
            captureMode = .session
        } else {
            captureMode = .point
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(mood, forKey: .mood)
        try container.encode(note, forKey: .note)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(endedAt, forKey: .endedAt)
        try container.encode(isTracking, forKey: .isTracking)
        try container.encode(captureMode, forKey: .captureMode)
        try container.encode(photoAttachments, forKey: .photoAttachments)
    }

    private func minuteOfDay(for date: Date, calendar: Calendar) -> Int {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return (hour * 60) + minute
    }

    private func durationDescription(minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let remainder = minutes % 60

            if remainder == 0 {
                return "\(hours) 小时"
            }

            return "\(hours) 小时 \(remainder) 分钟"
        }

        return "\(minutes) 分钟"
    }
}
