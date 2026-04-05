import SwiftUI

enum AppTab: Int, CaseIterable {
    case today
    case history
    case record
    case settings
}

struct RootView: View {
    @AppStorage("today.hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedTab: AppTab = .today
    @State private var showQuickRecord = false

    var body: some View {
        if hasCompletedOnboarding {
            mainTabView
        } else {
            OnboardingView()
        }
    }

    // MARK: - Tab View

    @MainActor
    private var mainTabView: some View {
        TabView(selection: tabBinding) {
            TodayScreen(viewModel: AppContainer.makeTodayViewModel())
                .tabItem {
                    Label("首页", systemImage: "sun.horizon")
                }
                .tag(AppTab.today)

            HistoryView(
                timelineProvider: AppContainer.makeTimelineProvider(),
                moodRecordManager: AppContainer.makeMoodRecordManager(),
                shutterManager: AppContainer.makeShutterManager(),
                annotationStore: AppContainer.makeAnnotationStore()
            )
            .tabItem {
                Label("回看", systemImage: "clock.arrow.circlepath")
            }
            .tag(AppTab.history)

            // Center placeholder — intercepted
            Color.clear
                .tabItem {
                    Label("记录", systemImage: "plus.circle.fill")
                }
                .tag(AppTab.record)

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
        .tint(AppColor.accent)
        .sheet(isPresented: $showQuickRecord) {
            QuickRecordSheet(
                isPresented: $showQuickRecord,
                onSave: { note in
                    let manager = AppContainer.makeMoodRecordManager()
                    let record = MoodRecord(mood: .calm, note: note)
                    manager.startRecord(record)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Tab Binding (intercept center + button)

    private var tabBinding: Binding<AppTab> {
        Binding<AppTab>(
            get: { selectedTab },
            set: { newTab in
                if newTab == .record {
                    showQuickRecord = true
                } else {
                    selectedTab = newTab
                }
            }
        )
    }
}
