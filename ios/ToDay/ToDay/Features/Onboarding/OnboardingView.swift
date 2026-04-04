import CoreLocation
import CoreMotion
import SwiftUI

// MARK: - OnboardingStep

enum OnboardingStep: Equatable {
    case value               // Show app value, no permission dialog
    case locationWhenInUse   // Explain location, trigger whenInUse dialog
    case locationAlwaysUpgrade // Explain Always benefit, trigger always upgrade dialog
    case locationDenied      // Recovery: location was denied, show Settings button
    case motion              // Explain motion, trigger motion dialog
    case complete            // Success — call onComplete()
}

// MARK: - LocationPermissionCoordinator

@MainActor
final class LocationPermissionCoordinator: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
        authorizationStatus = locationManager.authorizationStatus
    }

    func requestWhenInUse() {
        locationManager.requestWhenInUseAuthorization()
    }

    func requestAlways() {
        locationManager.requestAlwaysAuthorization()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
        }
    }
}

// MARK: - OnboardingView

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var step: OnboardingStep = .value
    @StateObject private var locationCoordinator = LocationPermissionCoordinator()
    @State private var motionManager = CMMotionActivityManager()

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            switch step {
            case .value:
                valueStepView
            case .locationWhenInUse:
                locationWhenInUseStepView
            case .locationAlwaysUpgrade:
                locationAlwaysUpgradeStepView
            case .locationDenied:
                locationDeniedStepView
            case .motion:
                motionStepView
            case .complete:
                completeStepView
            }
        }
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    // MARK: - Step Views

    private var valueStepView: some View {
        stepContainer {
            Spacer()

            VStack(spacing: 12) {
                Text("Unfold")
                    .font(.system(size: 42, weight: .regular, design: .serif).italic())
                    .foregroundStyle(.primary)

                Text("Your day, unfolded.")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
            }

            Spacer()
                .frame(height: 40)

            Text("把你的一天自动变成一张精美的生活画卷。零手动操作，睡前打开，一眼看懂今天。")
                .font(.body)
                .foregroundStyle(Color(UIColor.secondaryLabel))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            primaryButton("探索 Unfold") {
                step = .locationWhenInUse
            }
        }
    }

    private var locationWhenInUseStepView: some View {
        stepContainer {
            Spacer()

            iconCircle(systemName: "location.fill", color: TodayTheme.teal)

            Spacer()
                .frame(height: 32)

            stepTitle("记录你到过的地方")

            Spacer()
                .frame(height: 12)

            stepDescription("Unfold 在后台持续记录你的位置，自动生成每天的生活轨迹。需要位置权限才能在 App 关闭时继续记录。")

            Spacer()
                .frame(height: 16)

            privacyNote("位置数据仅存储在设备本地，不会上传。")

            Spacer()

            primaryButton("允许位置访问") {
                locationCoordinator.requestWhenInUse()
            }
        }
        .onChange(of: locationCoordinator.authorizationStatus) { _, newStatus in
            switch newStatus {
            case .authorizedWhenInUse:
                step = .locationAlwaysUpgrade
            case .authorizedAlways:
                step = .motion
            case .denied, .restricted:
                step = .locationDenied
            default:
                break
            }
        }
    }

    private var locationAlwaysUpgradeStepView: some View {
        stepContainer {
            Spacer()

            ZStack(alignment: .bottomTrailing) {
                iconCircle(systemName: "location.fill", color: TodayTheme.teal)

                Text("始终允许")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.orange)
                    .clipShape(Capsule())
                    .offset(x: 8, y: 8)
            }

            Spacer()
                .frame(height: 40)

            stepTitle("开启后台记录")

            Spacer()
                .frame(height: 12)

            stepDescription("在下一个系统弹窗中，请选择「始终允许」。这样 Unfold 才能在你关闭 App 后继续记录。")

            Spacer()

            primaryButton("继续") {
                locationCoordinator.requestAlways()
            }
        }
        .onChange(of: locationCoordinator.authorizationStatus) { _, newStatus in
            switch newStatus {
            case .authorizedAlways:
                step = .motion
            case .authorizedWhenInUse, .denied, .restricted:
                step = .locationDenied
            default:
                break
            }
        }
    }

    private var locationDeniedStepView: some View {
        stepContainer {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(Color.orange)

            Spacer()
                .frame(height: 32)

            stepTitle("位置权限受限")

            Spacer()
                .frame(height: 12)

            stepDescription("没有「始终允许」位置权限，Unfold 无法在后台记录。你可以前往设置手动开启，或稍后跳过继续使用（功能受限）。")

            Spacer()

            primaryButton("前往设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }

            Spacer()
                .frame(height: 12)

            Button("稍后设置") {
                withAnimation {
                    step = .smartRecording
                }
            }
            .font(.system(size: 14))
            .foregroundStyle(Color(UIColor.tertiaryLabel))
            .padding(.bottom, 12)
        }
    }

    private var motionStepView: some View {
        stepContainer {
            Spacer()

            iconCircle(systemName: "figure.walk", color: TodayTheme.rose)

            Spacer()
                .frame(height: 32)

            stepTitle("感知你的活动")

            Spacer()
                .frame(height: 12)

            stepDescription("运动识别帮助 Unfold 判断你在走路、跑步还是乘车，让时间轴更完整。")

            Spacer()

            primaryButton("允许运动访问") {
                guard CMMotionActivityManager.isActivityAvailable() else {
                    step = .complete
                    return
                }
                motionManager.queryActivityStarting(
                    from: Date().addingTimeInterval(-3600),
                    to: Date(),
                    to: .main
                ) { _, _ in
                    Task { @MainActor in
                        step = .complete
                    }
                }
            }
        }
    }

    private var completeStepView: some View {
        stepContainer {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.green)

            Spacer()
                .frame(height: 32)

            stepTitle("一切就绪")

            Spacer()
                .frame(height: 12)

            stepDescription("Unfold 已经开始记录你的今天。带着手机出门，睡前打开看看今天的画卷。")

            Spacer()

            primaryButton("开始") {
                onComplete()
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(1.5))
            onComplete()
        }
    }

    // MARK: - Reusable Components

    private func stepContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func iconCircle(systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 32, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 80, height: 80)
            .background(color.opacity(0.12))
            .clipShape(Circle())
    }

    private func stepTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
    }

    private func stepDescription(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(Color(UIColor.secondaryLabel))
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .padding(.horizontal, 8)
    }

    private func privacyNote(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 11))
            Text(text)
                .font(.system(size: 13))
        }
        .foregroundStyle(Color(UIColor.tertiaryLabel))
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
