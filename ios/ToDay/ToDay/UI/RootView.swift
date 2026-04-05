import SwiftUI

enum AppTab: Int, CaseIterable {
    case today
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
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                TodayScreen(viewModel: AppContainer.makeTodayViewModel())
                    .tabItem {
                        Label("首页", systemImage: "sun.horizon")
                    }
                    .tag(AppTab.today)

                // Hidden placeholder to keep tab indices balanced
                Color.clear
                    .tabItem {
                        Label("", systemImage: "")
                    }
                    .tag(AppTab.record)

                SettingsView()
                    .tabItem {
                        Label("设置", systemImage: "gearshape")
                    }
                    .tag(AppTab.settings)
            }
            .tint(AppColor.accent)

            // Floating center "+" button overlaying the tab bar
            Button {
                showQuickRecord = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(AppColor.accent)
                    )
                    .shadow(color: AppColor.accent.opacity(0.3), radius: 8, y: 4)
            }
            .offset(y: -22)
            .accessibilityLabel("快速记录")
        }
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

}
