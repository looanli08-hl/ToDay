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
                    sectionHeader("AI")
                } footer: {
                    Text("Echo uses DeepSeek API for insights. Key stored locally only.")
                        .font(AppFont.micro())
                        .foregroundStyle(AppColor.labelQuaternary)
                }

                // Permissions
                Section {
                    HStack {
                        Text("Location")
                            .font(AppFont.bodyRegular())
                            .foregroundStyle(AppColor.label)
                        Spacer()
                        Text(locationStatus)
                            .font(AppFont.small())
                            .foregroundStyle(AppColor.labelTertiary)
                    }

                    Button("System Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(AppFont.bodyRegular())
                    .foregroundStyle(AppColor.accent)
                } header: {
                    sectionHeader("Permissions")
                }

                // Privacy
                Section {
                    Button("Privacy Policy") {
                        // TODO: Open privacy policy URL
                    }
                    .font(AppFont.bodyRegular())
                    .foregroundStyle(AppColor.accent)
                } header: {
                    sectionHeader("Privacy")
                }

                // Data
                Section {
                    Button("Clear All Data") {
                        // Placeholder
                    }
                    .font(AppFont.bodyRegular())
                    .foregroundStyle(AppColor.mood)
                } header: {
                    sectionHeader("Data")
                }

                // Version
                Section {
                    HStack {
                        Text("Version")
                            .font(AppFont.bodyRegular())
                            .foregroundStyle(AppColor.label)
                        Spacer()
                        Text("Unfold v1.0.0")
                            .font(AppFont.micro())
                            .foregroundStyle(AppColor.labelQuaternary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColor.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                updateLocationStatus()
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        Text(title.lowercased())
            .font(AppFont.micro())
            .foregroundStyle(AppColor.labelTertiary)
            .tracking(1.5)
    }

    // MARK: - Helpers

    private func updateLocationStatus() {
        let status = CLLocationManager().authorizationStatus
        switch status {
        case .authorizedAlways:
            locationStatus = "Always"
        case .authorizedWhenInUse:
            locationStatus = "When In Use"
        case .denied:
            locationStatus = "Denied"
        case .restricted:
            locationStatus = "Restricted"
        case .notDetermined:
            locationStatus = "Not Set"
        @unknown default:
            locationStatus = "Unknown"
        }
    }
}
