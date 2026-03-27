import Foundation
import SwiftData

@Model
final class DayTimelineEntity {
    @Attribute(.unique) var dateKey: String
    var date: Date
    var summary: String
    var sourceRawValue: String
    var statsData: Data
    var entriesData: Data
    var cachedAt: Date

    init(timeline: DayTimeline) {
        let normalizedDate = Calendar.current.startOfDay(for: timeline.date)
        dateKey = Self.dateKey(for: normalizedDate)
        date = normalizedDate
        summary = timeline.summary
        sourceRawValue = timeline.source.rawValue
        statsData = Self.encodeStats(timeline.stats)
        entriesData = Self.encodeEntries(timeline.entries)
        cachedAt = Date()
    }

    func update(from timeline: DayTimeline) {
        let normalizedDate = Calendar.current.startOfDay(for: timeline.date)
        dateKey = Self.dateKey(for: normalizedDate)
        date = normalizedDate
        summary = timeline.summary
        sourceRawValue = timeline.source.rawValue
        statsData = Self.encodeStats(timeline.stats)
        entriesData = Self.encodeEntries(timeline.entries)
        cachedAt = Date()
    }

    func toDayTimeline() -> DayTimeline {
        DayTimeline(
            date: date,
            summary: summary,
            source: TimelineSource(rawValue: sourceRawValue) ?? .mock,
            stats: Self.decodeStats(statsData),
            entries: Self.decodeEntries(entriesData)
        )
    }

    static func dateKey(for date: Date) -> String {
        dateKeyFormatter.string(from: Calendar.current.startOfDay(for: date))
    }

    private static func encodeStats(_ stats: [TimelineStat]) -> Data {
        (try? JSONEncoder().encode(stats)) ?? Data()
    }

    private static func decodeStats(_ data: Data) -> [TimelineStat] {
        guard !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([TimelineStat].self, from: data)) ?? []
    }

    private static func encodeEntries(_ entries: [InferredEvent]) -> Data {
        (try? JSONEncoder().encode(entries)) ?? Data()
    }

    private static func decodeEntries(_ data: Data) -> [InferredEvent] {
        guard !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([InferredEvent].self, from: data)) ?? []
    }

    private static let dateKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
