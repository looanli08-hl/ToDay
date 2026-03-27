import BackgroundTasks
import Foundation
import HealthKit
import SwiftData

/// Manages background timeline generation using BGTaskScheduler.
///
/// Registers two tasks:
/// - **App Refresh** (`com.looanli.today.refresh`): Lightweight, runs ~every 1-2 hours when system allows.
///   Generates today's timeline and persists it.
/// - **Processing** (`com.looanli.today.processing`): Heavier, runs overnight.
///   Generates timelines for any recent days that are missing.
final class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()

    static let refreshTaskIdentifier = "com.looanli.today.refresh"
    static let processingTaskIdentifier = "com.looanli.today.processing"

    private let calendar = Calendar.current

    private init() {}

    // MARK: - Registration

    /// Call from `ToDayApp.init` or `.task {}` — must happen before app finishes launching.
    func registerTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.refreshTaskIdentifier,
            using: nil
        ) { task in
            self.handleAppRefresh(task as! BGAppRefreshTask)
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.processingTaskIdentifier,
            using: nil
        ) { task in
            self.handleProcessing(task as! BGProcessingTask)
        }
    }

    // MARK: - Scheduling

    /// Schedule the next app refresh. Call after each successful refresh and on app background.
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hour
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("[BGTask] Failed to schedule app refresh: \(error)")
        }
    }

    /// Schedule overnight processing for backfilling missing days.
    func scheduleProcessing() {
        let request = BGProcessingTaskRequest(identifier: Self.processingTaskIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 60 * 60) // 4 hours
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("[BGTask] Failed to schedule processing: \(error)")
        }
    }

    // MARK: - Task Handlers

    private func handleAppRefresh(_ task: BGAppRefreshTask) {
        // Schedule the next refresh immediately
        scheduleAppRefresh()

        let workTask = Task {
            await generateTodayTimeline()
        }

        task.expirationHandler = {
            workTask.cancel()
        }

        Task {
            await workTask.value
            task.setTaskCompleted(success: true)
        }
    }

    private func handleProcessing(_ task: BGProcessingTask) {
        // Schedule next processing
        scheduleProcessing()

        let workTask = Task {
            await backfillRecentTimelines()
        }

        task.expirationHandler = {
            workTask.cancel()
        }

        Task {
            await workTask.value
            task.setTaskCompleted(success: true)
        }
    }

    // MARK: - Timeline Generation

    /// Generate today's timeline from HealthKit and persist it.
    private func generateTodayTimeline() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let provider = HealthKitTimelineDataProvider()
        let today = calendar.startOfDay(for: Date())

        do {
            let timeline = try await provider.loadTimeline(for: today)
            persistTimeline(timeline)
            updateLastRecordedDate()
            print("[BGTask] Successfully generated today's timeline with \(timeline.entries.count) events")
        } catch {
            print("[BGTask] Failed to generate today's timeline: \(error)")
        }
    }

    /// Backfill any missing timelines for the past 7 days.
    private func backfillRecentTimelines() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let provider = HealthKitTimelineDataProvider()
        let today = calendar.startOfDay(for: Date())

        for offset in 1...7 {
            guard !Task.isCancelled else { break }
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }

            // Skip if already persisted
            if hasPersistedTimeline(for: date) { continue }

            do {
                let timeline = try await provider.loadTimeline(for: date)
                if !timeline.entries.isEmpty {
                    persistTimeline(timeline)
                    print("[BGTask] Backfilled timeline for \(DayTimelineEntity.dateKey(for: date))")
                }
            } catch {
                print("[BGTask] Failed to backfill \(DayTimelineEntity.dateKey(for: date)): \(error)")
            }
        }
    }

    // MARK: - Persistence

    private func persistTimeline(_ timeline: DayTimeline) {
        let context = ModelContext(AppContainer.modelContainer)
        let key = DayTimelineEntity.dateKey(for: timeline.date)
        var descriptor = FetchDescriptor<DayTimelineEntity>(predicate: #Predicate { $0.dateKey == key })
        descriptor.fetchLimit = 1

        do {
            if let existing = try context.fetch(descriptor).first {
                existing.update(from: timeline)
            } else {
                context.insert(DayTimelineEntity(timeline: timeline))
            }
            try context.save()
        } catch {
            print("[BGTask] Failed to persist timeline: \(error)")
        }
    }

    private func hasPersistedTimeline(for date: Date) -> Bool {
        let context = ModelContext(AppContainer.modelContainer)
        let key = DayTimelineEntity.dateKey(for: date)
        var descriptor = FetchDescriptor<DayTimelineEntity>(predicate: #Predicate { $0.dateKey == key })
        descriptor.fetchLimit = 1
        return (try? context.fetchCount(descriptor)) ?? 0 > 0
    }

    // MARK: - Recording State

    /// Stores the last time a background recording succeeded.
    private static let lastRecordedDateKey = "today.bg.lastRecordedDate"
    private static let todayEventCountKey = "today.bg.todayEventCount"

    private func updateLastRecordedDate() {
        UserDefaults.standard.set(Date(), forKey: Self.lastRecordedDateKey)
    }

    /// Returns the last time a background recording ran, or nil.
    static var lastRecordedDate: Date? {
        UserDefaults.standard.object(forKey: lastRecordedDateKey) as? Date
    }

    /// Update the event count for today (called from foreground too).
    static func updateTodayEventCount(_ count: Int) {
        UserDefaults.standard.set(count, forKey: todayEventCountKey)
    }

    /// Current event count for today.
    static var todayEventCount: Int {
        UserDefaults.standard.integer(forKey: todayEventCountKey)
    }
}
