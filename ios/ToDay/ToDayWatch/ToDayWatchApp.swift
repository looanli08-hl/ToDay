import SwiftUI

@main
struct ToDayWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = WatchViewModel()
    private let dailyReviewNotifier = DailyReviewNotifier()

    var body: some Scene {
        WindowGroup {
            WatchHomeView(viewModel: viewModel)
                .task {
                    await dailyReviewNotifier.requestAuthorizationAndSchedule()
                    _ = await viewModel.requestHealthKitAuthorization()
                    await viewModel.registerBackgroundDelivery()
                    viewModel.setAppActive(true)
                }
                .onChange(of: scenePhase) { _, newValue in
                    viewModel.setAppActive(newValue == .active)
                }
        }
    }
}
