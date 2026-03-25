import CoreLocation
import HealthKit
import Photos
import SwiftData
import SwiftUI
import UIKit
import WatchConnectivity

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var echoViewModel: EchoViewModel
    @ObservedObject private var connectivityManager = PhoneConnectivityManager.shared
    @State private var healthStatus: HKAuthorizationStatus = .notDetermined
    @State private var locationStatus: CLAuthorizationStatus = .notDetermined
    @State private var photoStatus: PHAuthorizationStatus = .notDetermined
    @State private var showClearConfirmation = false
    @State private var showClearSuccess = false

    private let healthStore = HKHealthStore()
    private let locationManager = CLLocationManager()
    private let annotationStorageKey = "today.eventAnnotations"

    var body: some View {
        NavigationStack {
            List {
                // MARK: - App Profile Header
                Section {
                    VStack(spacing: 6) {
                        Image(systemName: "circle.hexagongrid.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(TodayTheme.teal)
                            .padding(.bottom, 4)

                        Text("ToDay")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(TodayTheme.ink)

                        Text("Version \(shortVersionText)")
                            .font(.system(size: 13))
                            .foregroundStyle(TodayTheme.inkMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                // MARK: - 设备与同步
                Section {
                    settingsRow(
                        icon: "applewatch",
                        iconBackground: TodayTheme.teal,
                        title: "手表连接",
                        detail: watchStatusText,
                        detailColor: watchStatusColor
                    )
                } header: {
                    sectionHeader("设备与同步")
                }

                // MARK: - Echo 回响
                Section {
                    // Frequency picker
                    HStack(spacing: 12) {
                        iconBadge(systemName: "bell.badge.fill", background: TodayTheme.purple)

                        Text("回响频率")
                            .font(.system(size: 16))
                            .foregroundStyle(TodayTheme.ink)

                        Spacer()

                        Picker("", selection: Binding(
                            get: { echoViewModel.globalFrequency ?? .medium },
                            set: { echoViewModel.globalFrequency = $0 }
                        )) {
                            Text("高").tag(EchoFrequency.high)
                            Text("中").tag(EchoFrequency.medium)
                            Text("低").tag(EchoFrequency.low)
                            Text("关闭").tag(EchoFrequency.off)
                        }
                        .pickerStyle(.menu)
                        .tint(TodayTheme.teal)
                    }

                    // Echo hour
                    HStack(spacing: 12) {
                        iconBadge(systemName: "clock.fill", background: TodayTheme.orange)

                        Text("回响时间")
                            .font(.system(size: 16))
                            .foregroundStyle(TodayTheme.ink)

                        Spacer()

                        Picker("", selection: Binding(
                            get: { echoViewModel.echoHour },
                            set: { echoViewModel.echoHour = $0 }
                        )) {
                            ForEach(6..<23, id: \.self) { hour in
                                Text(String(format: "%02d:00", hour)).tag(hour)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(TodayTheme.teal)
                    }

                    // Care nudges toggle
                    HStack(spacing: 12) {
                        iconBadge(systemName: "heart.fill", background: TodayTheme.rose)

                        Toggle(isOn: Binding(
                            get: { echoViewModel.careNudgesEnabled },
                            set: { echoViewModel.careNudgesEnabled = $0 }
                        )) {
                            Text("关怀推送")
                                .font(.system(size: 16))
                                .foregroundStyle(TodayTheme.ink)
                        }
                        .tint(TodayTheme.teal)
                    }
                } header: {
                    sectionHeader("ECHO 回响")
                }

                // MARK: - 数据权限
                Section {
                    Button {
                        UIApplication.shared.open(URL(string: "x-apple-health://")!)
                    } label: {
                        settingsRow(
                            icon: "heart.text.square.fill",
                            iconBackground: .red,
                            title: "健康数据",
                            detail: healthStatusText,
                            detailColor: healthStatus == .sharingAuthorized ? .green : TodayTheme.inkMuted,
                            showChevron: true
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                    } label: {
                        settingsRow(
                            icon: "location.fill",
                            iconBackground: TodayTheme.blue,
                            title: "位置权限",
                            detail: locationStatusText,
                            detailColor: locationStatus == .authorizedAlways || locationStatus == .authorizedWhenInUse
                                ? .green : TodayTheme.inkMuted,
                            showChevron: true
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                    } label: {
                        settingsRow(
                            icon: "photo.fill",
                            iconBackground: TodayTheme.accent,
                            title: "照片权限",
                            detail: photoStatusText,
                            detailColor: photoStatus == .authorized || photoStatus == .limited
                                ? .green : TodayTheme.inkMuted,
                            showChevron: true
                        )
                    }
                    .buttonStyle(.plain)
                } header: {
                    sectionHeader("数据权限")
                }

                // MARK: - 隐私与支持
                Section {
                    if let privacyPolicyURL = AppConfiguration.privacyPolicyURL {
                        Link(destination: privacyPolicyURL) {
                            settingsRow(
                                icon: "hand.raised.fill",
                                iconBackground: TodayTheme.teal,
                                title: "隐私政策",
                                showChevron: true
                            )
                        }
                    }

                    if let termsOfServiceURL = AppConfiguration.termsOfServiceURL {
                        Link(destination: termsOfServiceURL) {
                            settingsRow(
                                icon: "doc.text.fill",
                                iconBackground: TodayTheme.blue,
                                title: "服务条款",
                                showChevron: true
                            )
                        }
                    }

                    NavigationLink {
                        DataExplanationView()
                    } label: {
                        HStack(spacing: 12) {
                            iconBadge(systemName: "info.circle.fill", background: TodayTheme.purple)

                            Text("数据说明")
                                .font(.system(size: 16))
                                .foregroundStyle(TodayTheme.ink)
                        }
                    }

                    if let supportEmail = AppConfiguration.supportEmail,
                       let mailURL = URL(string: "mailto:\(supportEmail)") {
                        Link(destination: mailURL) {
                            settingsRow(
                                icon: "envelope.fill",
                                iconBackground: TodayTheme.accent,
                                title: "联系我们",
                                showChevron: true
                            )
                        }
                    }

                    if let websiteURL = AppConfiguration.websiteURL {
                        Link(destination: websiteURL) {
                            settingsRow(
                                icon: "globe",
                                iconBackground: TodayTheme.inkSoft,
                                title: "官网",
                                showChevron: true
                            )
                        }
                    }
                } header: {
                    sectionHeader("隐私与支持")
                }

                // MARK: - 数据管理
                Section {
                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        HStack(spacing: 12) {
                            iconBadge(systemName: "trash.fill", background: .red)

                            Text("清除所有标注和记录")
                                .font(.system(size: 16))
                                .foregroundStyle(.red)
                        }
                    }
                } header: {
                    sectionHeader("数据管理")
                }

                // MARK: - Footer Version
                Section {
                    Text("ToDay v\(versionText)")
                        .font(.system(size: 12))
                        .foregroundStyle(TodayTheme.inkFaint)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("设置")
            .scrollContentBackground(.hidden)
            .background(TodayTheme.background)
            .confirmationDialog(
                "确认清除？",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("清除所有标注和记录", role: .destructive) {
                    Task {
                        await clearAllData()
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("此操作将删除所有手动标注和心情记录，无法撤销。")
            }
            .overlay(alignment: .bottom) {
                if showClearSuccess {
                    successToast
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 18)
                }
            }
            .task {
                refreshStatuses()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                refreshStatuses()
            }
        }
    }

    // MARK: - Row Components

    @ViewBuilder
    private func iconBadge(systemName: String, background: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    @ViewBuilder
    private func settingsRow(
        icon: String,
        iconBackground: Color,
        title: String,
        detail: String? = nil,
        detailColor: Color = TodayTheme.inkMuted,
        showChevron: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            iconBadge(systemName: icon, background: iconBackground)

            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(TodayTheme.ink)

            Spacer()

            if let detail {
                Text(detail)
                    .font(.system(size: 15))
                    .foregroundStyle(detailColor)
            }

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TodayTheme.inkFaint)
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(TodayTheme.inkMuted)
            .tracking(2.0)
    }

    // MARK: - Toast

    private var successToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("已清除所有标注和记录")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(TodayTheme.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(TodayTheme.card)
        .overlay(
            Capsule()
                .stroke(TodayTheme.border, lineWidth: 0.5)
        )
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 6)
    }

    // MARK: - Computed Properties

    private var shortVersionText: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    private var versionText: String {
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
        let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(shortVersion) (\(buildVersion))"
    }

    private var watchStatusText: String {
        if !WCSession.isSupported() { return "不支持" }
        if !connectivityManager.isWatchPaired { return "未配对" }
        if !connectivityManager.isWatchAppInstalled { return "未安装 App" }
        if connectivityManager.isWatchReachable { return "已连接" }
        return "已配对"
    }

    private var watchStatusIcon: String {
        if connectivityManager.isWatchReachable {
            return "checkmark.circle.fill"
        }
        if connectivityManager.isWatchPaired && connectivityManager.isWatchAppInstalled {
            return "applewatch"
        }
        return "exclamationmark.circle.fill"
    }

    private var watchStatusColor: Color {
        if connectivityManager.isWatchReachable { return .green }
        if connectivityManager.isWatchPaired && connectivityManager.isWatchAppInstalled { return TodayTheme.inkMuted }
        return .orange
    }

    private var healthStatusText: String {
        switch healthStatus {
        case .sharingAuthorized:
            return "已授权"
        case .sharingDenied:
            return "未授权"
        case .notDetermined:
            return "未授权"
        @unknown default:
            return "未知"
        }
    }

    private var locationStatusText: String {
        switch locationStatus {
        case .authorizedAlways:
            return "始终允许"
        case .authorizedWhenInUse:
            return "使用时允许"
        case .denied:
            return "已拒绝"
        case .restricted:
            return "受限"
        case .notDetermined:
            return "未授权"
        @unknown default:
            return "未知"
        }
    }

    private var photoStatusText: String {
        switch photoStatus {
        case .authorized:
            return "已授权"
        case .limited:
            return "已选择部分照片"
        case .denied:
            return "已拒绝"
        case .restricted:
            return "受限"
        case .notDetermined:
            return "未授权"
        @unknown default:
            return "未知"
        }
    }

    // MARK: - Actions

    private func refreshStatuses() {
        if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            healthStatus = healthStore.authorizationStatus(for: heartRateType)
        } else {
            healthStatus = .notDetermined
        }
        locationStatus = locationManager.authorizationStatus
        photoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    @MainActor
    private func clearAllData() async {
        let sharedDefaults = UserDefaults(suiteName: SharedAppGroup.identifier)
        sharedDefaults?.removeObject(forKey: annotationStorageKey)
        UserDefaults.standard.removeObject(forKey: annotationStorageKey)

        let moodDescriptor = FetchDescriptor<MoodRecordEntity>()
        let timelineDescriptor = FetchDescriptor<DayTimelineEntity>()

        do {
            let records = try modelContext.fetch(moodDescriptor)
            for record in records {
                modelContext.delete(record)
            }

            let timelines = try modelContext.fetch(timelineDescriptor)
            for timeline in timelines {
                modelContext.delete(timeline)
            }

            try modelContext.save()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                showClearSuccess = true
            }
            Task {
                try? await Task.sleep(for: .seconds(1.4))
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showClearSuccess = false
                    }
                }
            }
        } catch {
            assertionFailure("清除数据失败：\(error.localizedDescription)")
        }
    }
}

private struct DataExplanationView: View {
    var body: some View {
        ScrollView {
            Text(
                """
                ToDay 的所有数据（健康、位置、照片）仅存储在你的设备本地。

                我们不上传、不收集、不分享任何个人数据。

                你可以随时在此页面清除所有标注和心情记录。
                """
            )
            .font(.system(size: 15))
            .foregroundStyle(TodayTheme.ink)
            .lineSpacing(5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .background(TodayTheme.background)
        .navigationTitle("数据说明")
        .navigationBarTitleDisplayMode(.inline)
    }
}
