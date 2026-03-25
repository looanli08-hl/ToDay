import Foundation
import SwiftData

@Model
final class ShutterRecordEntity {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var typeRawValue: String
    var textContent: String?
    var mediaFilename: String?
    var voiceTranscript: String?
    var duration: Double?
    var latitude: Double?
    var longitude: Double?
    var echoConfigData: Data

    init(record: ShutterRecord) {
        id = record.id
        createdAt = record.createdAt
        typeRawValue = record.type.rawValue
        textContent = record.textContent
        mediaFilename = record.mediaFilename
        voiceTranscript = record.voiceTranscript
        duration = record.duration
        latitude = record.latitude
        longitude = record.longitude
        echoConfigData = (try? JSONEncoder().encode(record.echoConfig)) ?? Data()
    }

    func update(from record: ShutterRecord) {
        createdAt = record.createdAt
        typeRawValue = record.type.rawValue
        textContent = record.textContent
        mediaFilename = record.mediaFilename
        voiceTranscript = record.voiceTranscript
        duration = record.duration
        latitude = record.latitude
        longitude = record.longitude
        echoConfigData = (try? JSONEncoder().encode(record.echoConfig)) ?? Data()
    }

    func toShutterRecord() -> ShutterRecord {
        let echoConfig = (try? JSONDecoder().decode(EchoConfig.self, from: echoConfigData)) ?? .default
        return ShutterRecord(
            id: id,
            createdAt: createdAt,
            type: ShutterType(rawValue: typeRawValue) ?? .text,
            textContent: textContent,
            mediaFilename: mediaFilename,
            voiceTranscript: voiceTranscript,
            duration: duration,
            latitude: latitude,
            longitude: longitude,
            echoConfig: echoConfig
        )
    }
}
