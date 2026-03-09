import SwiftUI

private enum AppTab: Hashable {
    case today
    case history
    case pro
}

struct AppRootScreen: View {
    @ObservedObject var todayViewModel: TodayViewModel
    @ObservedObject var monetizationViewModel: MonetizationViewModel
    @State private var selectedTab: AppTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayScreen(
                viewModel: todayViewModel,
                monetizationViewModel: monetizationViewModel,
                onOpenHistory: { selectedTab = .history },
                onOpenPro: { selectedTab = .pro }
            )
            .tabItem {
                Label("今天", systemImage: "sun.max.fill")
            }
            .tag(AppTab.today)

            HistoryScreen(
                viewModel: todayViewModel,
                monetizationViewModel: monetizationViewModel,
                onOpenPro: { selectedTab = .pro }
            )
            .tabItem {
                Label("回看", systemImage: "clock.arrow.circlepath")
            }
            .tag(AppTab.history)

            ProScreen(monetizationViewModel: monetizationViewModel)
                .tabItem {
                    Label("会员", systemImage: "sparkles.rectangle.stack")
                }
                .tag(AppTab.pro)
        }
        .tint(Color(red: 0.35, green: 0.63, blue: 0.54))
    }
}
