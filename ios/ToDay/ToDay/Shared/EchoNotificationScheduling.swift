import Foundation
import UserNotifications

protocol EchoNotificationScheduling: Sendable {
    func scheduleEchoNotification(identifier: String, title: String, body: String, triggerDate: Date)
    func removeNotifications(identifiers: [String])
}

struct SystemNotificationScheduler: EchoNotificationScheduling {
    func scheduleEchoNotification(identifier: String, title: String, body: String, triggerDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { _ in }
    }

    func removeNotifications(identifiers: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
