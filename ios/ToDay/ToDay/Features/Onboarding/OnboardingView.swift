import CoreLocation
import HealthKit
import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    private enum Step {
        case permissions
        case smartRecording
    }

    @State private var step: Step = .permissions

    var body: some View {
        switch step {
        case .permissions:
            permissionsPage
                .transition(.move(edge: .leading))
        case .smartRecording:
            SmartRecordingPage(
                onEnable: { onComplete() },
                onSkip: { onComplete() }
            )
            .transition(.move(edge: .trailing))
        }
    }

    private var permissionsPage: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 12) {
                Text("ToDay")
                    .font(.system(size: 42, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(.primary)

                Text("把每一天变成可见的故事")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
            }

            Spacer()
                .frame(height: 48)

            VStack(spacing: 14) {
                permissionRow(
                    icon: "heart.fill",
                    iconColor: TodayTheme.rose,
                    title: "健康数据",
                    detail: "读取心率、步数、睡眠和运动，自动生成每日时间轴。"
                )
                permissionRow(
                    icon: "location.fill",
                    iconColor: TodayTheme.teal,
                    title: "位置信息",
                    detail: "记录到访地点，让事件有地理上下文。"
                )
                permissionRow(
                    icon: "photo.fill",
                    iconColor: Color.accentColor,
                    title: "照片库",
                    detail: "匹配当天拍的照片到对应事件。"
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
                    await requestAllPermissions()
                    withAnimation {
                        step = .smartRecording
                    }
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
                withAnimation {
                    step = .smartRecording
                }
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
        detail: String
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)

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
                .stroke(Color(UIColor.separator), lineWidth: 0.5)
        )
    }

    private func requestAllPermissions() async {
        if HKHealthStore.isHealthDataAvailable() {
            let store = HKHealthStore()
            let types = Set([
                HKObjectType.quantityType(forIdentifier: .heartRate),
                HKObjectType.quantityType(forIdentifier: .stepCount),
                HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
                HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
                HKObjectType.workoutType(),
                HKObjectType.activitySummaryType()
            ]
            .compactMap { $0 })

            try? await store.requestAuthorization(toShare: [], read: types)
        }

        let locationManager = CLLocationManager()
        locationManager.requestAlwaysAuthorization()
    }
}
