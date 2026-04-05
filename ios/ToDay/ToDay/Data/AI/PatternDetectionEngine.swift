import Foundation
import SwiftData

// MARK: - TimeOfDayBucket

/// Classifies an hour of the day into a named time bucket.
enum TimeOfDayBucket: String, Sendable, Equatable {
    case morning    // hour 6..<12
    case afternoon  // hour 12..<18
    case evening    // all other hours (0..<6 and 18+)

    static func from(hour: Int) -> TimeOfDayBucket {
        switch hour {
        case 6..<12: return .morning
        case 12..<18: return .afternoon
        default: return .evening
        }
    }
}

// MARK: - DetectedPattern

/// A behavioral pattern detected across multiple consecutive days.
struct DetectedPattern: Sendable {
    /// The event kind of the matching events (always .quietTime for now)
    let kind: EventKind
    /// The resolved place name (e.g. "北大图书馆")
    let placeName: String
    /// The time-of-day bucket the activity falls into
    let timeOfDay: TimeOfDayBucket
    /// Number of consecutive days in the streak
    let streakLength: Int
    /// The dateKey strings ("yyyy-MM-dd") for each day in the streak
    let recentDates: [String]
}

// MARK: - PatternDetectionEngine

/// Pure-Swift behavioral pattern detector.
///
/// Reads SwiftData (DayTimelineEntity, DailySummaryEntity) and returns DetectedPattern values.
/// This struct has no side effects — it does not write to the database or schedule notifications.
/// All methods are safe to call from any context.
struct PatternDetectionEngine {

    // MARK: - Configuration

    /// Minimum number of DailySummaryEntity records required before detection runs.
    let minimumDataDays: Int = 21

    /// Minimum consecutive days to constitute a detectable pattern.
    let minimumStreakDays: Int = 3

    /// Display names that represent unresolved or fallback geocoder results.
    private let blocklist: Set<String> = ["未知地点", "离开了手机"]

    // MARK: - Public API

    /// Returns false when DailySummaryEntity count < minimumDataDays.
    /// Uses fetchCount for efficiency — no full fetch.
    func hasSufficientData(context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<DailySummaryEntity>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        return count >= minimumDataDays
    }

    /// Returns the highest-streakLength DetectedPattern found in the last 30 days,
    /// or nil if no streak meets minimumStreakDays or data is insufficient.
    ///
    /// Only considers EventKind.quietTime events with a non-blocklisted displayName.
    /// Uses string-range predicate on dateKey (not Date predicate) to avoid SwiftData capture bugs.
    func detectBestPattern(context: ModelContext) -> DetectedPattern? {
        guard hasSufficientData(context: context) else { return nil }

        let timelines = fetchRecentTimelines(context: context, lookbackDays: 30)

        // Group dateKeys by (displayName, TimeOfDayBucket)
        var groupedDateKeys: [String: [String: Set<String>]] = [:]
        // Key structure: groupedDateKeys[displayName][bucket.rawValue] = Set<dateKey>

        for entity in timelines {
            let dateKey = entity.dateKey
            let entries = decodeEntries(entity.entriesData)

            for event in entries {
                guard event.kind == .quietTime else { continue }
                guard !blocklist.contains(event.displayName) else { continue }
                guard !event.displayName.trimmingCharacters(in: .whitespaces).isEmpty else { continue }

                let hour = Calendar.current.component(.hour, from: event.startDate)
                let bucket = TimeOfDayBucket.from(hour: hour)

                if groupedDateKeys[event.displayName] == nil {
                    groupedDateKeys[event.displayName] = [:]
                }
                if groupedDateKeys[event.displayName]![bucket.rawValue] == nil {
                    groupedDateKeys[event.displayName]![bucket.rawValue] = []
                }
                groupedDateKeys[event.displayName]![bucket.rawValue]!.insert(dateKey)
            }
        }

        // Find the group with the longest streak
        var bestPattern: DetectedPattern? = nil

        for (displayName, buckets) in groupedDateKeys {
            for (bucketRaw, dateKeySet) in buckets {
                guard let bucket = TimeOfDayBucket(rawValue: bucketRaw) else { continue }
                let dateKeys = Array(dateKeySet)
                let result = longestStreak(dateKeys: dateKeys)

                guard result.length >= minimumStreakDays else { continue }

                if bestPattern == nil || result.length > bestPattern!.streakLength {
                    bestPattern = DetectedPattern(
                        kind: .quietTime,
                        placeName: displayName,
                        timeOfDay: bucket,
                        streakLength: result.length,
                        recentDates: result.recent
                    )
                }
            }
        }

        return bestPattern
    }

    // MARK: - Internal Helpers

    /// Fetches DayTimelineEntity records for the last lookbackDays days using string-range predicate.
    private func fetchRecentTimelines(context: ModelContext, lookbackDays: Int) -> [DayTimelineEntity] {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -lookbackDays, to: Date()) ?? Date()
        let cutoffKey = DayTimelineEntity.dateKey(for: cutoff)
        let descriptor = FetchDescriptor<DayTimelineEntity>(
            predicate: #Predicate { $0.dateKey >= cutoffKey },
            sortBy: [SortDescriptor(\.dateKey, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Decodes the entriesData blob from a DayTimelineEntity into [InferredEvent].
    private func decodeEntries(_ data: Data) -> [InferredEvent] {
        guard !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([InferredEvent].self, from: data)) ?? []
    }

    /// Finds the longest run of consecutive calendar days in the given dateKey strings.
    ///
    /// Returns (length, recent) where recent is the sorted slice of dateKeys in the best streak.
    /// Sorted ISO date strings are lexicographically equivalent to chronological order.
    private func longestStreak(dateKeys: [String]) -> (length: Int, recent: [String]) {
        let sorted = dateKeys.sorted()
        guard !sorted.isEmpty else { return (0, []) }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        var currentStreak = [sorted[0]]
        var bestStreak = currentStreak

        for i in 1..<sorted.count {
            guard let prev = formatter.date(from: sorted[i - 1]),
                  let curr = formatter.date(from: sorted[i]) else { continue }
            let diff = Calendar.current.dateComponents([.day], from: prev, to: curr).day ?? 0
            if diff == 1 {
                currentStreak.append(sorted[i])
            } else {
                if currentStreak.count > bestStreak.count {
                    bestStreak = currentStreak
                }
                currentStreak = [sorted[i]]
            }
        }
        if currentStreak.count > bestStreak.count {
            bestStreak = currentStreak
        }
        return (bestStreak.count, bestStreak)
    }
}
