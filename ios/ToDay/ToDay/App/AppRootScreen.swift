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
    @ObservedObject var echoViewModel: EchoViewModel
    @State private var selectedTab: AppTab = .home
    @State private var showRecordPanel = false

    var body: some View {
        if hasCompletedOnboarding {
            ZStack {
                TabView(selection: $selectedTab) {
                    DashboardView(
                        todayViewModel: todayViewModel,
                        onOpenTimeline: { selectedTab = .timeline }
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

                    EchoScreen(viewModel: echoViewModel)
                    .tabItem {
                        Label("Echo", systemImage: "bell.badge.fill")
                    }
                    .tag(AppTab.echo)

                    SettingsView(echoViewModel: echoViewModel)
                        .tabItem {
                            Label("设置", systemImage: "gear")
                        }
                        .tag(AppTab.settings)
                }
                .tint(TodayTheme.teal)

                // Floating record + shutter bar at the bottom
                VStack {
                    Spacer()
                    floatingRecordBar
                        .padding(.bottom, 60)
                }
            }
            .sheet(isPresented: $todayViewModel.showShutterPanel) {
                ShutterPanel(viewModel: todayViewModel)
            }
            .sheet(isPresented: $showRecordPanel) {
                RecordPanel(viewModel: todayViewModel)
            }
        } else {
            OnboardingView {
                hasCompletedOnboarding = true
            }
        }
    }

    // MARK: - Floating Record Bar

    private var floatingRecordBar: some View {
        HStack(spacing: 12) {
            // Combined mood + time period button
            Button {
                showRecordPanel = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                    Text("记录")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(TodayTheme.accent)
                .clipShape(Capsule())
                .shadow(color: TodayTheme.accent.opacity(0.35), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)

            // Shutter button
            Button {
                todayViewModel.showShutterPanel = true
            } label: {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(TodayTheme.scrollGold))
                    .shadow(color: TodayTheme.scrollGold.opacity(0.35), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
        }
    }
}
