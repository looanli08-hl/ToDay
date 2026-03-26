import SwiftUI
import SwiftData
import UIKit

@main
struct ToDayApp: App {
    @StateObject private var viewModel = AppContainer.makeTodayViewModel()
    @StateObject private var echoViewModel = AppContainer.makeEchoViewModel()
    @StateObject private var echoChatViewModel = AppContainer.makeEchoChatViewModel()
    @Environment(\.scenePhase) private var scenePhase
    private let locationService = LocationService.shared
    private let echoScheduler = AppContainer.getEchoScheduler()

    var body: some Scene {
        WindowGroup {
            AppRootScreen(
                todayViewModel: viewModel,
                echoViewModel: echoViewModel,
                echoChatViewModel: echoChatViewModel
            )
            .task {
                _ = locationService
                // Weekly profile check on launch
                await echoScheduler.onAppLaunch()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background {
                    Task {
                        await echoScheduler.onAppBackground(
                            todayDataSummary: "",
                            shutterTexts: [],
                            moodNotes: []
                        )
                    }
                }
            }
        }
        .modelContainer(AppContainer.modelContainer)
    }
}
