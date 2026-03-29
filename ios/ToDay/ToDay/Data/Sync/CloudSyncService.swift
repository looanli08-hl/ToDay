import Foundation
import SwiftData

/// Pushes local data to Supabase for cross-device access (web dashboard).
/// Runs on app foreground and after background timeline generation.
final class CloudSyncService: @unchecked Sendable {

    static let shared = CloudSyncService()

    private let lastSyncKey = "today.cloud.lastSync"

    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: - Public

    /// Sync all pending data to Supabase.
    func syncAll(modelContainer: ModelContainer) async {
        let context = ModelContext(modelContainer)

        await syncTimelineEvents(context: context)
        await syncMoodRecords(context: context)

        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastSyncKey)
        print("[CloudSync] Sync completed at \(Date())")
    }

    // MARK: - Timeline Events

    private func syncTimelineEvents(context: ModelContext) async {
        do {
            let descriptor = FetchDescriptor<DayTimelineEntity>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            let timelines = try context.fetch(descriptor)

            for timeline in timelines.prefix(7) {
                let dayTimeline = timeline.toDayTimeline()

                for event in dayTimeline.entries {
                    let dataPoint = DataPointInsert(
                        source: "iphone",
                        type: event.kind.rawValue,
                        value: TimelineEventValue(
                            displayName: event.displayName,
                            kind: event.kind.rawValue,
                            confidence: event.confidence.rawValue,
                            startDate: iso8601.string(from: event.startDate),
                            endDate: iso8601.string(from: event.endDate),
                            duration: event.duration,
                            subtitle: event.subtitle
                        ),
                        timestamp: iso8601.string(from: event.startDate)
                    )

                    try await SupabaseConfig.client
                        .from("data_points")
                        .insert(dataPoint)
                        .execute()
                }
            }
        } catch {
            print("[CloudSync] Timeline sync failed: \(error)")
        }
    }

    // MARK: - Mood Records

    private func syncMoodRecords(context: ModelContext) async {
        do {
            let descriptor = FetchDescriptor<MoodRecordEntity>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            let entities = try context.fetch(descriptor)

            for entity in entities.prefix(50) {
                let record = entity.toMoodRecord()

                let dataPoint = DataPointInsert(
                    source: "iphone",
                    type: "mood",
                    value: MoodValue(
                        mood: record.mood.rawValue,
                        emoji: record.mood.emoji,
                        note: record.note,
                        captureMode: record.captureMode.rawValue,
                        isTracking: record.isTracking
                    ),
                    timestamp: iso8601.string(from: record.createdAt)
                )

                try await SupabaseConfig.client
                    .from("data_points")
                    .insert(dataPoint)
                    .execute()
            }
        } catch {
            print("[CloudSync] Mood sync failed: \(error)")
        }
    }
}

// MARK: - Encodable Insert Models

/// Top-level row inserted into `data_points`.
private struct DataPointInsert<V: Encodable>: Encodable {
    let source: String
    let type: String
    let value: V
    let timestamp: String
}

/// JSON value for a timeline event.
private struct TimelineEventValue: Encodable {
    let displayName: String
    let kind: String
    let confidence: Int
    let startDate: String
    let endDate: String
    let duration: TimeInterval
    let subtitle: String?
}

/// JSON value for a mood record.
private struct MoodValue: Encodable {
    let mood: String
    let emoji: String
    let note: String
    let captureMode: String
    let isTracking: Bool
}
