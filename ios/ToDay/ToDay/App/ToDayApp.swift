import SwiftUI
import SwiftData
import UIKit

@main
struct ToDayApp: App {
    @StateObject private var viewModel = AppContainer.makeTodayViewModel()
    private let locationService = LocationService.shared

    var body: some Scene {
        WindowGroup {
            AppRootScreen(todayViewModel: viewModel)
            .task {
                _ = locationService
            }
        }
        .modelContainer(AppContainer.modelContainer)
    }
}
