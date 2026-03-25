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
                .tint(.accentColor)

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
                QuickRecordSheet(mode: .flexible) { record in
                    todayViewModel.startMoodRecord(record)
                    showRecordPanel = false
                }
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
            // Record button
            Button {
                showRecordPanel = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.body)
                    Text("记录")
                        .font(.body.weight(.semibold))
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .clipShape(Capsule())
            .shadow(color: .accentColor.opacity(0.2), radius: 8, x: 0, y: 4)

            // Shutter button
            Button {
                todayViewModel.showShutterPanel = true
            } label: {
                Image(systemName: "camera.aperture")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color(UIColor.secondaryLabel)))
                    .shadow(color: Color.primary.opacity(0.1), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
    }
}
