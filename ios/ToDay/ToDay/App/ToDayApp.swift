import SwiftUI
import SwiftData
import UIKit

@main
struct ToDayApp: App {
    @StateObject private var viewModel = AppContainer.makeTodayViewModel()
    @StateObject private var echoViewModel = AppContainer.makeEchoViewModel()
    private let locationService = LocationService.shared

    var body: some Scene {
        WindowGroup {
            AppRootScreen(todayViewModel: viewModel, echoViewModel: echoViewModel)
            .task {
                _ = locationService
            }
        }
        .modelContainer(AppContainer.modelContainer)
    }
}
