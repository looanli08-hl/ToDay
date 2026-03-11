import SwiftUI
import UIKit

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
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                Task {
                    await monetizationViewModel.revalidateEntitlement()
                }
            }
        }
    }
}
