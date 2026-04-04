import CoreMotion
import SwiftUI

struct SmartRecordingPage: View {
    let onEnable: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 0.95, green: 0.45, blue: 0.35), Color(red: 0.98, green: 0.60, blue: 0.38)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 12) {
                Text("开启智能记录")
                    .font(.system(size: 28, weight: .bold))

                Text("ToDay 会在后台安静记录你的一天——\n运动、出行、作息，都会自动出现在时间线上。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            VStack(spacing: 8) {
                featureRow(icon: "figure.walk", text: "自动识别步行、跑步、骑行")
                featureRow(icon: "location.fill", text: "记录到访地点和停留时间")
                featureRow(icon: "moon.fill", text: "推断睡眠和作息规律")
                featureRow(icon: "lock.shield.fill", text: "所有数据仅存储在你的设备上")
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 12) {
                Button(action: {
                    UserDefaults.standard.set(true, forKey: "today.smartRecording.enabled")
                    requestCoreMotionAuthorization()
                    onEnable()
                }) {
                    Text("开启智能记录")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.95, green: 0.45, blue: 0.35), Color(red: 0.98, green: 0.60, blue: 0.38)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Button("稍后再说") {
                    UserDefaults.standard.set(false, forKey: "today.smartRecording.enabled")
                    onSkip()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .background(AppColor.background)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(AppColor.labelSecondary)
                .frame(width: 28)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(AppColor.label)
            Spacer()
        }
    }

    private func requestCoreMotionAuthorization() {
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        let manager = CMMotionActivityManager()
        // Querying activities triggers the authorization prompt
        manager.queryActivityStarting(
            from: Date(),
            to: Date(),
            to: .main
        ) { _, _ in }
    }
}
