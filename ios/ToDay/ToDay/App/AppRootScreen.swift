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

    private var showFloatingButton: Bool {
        selectedTab == .home || selectedTab == .timeline
    }

    var body: some View {
        if hasCompletedOnboarding {
            ZStack {
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

                if showFloatingButton {
                    ShutterFloatingButton(viewModel: todayViewModel)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .sheet(isPresented: $todayViewModel.showShutterPanel) {
                ShutterPanel(viewModel: todayViewModel)
            }
            .fullScreenCover(isPresented: $todayViewModel.isRecordingVoice) {
                VoiceRecordingOverlay { data, duration in
                    do {
                        let filename = try ShutterMediaLibrary.storeVoice(data)
                        let record = ShutterRecord(
                            type: .voice,
                            mediaFilename: filename,
                            voiceTranscript: nil,
                            duration: duration
                        )
                        todayViewModel.saveShutterRecord(record)
                    } catch {
                        // Voice save failed silently
                    }
                } onCancel: {
                    todayViewModel.isRecordingVoice = false
                }
            }
        } else {
            OnboardingView {
                hasCompletedOnboarding = true
            }
        }
    }
}
