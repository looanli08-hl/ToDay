import SwiftUI
import BackgroundTasks

@main
struct UnfoldApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        BackgroundTaskManager.shared.registerTasks()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(AppContainer.modelContainer)
                .task {
                    await startServices()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                BackgroundTaskManager.shared.scheduleAppRefresh()
                BackgroundTaskManager.shared.scheduleProcessing()
            default:
                break
            }
        }
    }

    @MainActor
    private func startServices() async {
        AppContainer.startSensors()
        AppContainer.wireEchoScheduler()
        await AppContainer.echoScheduler.onAppLaunch()
    }
}
