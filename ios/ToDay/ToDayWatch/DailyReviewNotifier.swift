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
        if let data = sharedDefaults?.data(forKey: SharedAppGroup.dailySummaryKey),
           let summary = try? JSONDecoder().decode(DailySummarySnapshot.self, from: data) {
            if summary.exerciseMinutes > 0 || summary.moodCount > 0 {
                return "今天运动了 \(summary.exerciseMinutes) 分钟，记录了 \(summary.moodCount) 个心情。打开手机看看完整的一天。"
            }

            if summary.eventCount > 0 {
                return "今天生成了 \(summary.eventCount) 个生活片段。打开手机看看完整的一天。"
            }
        }

        return "今天的故事等你回看。"
    }
}
