import SwiftUI

private enum AppTab: Hashable {
    case today
    case history
    case settings
}

struct AppRootScreen: View {
    @AppStorage("today.hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @ObservedObject var todayViewModel: TodayViewModel
    @State private var selectedTab: AppTab = .today

    var body: some View {
        if hasCompletedOnboarding {
            TabView(selection: $selectedTab) {
                TodayScreen(
                    viewModel: todayViewModel,
                    onOpenHistory: { selectedTab = .history }
                )
                .tabItem {
                    Label("今天", systemImage: "sun.max.fill")
                }
                .tag(AppTab.today)

                HistoryScreen(viewModel: todayViewModel)
                .tabItem {
                    Label("回看", systemImage: "clock.arrow.circlepath")
                }
                .tag(AppTab.history)

                SettingsView()
                    .tabItem {
                        Label("设置", systemImage: "gear")
                    }
                    .tag(AppTab.settings)
            }
            .tint(TodayTheme.teal)
        } else {
            OnboardingView {
                hasCompletedOnboarding = true
            }
        }
    }
}
