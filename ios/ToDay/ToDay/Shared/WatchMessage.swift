import Foundation

enum WatchMessage: Codable {
    case pointRecord(MoodRecord)
    case startSession(MoodRecord)
    case endSession(recordID: UUID, endedAt: Date)

    private enum CodingKeys: String, CodingKey {
        case type
        case record
        case recordID
        case endedAt
    }

    private enum MessageType: String, Codable {
        case pointRecord
        case startSession
        case endSession
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
        }
    }
}

struct PhoneContext: Codable {
    let activeSession: MoodRecord?
}
