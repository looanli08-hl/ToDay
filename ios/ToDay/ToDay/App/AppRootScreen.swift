import SwiftUI

private enum AppTab: Hashable {
    case home
    case timeline
    case record // placeholder for center button
    case echo
    case settings
}

struct AppRootScreen: View {
    @AppStorage("today.hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @ObservedObject var todayViewModel: TodayViewModel
    @ObservedObject var echoViewModel: EchoViewModel
    @State private var selectedTab: AppTab = .home
    @State private var showRecordSheet = false
    @State private var previousTab: AppTab = .home

    var body: some View {
        if hasCompletedOnboarding {
            ZStack(alignment: .bottom) {
                TabView(selection: tabSelection) {
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

                    // Invisible placeholder — the center button overlay handles taps
                    Color.clear
                    .tabItem {
                        Label("", systemImage: "")
                    }
                    .tag(AppTab.record)

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

                // Center "+" button overlaying the tab bar
                centerButton
            }
            .sheet(isPresented: $showRecordSheet) {
                RecordActionSheet(
                    todayViewModel: todayViewModel,
                    onDismiss: { showRecordSheet = false }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        } else {
            OnboardingView {
                hasCompletedOnboarding = true
            }
        }
    }

    // Intercept the .record tab to open sheet instead
    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { selectedTab },
            set: { newTab in
                if newTab == .record {
                    showRecordSheet = true
                    // Don't switch to the placeholder tab
                } else {
                    selectedTab = newTab
                    previousTab = newTab
                }
            }
        )
    }

    // MARK: - Center Button

    private var centerButton: some View {
        Button {
            showRecordSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.42, blue: 0.42), Color(red: 1.0, green: 0.55, blue: 0.30)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .shadow(color: Color(red: 1.0, green: 0.45, blue: 0.35).opacity(0.4), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .offset(y: -26)
    }
}

// MARK: - Record Action Sheet (combines shutter + mood)

private struct RecordActionSheet: View {
    @ObservedObject var todayViewModel: TodayViewModel
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    // Shutter options
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            todayViewModel.showShutterPanel = true
                        }
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("快门")
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Text("文字、语音、拍照、视频")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "camera.aperture")
                                .foregroundStyle(AppColor.shutter)
                        }
                    }

                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            todayViewModel.showQuickRecord = true
                        }
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("记录心情")
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Text("选一个最接近当下的情绪")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(AppColor.mood)
                        }
                    }
                } header: {
                    Text("记录此刻")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("新建")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
