import SwiftUI

private enum AppTab: Hashable {
    case home
    case timeline
    case echo
    case settings
}

struct AppRootScreen: View {
    @AppStorage("today.hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @ObservedObject var todayViewModel: TodayViewModel
    @State private var selectedTab: AppTab = .home

    var body: some View {
        if hasCompletedOnboarding {
            TabView(selection: $selectedTab) {
                TodayScreen(
                    viewModel: todayViewModel,
                    onOpenHistory: { selectedTab = .timeline }
                )
                .tabItem {
                    Label("首页", systemImage: "square.grid.2x2.fill")
                }
                .tag(AppTab.home)

                HistoryScreen(viewModel: todayViewModel)
                .tabItem {
                    Label("时间线", systemImage: "clock.fill")
                }
                .tag(AppTab.timeline)

                EchoScreen()
                .tabItem {
                    Label("Echo", systemImage: "bell.badge.fill")
                }
                .tag(AppTab.echo)

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
