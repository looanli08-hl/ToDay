import CoreLocation
import CoreMotion
import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var locationStatus: PermissionStatus = .pending
    @State private var motionStatus: PermissionStatus = .pending
    @State private var currentStep = 0

    private enum PermissionStatus {
        case pending, granted, denied
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 12) {
                Text("Unfold")
                    .font(.system(size: 42, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(.primary)

                Text("Your day, unfolded.")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
            }

            Spacer()
                .frame(height: 48)

            VStack(spacing: 14) {
                permissionRow(
                    icon: "location.fill",
                    iconColor: TodayTheme.teal,
                    title: "位置信息",
                    detail: "自动记录你到过的地方和停留时间，零操作生成一天的轨迹。",
                    status: locationStatus,
                    step: 0
                )
                permissionRow(
                    icon: "figure.walk",
                    iconColor: TodayTheme.rose,
                    title: "运动与健身",
                    detail: "感知走路、跑步、通勤等活动，让时间轴更完整。",
                    status: motionStatus,
                    step: 1
                )
            }
            .padding(.horizontal, 24)

            Spacer()
                .frame(height: 16)

            Text("所有数据仅存储在本地，不会上传。")
                .font(.system(size: 13))
                .foregroundStyle(Color(UIColor.quaternaryLabel))

            Spacer()

            Button {
                Task {
                    await requestPermissions()
                    onComplete()
                }
            } label: {
                Text("开始记录")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)

            Button("稍后设置") {
                onComplete()
            }
            .font(.system(size: 14))
            .foregroundStyle(Color(UIColor.tertiaryLabel))
            .padding(.bottom, 12)
        }
        .background(Color(UIColor.systemGroupedBackground))
    }

    private func permissionRow(
        icon: String,
        iconColor: Color,
        title: String,
        detail: String,
        status: PermissionStatus,
        step: Int
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)

                    if status == .granted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.green)
                    }
                }

                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
                    .lineSpacing(2)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(status == .granted ? Color.green.opacity(0.3) : Color(UIColor.separator), lineWidth: 0.5)
        )
    }

    private func requestPermissions() async {
        // 1. Location — request "Always" for background tracking
        let locationManager = CLLocationManager()
        let locStatus = locationManager.authorizationStatus
        if locStatus == .notDetermined {
            locationManager.requestAlwaysAuthorization()
            // Give time for the system dialog
            try? await Task.sleep(for: .milliseconds(500))
        }
        let updatedLocStatus = locationManager.authorizationStatus
        locationStatus = (updatedLocStatus == .authorizedAlways || updatedLocStatus == .authorizedWhenInUse)
            ? .granted : (updatedLocStatus == .denied ? .denied : .pending)

        // 2. Motion — triggers the system permission dialog
        let motionManager = CMMotionActivityManager()
        if CMMotionActivityManager.isActivityAvailable() {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                motionManager.queryActivityStarting(
                    from: Date().addingTimeInterval(-3600),
                    to: Date(),
                    to: .main
                ) { _, error in
                    if error != nil {
                        Task { @MainActor in motionStatus = .denied }
                    } else {
                        Task { @MainActor in motionStatus = .granted }
                    }
                    continuation.resume()
                }
            }
        }
    }
}
