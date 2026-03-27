import SwiftUI

struct ShutterFloatingButton: View {
    @ObservedObject var viewModel: TodayViewModel

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
            viewModel.showShutterPanel = true
        } label: {
            Image(systemName: "camera.aperture")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Circle().fill(Color.accentColor))
                .shadow(color: Color.accentColor.opacity(0.40), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("快门")
        .accessibilityHint("打开快门面板")
    }
}
