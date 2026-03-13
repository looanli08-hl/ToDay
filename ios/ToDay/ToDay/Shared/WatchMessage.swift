import Foundation

enum WatchMessage: Codable {
    case pointRecord(MoodRecord)
    case startSession(MoodRecord)
    case endSession(recordID: UUID, endedAt: Date)
    case annotation(eventID: UUID, title: String, timestamp: Date)
    case currentEventUpdate(CurrentEventSnapshot)
    case moodRecord(mood: String, timestamp: Date)
    case complicationRefresh

    private enum CodingKeys: String, CodingKey {
        case type
        case record
        case recordID
        case endedAt
        case eventID
        case title
        case timestamp
        case snapshot
        case mood
    }

    private enum MessageType: String, Codable {
        case pointRecord
        case startSession
        case endSession
        case annotation
        case currentEventUpdate
        case moodRecord
        case complicationRefresh
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MessageType.self, forKey: .type)

        switch type {
        case .pointRecord:
            self = .pointRecord(try container.decode(MoodRecord.self, forKey: .record))
        case .startSession:
            self = .startSession(try container.decode(MoodRecord.self, forKey: .record))
        case .endSession:
            self = .endSession(
                recordID: try container.decode(UUID.self, forKey: .recordID),
                endedAt: try container.decode(Date.self, forKey: .endedAt)
            )
        case .annotation:
            self = .annotation(
                eventID: try container.decode(UUID.self, forKey: .eventID),
                title: try container.decode(String.self, forKey: .title),
                timestamp: try container.decode(Date.self, forKey: .timestamp)
            )
        case .currentEventUpdate:
            self = .currentEventUpdate(try container.decode(CurrentEventSnapshot.self, forKey: .snapshot))
        case .moodRecord:
            self = .moodRecord(
                mood: try container.decode(String.self, forKey: .mood),
                timestamp: try container.decode(Date.self, forKey: .timestamp)
            )
        case .complicationRefresh:
            self = .complicationRefresh
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .pointRecord(record):
            try container.encode(MessageType.pointRecord, forKey: .type)
            try container.encode(record, forKey: .record)
        case let .startSession(record):
            try container.encode(MessageType.startSession, forKey: .type)
            try container.encode(record, forKey: .record)
        case let .endSession(recordID, endedAt):
            try container.encode(MessageType.endSession, forKey: .type)
            try container.encode(recordID, forKey: .recordID)
            try container.encode(endedAt, forKey: .endedAt)
        case let .annotation(eventID, title, timestamp):
            try container.encode(MessageType.annotation, forKey: .type)
            try container.encode(eventID, forKey: .eventID)
            try container.encode(title, forKey: .title)
            try container.encode(timestamp, forKey: .timestamp)
        case let .currentEventUpdate(snapshot):
            try container.encode(MessageType.currentEventUpdate, forKey: .type)
            try container.encode(snapshot, forKey: .snapshot)
        case let .moodRecord(mood, timestamp):
            try container.encode(MessageType.moodRecord, forKey: .type)
            try container.encode(mood, forKey: .mood)
            try container.encode(timestamp, forKey: .timestamp)
        case .complicationRefresh:
            try container.encode(MessageType.complicationRefresh, forKey: .type)
        }
    }
}

struct PhoneContext: Codable {
    let activeSession: MoodRecord?
    let currentEvent: CurrentEventSnapshot?
    let currentEventID: UUID?
}
