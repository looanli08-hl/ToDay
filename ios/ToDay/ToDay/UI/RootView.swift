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
            TabView(selection: recordTabBinding) {
                TodayScreen(viewModel: AppContainer.makeTodayViewModel())
                    .tabItem {
                        Label("Today", systemImage: "sun.horizon")
                    }
                    .tag(AppTab.today)

                // Placeholder — tapping this tab is intercepted by the binding
                Color.clear
                    .tabItem {
                        Label("", systemImage: "")
                    }
                    .tag(AppTab.record)

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .tag(AppTab.settings)
            }
            .tint(AppColor.accent)

            // Floating "+" button — glassmorphic, with warm shadow
            centerRecordButton
                .frame(maxWidth: .infinity)
                .padding(.bottom, 2)
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

    // MARK: - Center Record Button

    private var centerRecordButton: some View {
        Button {
            showQuickRecord = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 42)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.95, green: 0.45, blue: 0.35),
                            Color(red: 0.98, green: 0.60, blue: 0.38)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(
                    color: Color(red: 0.95, green: 0.45, blue: 0.35).opacity(0.25),
                    radius: 8,
                    y: 3
                )
        }
        .accessibilityLabel("Quick record")
    }

    /// Intercepts selection of the record tab to open the sheet instead.
    private var recordTabBinding: Binding<AppTab> {
        Binding(
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
