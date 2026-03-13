import Foundation
import UserNotifications

final class DailyReviewNotifier {
    private let notificationCenter: UNUserNotificationCenter
    private let sharedDefaults: UserDefaults?
    private let requestIdentifier = "watch.dailyReview"

    init(
        notificationCenter: UNUserNotificationCenter = .current(),
        sharedDefaults: UserDefaults? = UserDefaults(suiteName: SharedAppGroup.identifier)
    ) {
        self.notificationCenter = notificationCenter
        self.sharedDefaults = sharedDefaults
    }

    func requestAuthorizationAndSchedule() async {
        let granted = (try? await notificationCenter.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return }
        await scheduleDailyReview()
    }

    func scheduleDailyReview() async {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [requestIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "今日画卷已就绪"
        content.body = reviewBody()
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 21
        dateComponents.minute = 30

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: requestIdentifier, content: content, trigger: trigger)

        try? await notificationCenter.add(request)
    }

    private func reviewBody() -> String {
        guard let data = sharedDefaults?.data(forKey: SharedAppGroup.currentEventSnapshotKey),
              let snapshot = try? JSONDecoder().decode(CurrentEventSnapshot.self, from: data) else {
            return "今天的故事等你回看。"
        }

        if snapshot.durationMinutes > 0 {
            return "今天已经\(snapshot.eventName)\(durationText(snapshot.durationMinutes))。打开手机看看完整的一天。"
        }

        return "今天记录了新的片段。打开手机看看完整的一天。"
    }

    private func durationText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0 {
            if remainingMinutes > 0 {
                return "\(hours) 小时 \(remainingMinutes) 分钟"
            }
            return "\(hours) 小时"
        }

        return "\(minutes) 分钟"
    }
}
