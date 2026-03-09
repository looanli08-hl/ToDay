import SwiftUI

@main
struct ToDayApp: App {
    @StateObject private var viewModel = AppContainer.makeTodayViewModel()

    var body: some Scene {
        WindowGroup {
            TodayScreen(viewModel: viewModel)
        }
    }
}
