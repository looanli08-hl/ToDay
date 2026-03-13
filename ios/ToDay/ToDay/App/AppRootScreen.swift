import SwiftUI

private enum AppTab: Hashable {
    case today
    case history
}

struct AppRootScreen: View {
    @ObservedObject var todayViewModel: TodayViewModel
    @State private var selectedTab: AppTab = .today

    var body: some View {
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
        }
        .tint(Color(red: 0.35, green: 0.63, blue: 0.54))
    }
}
