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
                // MARK: - 设备与同步
                Section {
                    HStack {
                        Text("手表连接")
                        Spacer()
                        Text(watchStatusText)
                            .foregroundStyle(watchStatusColor)
                    }
                } header: {
                    Text("设备与同步")
                }

                // MARK: - Echo 回响
                Section {
                    Picker("回响频率", selection: Binding(
                        get: { echoViewModel.globalFrequency ?? .medium },
                        set: { echoViewModel.globalFrequency = $0 }
                    )) {
                        Text("高").tag(EchoFrequency.high)
                        Text("中").tag(EchoFrequency.medium)
                        Text("低").tag(EchoFrequency.low)
                        Text("关闭").tag(EchoFrequency.off)
                    }

                    Picker("回响时间", selection: Binding(
                        get: { echoViewModel.echoHour },
                        set: { echoViewModel.echoHour = $0 }
                    )) {
                        ForEach(6..<23, id: \.self) { hour in
                            Text(String(format: "%02d:00", hour)).tag(hour)
                        }
                    }

                    Toggle("关怀推送", isOn: Binding(
                        get: { echoViewModel.careNudgesEnabled },
                        set: { echoViewModel.careNudgesEnabled = $0 }
                    ))
                } header: {
                    Text("Echo 回响")
                }

                // MARK: - Echo AI
                Section {
                    HStack {
                        Text("DeepSeek API Key")
                        Spacer()
                        Text("已配置")
                            .foregroundStyle(.green)
                    }
                } header: {
                    Text("AI 服务")
                } footer: {
                    Text("Echo 使用 DeepSeek AI 进行对话和分析。")
                }

                Section {
                    EchoPersonalityPicker(
                        selection: Binding(
                            get: {
                                guard let raw = UserDefaults.standard.string(forKey: "today.echo.personality") else {
                                    return .gentle
                                }
                                return EchoPersonality(rawValue: raw) ?? .gentle
                            },
                            set: {
                                UserDefaults.standard.set($0.rawValue, forKey: "today.echo.personality")
                            }
                        )
                    )
                } header: {
                    Text("Echo 性格")
                } footer: {
                    Text("选择 Echo 的说话风格，影响所有 AI 对话和洞察的语气。")
                }

                // MARK: - 数据权限
                Section {
                    Button {
                        UIApplication.shared.open(URL(string: "x-apple-health://")!)
                    } label: {
                        HStack {
                            Text("健康数据")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(healthStatusText)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                    } label: {
                        HStack {
                            Text("位置权限")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(locationStatusText)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                    } label: {
                        HStack {
                            Text("照片权限")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(photoStatusText)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("数据权限")
                }

                // MARK: - 隐私与支持
                Section {
                    if let privacyPolicyURL = AppConfiguration.privacyPolicyURL {
                        Link(destination: privacyPolicyURL) {
                            HStack {
                                Text("隐私政策")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.forward")
                                    .font(.footnote)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    if let termsOfServiceURL = AppConfiguration.termsOfServiceURL {
                        Link(destination: termsOfServiceURL) {
                            HStack {
                                Text("服务条款")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.forward")
                                    .font(.footnote)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    NavigationLink("数据说明") {
                        DataExplanationView()
                    }

                    if let supportEmail = AppConfiguration.supportEmail,
                       let mailURL = URL(string: "mailto:\(supportEmail)") {
                        Link(destination: mailURL) {
                            HStack {
                                Text("联系我们")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.forward")
                                    .font(.footnote)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    if let websiteURL = AppConfiguration.websiteURL {
                        Link(destination: websiteURL) {
                            HStack {
                                Text("官网")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.forward")
                                    .font(.footnote)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                } header: {
                    Text("隐私与支持")
                }

                // MARK: - 数据管理
                Section {
                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        Text("清除所有标注和记录")
                    }
                } header: {
                    Text("数据管理")
                }

                // MARK: - Footer Version
                Section {
                } footer: {
                    Text("Unfold v\(versionText)")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColor.background)
            .navigationTitle("设置")
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

    // MARK: - Toast

    private var successToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("已清除所有标注和记录")
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(Capsule())
    }

    // MARK: - Computed Properties

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

    private var watchStatusColor: Color {
        if connectivityManager.isWatchReachable { return .green }
        if connectivityManager.isWatchPaired && connectivityManager.isWatchAppInstalled { return .secondary }
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
        List {
            Section {
                Text(
                    """
                    Unfold 的所有数据（位置、活动）仅存储在你的设备本地。

                    我们不上传、不收集、不分享任何个人数据。

                    你可以随时在设置页面清除所有标注和心情记录。
                    """
                )
                .font(.body)
                .foregroundStyle(.primary)
                .lineSpacing(4)
            }
        }
        .navigationTitle("数据说明")
        .navigationBarTitleDisplayMode(.inline)
    }
}
