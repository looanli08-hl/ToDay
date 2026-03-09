import SwiftUI

@main
struct ToDayApp: App {
    @StateObject private var viewModel = AppContainer.makeTodayViewModel()
    @StateObject private var monetizationViewModel = AppContainer.makeMonetizationViewModel()

    var body: some Scene {
        WindowGroup {
            AppRootScreen(
                todayViewModel: viewModel,
                monetizationViewModel: monetizationViewModel
            )
        }
    }
}
