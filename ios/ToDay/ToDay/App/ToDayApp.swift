import SwiftUI
import SwiftData
import UIKit

@main
struct ToDayApp: App {
    @StateObject private var viewModel = AppContainer.makeTodayViewModel()
    @StateObject private var echoViewModel = AppContainer.makeEchoViewModel()
    @StateObject private var echoMessageManager = AppContainer.getEchoMessageManager()
    @Environment(\.scenePhase) private var scenePhase
    private let echoScheduler = AppContainer.getEchoScheduler()
    private let backgroundTaskManager = BackgroundTaskManager.shared

    init() {
        UserDefaults.standard.register(defaults: ["today.smartRecording.enabled": true])
        backgroundTaskManager.registerTasks()
    }

    var body: some Scene {
        WindowGroup {
            AppRootScreen(
                todayViewModel: viewModel,
                echoViewModel: echoViewModel,
                echoMessageManager: echoMessageManager
            )
            .task {
                AppContainer.getDeviceStateCollector().startMonitoring()
                AppContainer.getLocationCollector().startMonitoring()
                await echoScheduler.onAppLaunch()
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .background:
                    // Schedule background timeline generation
                    backgroundTaskManager.scheduleAppRefresh()
                    backgroundTaskManager.scheduleProcessing()
                    // Update today's event count for the recording indicator
                    if let count = viewModel.timeline?.entries.count {
                        BackgroundTaskManager.updateTodayEventCount(count)
                    }
                    Task {
                        await echoScheduler.onAppBackground(
                            todayDataSummary: viewModel.timelineDataSummary,
                            shutterTexts: viewModel.todayShutterTexts,
                            moodNotes: viewModel.todayMoodNotes
                        )
                    }
                case .active:
                    // Refresh timeline when coming back to foreground
                    Task {
                        await viewModel.load(forceReload: true)
                    }
                    // Sync local data to Supabase for web dashboard
                    Task {
                        await CloudSyncService.shared.syncAll(modelContainer: AppContainer.modelContainer)
                    }
                default:
                    break
                }
            }
        }
        .modelContainer(AppContainer.modelContainer)
    }
}
