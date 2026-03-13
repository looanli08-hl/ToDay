import SwiftUI

@main
struct ToDayWatchApp: App {
    private let dailyReviewNotifier = DailyReviewNotifier()

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .task {
                    await dailyReviewNotifier.requestAuthorizationAndSchedule()
                }
        }
    }
}
