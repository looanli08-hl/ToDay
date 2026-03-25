import SwiftUI

struct ShutterFloatingButton: View {
    @ObservedObject var viewModel: TodayViewModel
    @State private var isLongPressing = false
    @State private var longPressStarted = false

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                shutterButton
                    .padding(.trailing, 20)
                    .padding(.bottom, 12)
            }
        }
    }

    private var shutterButton: some View {
        Button {
            if !longPressStarted {
                viewModel.showShutterPanel = true
            }
            longPressStarted = false
        } label: {
            Image(systemName: "camera.aperture")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(
                            isLongPressing
                                ? TodayTheme.rose
                                : TodayTheme.accent
                        )
                )
                .shadow(color: TodayTheme.accent.opacity(0.4), radius: 16, x: 0, y: 8)
                .scaleEffect(isLongPressing ? 1.15 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isLongPressing)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4)
                .onEnded { _ in
                    longPressStarted = true
                    isLongPressing = true
                    viewModel.isRecordingVoice = true
                }
        )
        .accessibilityLabel("快门")
        .accessibilityHint("单击打开快门面板，长按录制语音")
    }
}
