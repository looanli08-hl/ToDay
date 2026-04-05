import SwiftUI
import CoreLocation

struct SettingsView: View {
    @AppStorage(DeepSeekAIProvider.apiKeyDefaultsKey) private var apiKey: String = ""
    @State private var locationStatus: String = ""

    var body: some View {
        NavigationStack {
            List {
                // API Key
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
                    Text("AI 设置")
                        .font(AppFont.small())
                        .foregroundStyle(AppColor.labelTertiary)
                } footer: {
                    Text("Echo 使用 DeepSeek API 生成洞察和对话。API Key 仅保存在本地。")
                        .font(AppFont.small())
                        .foregroundStyle(AppColor.labelQuaternary)
                }

                // Permissions
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
                    Text("权限")
                        .font(AppFont.small())
                        .foregroundStyle(AppColor.labelTertiary)
                }

                // Privacy
                Section {
                    Button("隐私政策") {
                        // TODO: Open privacy policy URL
                    }
                    .font(AppFont.bodyRegular())
                    .foregroundStyle(AppColor.accent)
                } header: {
                    Text("隐私")
                        .font(AppFont.small())
                        .foregroundStyle(AppColor.labelTertiary)
                }

                // Data
                Section {
                    Button("清除所有数据") {
                        // Placeholder — data clearing will be wired in future
                    }
                    .font(AppFont.bodyRegular())
                    .foregroundStyle(AppColor.mood)
                } header: {
                    Text("数据")
                        .font(AppFont.small())
                        .foregroundStyle(AppColor.labelTertiary)
                }

                // Version
                Section {
                    HStack {
                        Text("版本")
                            .font(AppFont.bodyRegular())
                            .foregroundStyle(AppColor.label)
                        Spacer()
                        Text("Unfold v1.0.0")
                            .font(AppFont.small())
                            .foregroundStyle(AppColor.labelTertiary)
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
        }
    }

    private func updateLocationStatus() {
        let status = CLLocationManager().authorizationStatus
        switch status {
        case .authorizedAlways:
            locationStatus = "始终"
        case .authorizedWhenInUse:
            locationStatus = "使用时"
        case .denied:
            locationStatus = "已拒绝"
        case .restricted:
            locationStatus = "受限"
        case .notDetermined:
            locationStatus = "未设置"
        @unknown default:
            locationStatus = "未知"
        }
    }
}
