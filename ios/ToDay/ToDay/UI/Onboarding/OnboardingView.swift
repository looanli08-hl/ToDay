import CoreLocation
import CoreMotion
import SwiftUI

// MARK: - Location Permission Coordinator

@MainActor
final class LocationPermissionCoordinator: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
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
            authorizationStatus = manager.authorizationStatus
        }
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse
    }

    var hasAlwaysAuthorization: Bool {
        authorizationStatus == .authorizedAlways
    }

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @AppStorage("today.hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var locationCoordinator = LocationPermissionCoordinator()
    @State private var currentStep = 0

    var body: some View {
        ZStack {
            AppColor.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress
                HStack(spacing: AppSpacing.xxs) {
                    ForEach(0..<4) { index in
                        Capsule()
                            .fill(index <= currentStep ? AppColor.accent : AppColor.labelQuaternary.opacity(0.3))
                            .frame(height: 3)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)

                Spacer()

                // Content
                Group {
                    switch currentStep {
                    case 0:
                        valueStep
                    case 1:
                        locationStep
                    case 2:
                        motionStep
                    case 3:
                        completeStep
                    default:
                        EmptyView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                Spacer()
            }
        }
    }

    // MARK: - Step 1: Value

    private var valueStep: some View {
        VStack(spacing: AppSpacing.lg) {
            Text("Unfold")
                .heroStyle()

            Text("把你的一天变成一张\n会让你想看的生活画卷")
                .font(AppFont.bodyRegular())
                .foregroundStyle(AppColor.labelSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)

            Spacer().frame(height: AppSpacing.xl)

            VStack(spacing: AppSpacing.md) {
                featureRow(icon: "location.fill", text: "自动感知你去过的地方")
                featureRow(icon: "figure.walk", text: "识别步行、通勤、运动")
                featureRow(icon: "sparkles", text: "AI 帮你回看每���天")
            }

            Spacer().frame(height: AppSpacing.xl)

            primaryButton("开始") {
                withAnimation(.spring(dampingFraction: 0.8)) {
                    currentStep = 1
                }
            }
        }
        .padding(.horizontal, AppSpacing.xl)
    }

    // MARK: - Step 2: Location

    private var locationStep: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "location.fill")
                .font(.system(size: 40))
                .foregroundStyle(AppColor.accent)

            Text("位置权限")
                .font(AppFont.heading())
                .foregroundStyle(AppColor.label)

            Text("Unfold 需要后台位置权限来感知你每天的轨迹，数据完全保存在本地。")
                .font(AppFont.bodyRegular())
                .foregroundStyle(AppColor.labelSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Spacer().frame(height: AppSpacing.lg)

            if locationCoordinator.isDenied {
                Text("位置权限被拒绝，请前往系统设置开启。")
                    .font(AppFont.small())
                    .foregroundStyle(AppColor.mood)

                primaryButton("前往设置") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } else if locationCoordinator.hasAlwaysAuthorization {
                primaryButton("继续") {
                    withAnimation(.spring(dampingFraction: 0.8)) {
                        currentStep = 2
                    }
                }
            } else if locationCoordinator.isAuthorized {
                VStack(spacing: AppSpacing.sm) {
                    Text("已授权「使用时」，建议升级为「始终」以支持后台记录。")
                        .font(AppFont.small())
                        .foregroundStyle(AppColor.labelTertiary)
                        .multilineTextAlignment(.center)

                    primaryButton("升级为始终允许") {
                        locationCoordinator.requestAlways()
                    }

                    secondaryButton("跳过") {
                        withAnimation(.spring(dampingFraction: 0.8)) {
                            currentStep = 2
                        }
                    }
                }
            } else {
                primaryButton("允许位置访问") {
                    locationCoordinator.requestWhenInUse()
                }
            }
        }
        .padding(.horizontal, AppSpacing.xl)
    }

    // MARK: - Step 3: Motion

    private var motionStep: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "figure.walk")
                .font(.system(size: 40))
                .foregroundStyle(AppColor.accent)

            Text("运动权限")
                .font(AppFont.heading())
                .foregroundStyle(AppColor.label)

            Text("Unfold 通过运动传感器识别你的活动状态，让时间轴更精准。")
                .font(AppFont.bodyRegular())
                .foregroundStyle(AppColor.labelSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Spacer().frame(height: AppSpacing.lg)

            primaryButton("允许运动访问") {
                Task {
                    if CMMotionActivityManager.isActivityAvailable() {
                        let manager = CMMotionActivityManager()
                        let now = Date()
                        let oneMinAgo = now.addingTimeInterval(-60)
                        manager.queryActivityStarting(from: oneMinAgo, to: now, to: .main) { _, _ in }
                    }
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    withAnimation(.spring(dampingFraction: 0.8)) {
                        currentStep = 3
                    }
                }
            }

            secondaryButton("跳过") {
                withAnimation(.spring(dampingFraction: 0.8)) {
                    currentStep = 3
                }
            }
        }
        .padding(.horizontal, AppSpacing.xl)
    }

    // MARK: - Step 4: Complete

    private var completeStep: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppColor.accent)

            Text("准备就绪")
                .font(AppFont.heading())
                .foregroundStyle(AppColor.label)

            Text("Unfold 会在后台默默记录你的一天，\n睡前打开看看你的今日画卷。")
                .font(AppFont.bodyRegular())
                .foregroundStyle(AppColor.labelSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Spacer().frame(height: AppSpacing.xl)

            primaryButton("开始使用") {
                UserDefaults.standard.set(true, forKey: "today.smartRecording.enabled")
                hasCompletedOnboarding = true
            }
        }
        .padding(.horizontal, AppSpacing.xl)
    }

    // MARK: - Shared Components

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(AppColor.accent)
                .frame(width: 24)

            Text(text)
                .font(AppFont.bodyRegular())
                .foregroundStyle(AppColor.labelSecondary)
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.body())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(AppColor.accent)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous))
        }
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.bodyRegular())
                .foregroundStyle(AppColor.labelTertiary)
        }
    }
}
