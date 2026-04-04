import CoreLocation
import Foundation
import UserNotifications

// MARK: - Notification Scheduling Protocol

protocol EchoNotificationScheduling: Sendable {
    func scheduleEchoNotification(identifier: String, title: String, body: String, triggerDate: Date)
    func removeNotifications(identifiers: [String])
}

// MARK: - UNUserNotificationCenter Conformance

final class SystemNotificationScheduler: EchoNotificationScheduling {
    func scheduleEchoNotification(identifier: String, title: String, body: String, triggerDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "ECHO_REMINDER"

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[EchoEngine] Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }

    func removeNotifications(identifiers: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

// MARK: - Echo Engine

@MainActor
final class EchoEngine {
    private let echoStore: any EchoItemStoring
    private let shutterRecordStore: (any ShutterRecordStoring)?
    private let notificationScheduler: any EchoNotificationScheduling
    private let calendar: Calendar
    private var hasRequestedPermission = false

    /// User preference: default echo time of day (hour component, 0-23). Default = 9 (9:00 AM)
    var echoHour: Int {
        get { UserDefaults.standard.integer(forKey: "today.echo.hour").clamped(to: 0...23, default: 9) }
        set { UserDefaults.standard.set(newValue, forKey: "today.echo.hour") }
    }

    /// User preference: care nudges enabled
    var careNudgesEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "today.echo.careNudges") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "today.echo.careNudges") }
    }

    /// User preference: global echo frequency override (nil = use per-record config)
    var globalFrequency: EchoFrequency? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: "today.echo.globalFrequency") else { return nil }
            return EchoFrequency(rawValue: raw)
        }
        set { UserDefaults.standard.set(newValue?.rawValue, forKey: "today.echo.globalFrequency") }
    }

    init(
        echoStore: any EchoItemStoring,
        shutterRecordStore: (any ShutterRecordStoring)? = nil,
        notificationScheduler: any EchoNotificationScheduling = SystemNotificationScheduler(),
        calendar: Calendar = .current
    ) {
        self.echoStore = echoStore
        self.shutterRecordStore = shutterRecordStore
        self.notificationScheduler = notificationScheduler
        self.calendar = calendar
    }

    // MARK: - Scheduling

    /// Schedule echo reminders for a newly saved ShutterRecord
    func scheduleEchoes(for record: ShutterRecord) {
        let frequency = globalFrequency ?? record.echoConfig.frequency
        guard frequency != .off else { return }

        if !hasRequestedPermission {
            requestNotificationPermission()
            hasRequestedPermission = true
        }

        let reminderDays = frequency.reminderDays

        for dayOffset in reminderDays {
            guard let scheduledDate = echoDate(from: record.createdAt, dayOffset: dayOffset) else { continue }

            let item = EchoItem(
                shutterRecordID: record.id,
                scheduledDate: scheduledDate,
                status: .pending,
                reminderDayOffset: dayOffset
            )

            try? echoStore.save(item)

            // Schedule local notification
            let preview = record.displayText
            let identifier = notificationIdentifier(echoID: item.id)
            notificationScheduler.scheduleEchoNotification(
                identifier: identifier,
                title: "回响",
                body: "\(item.offsetLabel)你说：「\(preview)」",
                triggerDate: scheduledDate
            )
        }
    }

    /// Evaluate shutter records using relevance scoring and push an elastic echo
    /// notification if the top-scoring record exceeds the frequency threshold.
    func evaluateAndPushIfNeeded() {
        let frequency = globalFrequency ?? .medium
        guard frequency != .off else { return }

        // Check min interval since last elastic push
        let lastPush = UserDefaults.standard.object(forKey: "today.echo.lastPushDate") as? Date ?? .distantPast
        let minInterval = EchoRelevanceScorer.minInterval(for: frequency)
        guard Date().timeIntervalSince(lastPush) >= minInterval else { return }

        let threshold = EchoRelevanceScorer.threshold(for: frequency)
        let scorer = EchoRelevanceScorer()
        let now = Date()

        guard let store = shutterRecordStore else { return }
        let records = store.loadAll()
        guard !records.isEmpty else { return }

        var bestScore: Double = 0
        var bestRecord: (title: String, id: UUID)?

        for record in records {
            let recordLocation: CLLocation?
            if let lat = record.latitude, let lon = record.longitude {
                recordLocation = CLLocation(latitude: lat, longitude: lon)
            } else {
                recordLocation = nil
            }

            let s = scorer.score(
                recordDate: record.createdAt,
                recordNote: record.displayText,
                now: now,
                currentLocation: nil,
                recordLocation: recordLocation
            )
            if s > bestScore {
                bestScore = s
                bestRecord = (record.displayText, record.id)
            }
        }

        guard bestScore >= threshold, let best = bestRecord else { return }

        if !hasRequestedPermission {
            requestNotificationPermission()
            hasRequestedPermission = true
        }

        // Schedule immediate notification
        let content = UNMutableNotificationContent()
        content.title = "回响"
        content.body = "还记得「\(best.title)」吗？"
        content.sound = .default
        content.categoryIdentifier = "ECHO_REMINDER"

        let request = UNNotificationRequest(
            identifier: "echo.elastic.\(best.id)",
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[EchoEngine] Failed to schedule elastic echo: \(error.localizedDescription)")
            }
        }

        UserDefaults.standard.set(Date(), forKey: "today.echo.lastPushDate")
    }

    /// Cancel all echoes for a deleted ShutterRecord
    func cancelEchoes(forShutterRecordID shutterRecordID: UUID) {
        let items = echoStore.loadAll().filter { $0.shutterRecordID == shutterRecordID }
        let identifiers = items.map { notificationIdentifier(echoID: $0.id) }

        if !identifiers.isEmpty {
            notificationScheduler.removeNotifications(identifiers: identifiers)
        }

        try? echoStore.deleteAll(forShutterRecordID: shutterRecordID)
    }

    // MARK: - Queries

    /// Get today's pending echoes
    func todayEchoes() -> [EchoItem] {
        echoStore.loadPending(for: Date())
    }

    /// Get past viewed/dismissed echoes
    func echoHistory(limit: Int = 50) -> [EchoItem] {
        echoStore.loadHistory(limit: limit)
    }

    // MARK: - Actions

    /// Mark an echo as viewed
    func markAsViewed(echoID: UUID) {
        guard var item = findItem(id: echoID) else { return }
        item.status = .viewed
        try? echoStore.save(item)
    }

    /// Dismiss an echo
    func dismiss(echoID: UUID) {
        guard var item = findItem(id: echoID) else { return }
        item.status = .dismissed
        try? echoStore.save(item)

        // Cancel any pending notification
        notificationScheduler.removeNotifications(identifiers: [notificationIdentifier(echoID: echoID)])
    }

    /// Snooze an echo to tomorrow
    func snooze(echoID: UUID) {
        guard var item = findItem(id: echoID) else { return }

        // Mark original as snoozed
        item.status = .snoozed
        try? echoStore.save(item)

        // Cancel original notification
        notificationScheduler.removeNotifications(identifiers: [notificationIdentifier(echoID: echoID)])

        // Create new echo for tomorrow
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        guard let tomorrowDate = echoDateForHour(on: tomorrow) else { return }

        let newItem = EchoItem(
            shutterRecordID: item.shutterRecordID,
            scheduledDate: tomorrowDate,
            status: .pending,
            reminderDayOffset: item.reminderDayOffset
        )
        try? echoStore.save(newItem)

        // Schedule new notification
        notificationScheduler.scheduleEchoNotification(
            identifier: notificationIdentifier(echoID: newItem.id),
            title: "回响",
            body: "你有一条待查看的回响",
            triggerDate: tomorrowDate
        )
    }

    // MARK: - Notification Permissions

    /// Request notification authorization if not already granted
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                print("[EchoEngine] Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private Helpers

    private func findItem(id: UUID) -> EchoItem? {
        echoStore.loadAll().first { $0.id == id }
    }

    private func echoDate(from recordDate: Date, dayOffset: Int) -> Date? {
        guard let targetDay = calendar.date(byAdding: .day, value: dayOffset, to: recordDate) else { return nil }
        return echoDateForHour(on: targetDay)
    }

    private func echoDateForHour(on date: Date) -> Date? {
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(bySettingHour: echoHour, minute: 0, second: 0, of: startOfDay)
    }

    private func notificationIdentifier(echoID: UUID) -> String {
        "echo-\(echoID.uuidString)"
    }
}

// MARK: - Int Clamped Extension

private extension Int {
    func clamped(to range: ClosedRange<Int>, default defaultValue: Int) -> Int {
        if self == 0 && UserDefaults.standard.object(forKey: "today.echo.hour") == nil {
            return defaultValue
        }
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
