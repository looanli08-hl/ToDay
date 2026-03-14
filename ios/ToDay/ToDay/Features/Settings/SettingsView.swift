import CoreLocation
import HealthKit
import Photos
import SwiftData
import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
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
            Form {
                Section("数据权限") {
                    Button {
                        UIApplication.shared.open(URL(string: "x-apple-health://")!)
                    } label: {
                        permissionRow(
                            title: "健康数据",
                            detail: healthStatusText,
                            iconName: healthStatus == .sharingAuthorized
                                ? "checkmark.circle.fill"
                                : "exclamationmark.circle.fill",
                            iconColor: healthStatus == .sharingAuthorized
                                ? .green
                                : .orange
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                    } label: {
                        permissionRow(
                            title: "位置权限",
                            detail: locationStatusText
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                    } label: {
                        permissionRow(
                            title: "照片权限",
                            detail: photoStatusText
                        )
                    }
                    .buttonStyle(.plain)
                }

                Section("隐私") {
                    if let privacyPolicyURL = AppConfiguration.privacyPolicyURL {
                        Link(destination: privacyPolicyURL) {
                            simpleRow(title: "隐私政策")
                        }
                    }

                    NavigationLink("数据说明") {
                        DataExplanationView()
                    }
                }

                Section("关于") {
                    HStack {
                        Text("版本")
                            .foregroundStyle(TodayTheme.ink)
                        Spacer()
                        Text(versionText)
                            .foregroundStyle(TodayTheme.inkMuted)
                    }

                    if let supportEmail = AppConfiguration.supportEmail,
                       let mailURL = URL(string: "mailto:\(supportEmail)") {
                        Link(destination: mailURL) {
                            simpleRow(title: "联系我们")
                        }
                    }
                }

                Section("数据管理") {
                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        Text("清除所有标注和记录")
                            .foregroundStyle(Color.red)
                    }
                }
            }
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

    private var versionText: String {
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
        let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(shortVersion) (\(buildVersion))"
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

    @ViewBuilder
    private func permissionRow(
        title: String,
        detail: String,
        iconName: String? = nil,
        iconColor: Color = TodayTheme.inkMuted
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundStyle(TodayTheme.ink)

            Spacer()

            Text(detail)
                .foregroundStyle(TodayTheme.inkMuted)

            if let iconName {
                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
            }
        }
    }

    private func simpleRow(title: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(TodayTheme.ink)
            Spacer()
            Image(systemName: "arrow.up.right.square")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(TodayTheme.inkMuted)
        }
    }

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
