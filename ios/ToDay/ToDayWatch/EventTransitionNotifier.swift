import Foundation
import UserNotifications
import WatchKit

final class EventTransitionNotifier {
    private let notificationCenter: UNUserNotificationCenter
    private let defaults: UserDefaults
    private let lastNotificationKey = "watch.transition.lastNotificationDate"
    private let minimumInterval: TimeInterval = 30 * 60

    init(
        notificationCenter: UNUserNotificationCenter = .current(),
        defaults: UserDefaults = .standard
    ) {
        self.notificationCenter = notificationCenter
        self.defaults = defaults
    }

    func checkTransition(previous: CurrentEventSnapshot?, current: CurrentEventSnapshot?) {
        guard let previous, let current else { return }
        guard shouldNotify(previous: previous, current: current, now: Date()) else { return }

        let content = UNMutableNotificationContent()
        content.title = "开始\(current.eventName)"
        content.subtitle = "\(transitionLead(for: previous))了\(durationText(since: previous.startDate, now: current.startDate))后"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "watch.transition.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        notificationCenter.add(request)
        defaults.set(Date(), forKey: lastNotificationKey)
        WKInterfaceDevice.current().play(.notification)
    }

    private func shouldNotify(previous: CurrentEventSnapshot, current: CurrentEventSnapshot, now: Date) -> Bool {
        guard previous != current else { return false }
        guard !(previous.eventKind == "quietTime" && current.eventKind == "quietTime") else { return false }
        guard !isSleepWindow(now) else { return false }

        if let lastNotificationDate = defaults.object(forKey: lastNotificationKey) as? Date,
           now.timeIntervalSince(lastNotificationDate) < minimumInterval {
            return false
        }

        return true
    }

    private func isSleepWindow(_ date: Date) -> Bool {
        let hour = Calendar.current.component(.hour, from: date)
        return hour >= 22 || hour < 7
    }

    private func transitionLead(for snapshot: CurrentEventSnapshot) -> String {
        if snapshot.eventKind == "quietTime" {
            return "安静"
        }
        return snapshot.eventName
    }

    private func durationText(since startDate: Date, now: Date) -> String {
        let totalMinutes = max(1, Int(now.timeIntervalSince(startDate)) / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            if minutes > 0 {
                return " \(hours) 小时 \(minutes) 分钟 "
            }
            return " \(hours) 小时 "
        }

        return " \(minutes) 分钟 "
    }
}
