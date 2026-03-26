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
    @State private var pendingAction: RecordAction?

    enum RecordAction {
        case shutter
        case mood
    }

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
            .sheet(isPresented: $showRecordSheet, onDismiss: {
                guard let action = pendingAction else { return }
                pendingAction = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    switch action {
                    case .shutter:
                        todayViewModel.showShutterPanel = true
                    case .mood:
                        todayViewModel.showQuickRecord = true
                    }
                }
            }) {
                RecordActionSheet(
                    todayViewModel: todayViewModel,
                    onDismiss: { showRecordSheet = false },
                    onAction: { action in
                        pendingAction = action
                        showRecordSheet = false
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $todayViewModel.showShutterPanel) {
                ShutterPanel(viewModel: todayViewModel)
            }
            .sheet(isPresented: $todayViewModel.showQuickRecord) {
                QuickRecordSheet(mode: todayViewModel.quickRecordMode) { record in
                    todayViewModel.startMoodRecord(record)
                }
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

    // MARK: - Center Button (inside tab bar area)

    private var centerButton: some View {
        Button {
            showRecordSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.title3.weight(.heavy))
                .foregroundStyle(.white)
                .frame(width: 56, height: 42)
                .background(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.38, blue: 0.38), Color(red: 1.0, green: 0.52, blue: 0.28)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .offset(y: -2)
    }
}

// MARK: - Record Action Sheet (combines shutter + mood)

private struct RecordActionSheet: View {
    @ObservedObject var todayViewModel: TodayViewModel
    let onDismiss: () -> Void
    let onAction: (AppRootScreen.RecordAction) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        onAction(.shutter)
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
                        onAction(.mood)
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
