import SwiftUI
import SwiftData
import CoreLocation

struct SettingsView: View {
    @AppStorage(DeepSeekAIProvider.apiKeyDefaultsKey) private var apiKey: String = ""
    @State private var locationStatus: String = ""
    @State private var showClearConfirmation = false
    @State private var showClearSuccess = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("DeepSeek API Key")
                            .font(AppFont.body())
                            .foregroundStyle(AppColor.label)

                        SecureField("sk-...", text: $apiKey)
                            .font(AppFont.small())
                            .foregroundStyle(AppColor.label)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                    }
                } header: {
                    sectionHeader("AI 设置")
                } footer: {
                    Text("Echo 使用 DeepSeek API 生成洞察。API Key 仅保存在本地。")
                        .font(AppFont.micro())
                        .foregroundStyle(AppColor.labelQuaternary)
                }

                Section {
                    HStack {
                        Text("位置权限")
                            .font(AppFont.bodyRegular())
                            .foregroundStyle(AppColor.label)
                        Spacer()
                        Text(locationStatus)
                            .font(AppFont.small())
                            .foregroundStyle(AppColor.labelTertiary)
                    }

                    Button("前往系统设置") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(AppFont.bodyRegular())
                    .foregroundStyle(AppColor.accent)
                } header: {
                    sectionHeader("权限")
                }

                Section {
                    Link(destination: URL(string: "https://looanli08-hl.github.io/ToDay/privacy.html")!) {
                        Text("隐私政策")
                            .font(AppFont.bodyRegular())
                            .foregroundStyle(AppColor.accent)
                    }
                } header: {
                    sectionHeader("隐私")
                }

                Section {
                    Button("清除所有数据") {
                        showClearConfirmation = true
                    }
                    .font(AppFont.bodyRegular())
                    .foregroundStyle(AppColor.mood)
                } header: {
                    sectionHeader("数据")
                }

                Section {
                    HStack {
                        Text("版本")
                            .font(AppFont.bodyRegular())
                            .foregroundStyle(AppColor.label)
                        Spacer()
                        Text("Unfold v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")")
                            .font(AppFont.micro())
                            .foregroundStyle(AppColor.labelQuaternary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColor.background)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                updateLocationStatus()
            }
            .confirmationDialog("确认清除所有数据？此操作不可撤销。", isPresented: $showClearConfirmation, titleVisibility: .visible) {
                Button("清除所有数据", role: .destructive) {
                    clearAllData()
                }
            }
            .alert("已清除", isPresented: $showClearSuccess) {
                Button("好") {}
            } message: {
                Text("所有本地数据已清除。")
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(AppFont.micro())
            .foregroundStyle(AppColor.labelTertiary)
            .tracking(1.5)
    }

    private func updateLocationStatus() {
        let status = CLLocationManager().authorizationStatus
        switch status {
        case .authorizedAlways: locationStatus = "始终允许"
        case .authorizedWhenInUse: locationStatus = "使用时"
        case .denied: locationStatus = "已拒绝"
        case .restricted: locationStatus = "受限"
        case .notDetermined: locationStatus = "未设置"
        @unknown default: locationStatus = "未知"
        }
    }

    private func clearAllData() {
        do {
            try modelContext.delete(model: MoodRecordEntity.self)
            try modelContext.delete(model: DayTimelineEntity.self)
            try modelContext.delete(model: SensorReadingEntity.self)
            try modelContext.delete(model: DailySummaryEntity.self)
            try modelContext.delete(model: EchoMessageEntity.self)
            try modelContext.save()
            showClearSuccess = true
        } catch {
            print("Clear data failed: \(error)")
        }
    }
}
