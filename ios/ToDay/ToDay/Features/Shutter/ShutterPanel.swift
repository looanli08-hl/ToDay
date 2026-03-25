import AVFoundation
import SwiftUI

enum ShutterPanelMode: Equatable {
    case menu
    case text
    case voice
    case camera(CameraPickerMode)
}

struct ShutterPanel: View {
    @ObservedObject var viewModel: TodayViewModel
    @State private var mode: ShutterPanelMode = .menu
    @State private var showCameraUnavailableAlert = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .menu:
                    menuView
                case .text:
                    textView
                case .voice:
                    voiceView
                case .camera(let cameraMode):
                    cameraView(mode: cameraMode)
                }
            }
            .background(TodayTheme.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        if mode == .menu {
                            dismiss()
                        } else {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                mode = .menu
                            }
                        }
                    } label: {
                        Image(systemName: mode == .menu ? "xmark" : "chevron.left")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(TodayTheme.inkSoft)
                            .frame(width: 32, height: 32)
                            .background(TodayTheme.card)
                            .clipShape(Circle())
                    }
                }
            }
            .alert("相机不可用", isPresented: $showCameraUnavailableAlert) {
                Button("好的", role: .cancel) {}
            } message: {
                Text("当前设备没有可用的相机，请在真机上使用此功能。")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Menu View

    private var menuView: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("快门")
                    .font(.system(size: 28, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(TodayTheme.ink)

                Text("捕捉此刻的灵光一现，不用分类、不用打标签。")
                    .font(.system(size: 14))
                    .foregroundStyle(TodayTheme.inkMuted)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            VStack(spacing: 10) {
                shutterOption(
                    icon: "text.cursor",
                    title: "文字",
                    subtitle: "写下脑海里的念头",
                    tint: TodayTheme.accent
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mode = .text
                    }
                }

                shutterOption(
                    icon: "mic.fill",
                    title: "语音",
                    subtitle: "说出来，比打字更快",
                    tint: TodayTheme.purple
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mode = .voice
                    }
                }

                shutterOption(
                    icon: "camera.fill",
                    title: "拍照",
                    subtitle: "用镜头记住这一刻",
                    tint: TodayTheme.teal
                ) {
                    #if targetEnvironment(simulator)
                    showCameraUnavailableAlert = true
                    #else
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mode = .camera(.photo)
                    }
                    #endif
                }

                shutterOption(
                    icon: "video.fill",
                    title: "视频",
                    subtitle: "录一段 15 秒短片",
                    tint: TodayTheme.rose
                ) {
                    #if targetEnvironment(simulator)
                    showCameraUnavailableAlert = true
                    #else
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mode = .camera(.video)
                    }
                    #endif
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    private func shutterOption(
        icon: String,
        title: String,
        subtitle: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .background(tint.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(TodayTheme.ink)

                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(TodayTheme.inkFaint)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TodayTheme.inkFaint)
            }
            .padding(14)
            .background(TodayTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(TodayTheme.border, lineWidth: 1)
            )
            .shadow(color: TodayTheme.ink.opacity(0.06), radius: 16, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Text View

    private var textView: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("文字快门")
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(TodayTheme.ink)

                Text("写完按发送，会自动出现在时间线上。")
                    .font(.system(size: 13))
                    .foregroundStyle(TodayTheme.inkMuted)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()

            ShutterTextComposer { text in
                let record = ShutterRecord(type: .text, textContent: text)
                viewModel.saveShutterRecord(record)
                dismiss()
            } onCancel: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    mode = .menu
                }
            }
        }
    }

    // MARK: - Voice View

    private var voiceView: some View {
        VoiceRecordView { record in
            viewModel.saveShutterRecord(record)
            dismiss()
        } onCancel: {
            withAnimation(.easeInOut(duration: 0.2)) {
                mode = .menu
            }
        }
    }

    // MARK: - Camera View

    private func cameraView(mode: CameraPickerMode) -> some View {
        CameraPickerView(mode: mode) { result in
            handleCameraResult(result)
        } onCancel: {
            withAnimation(.easeInOut(duration: 0.2)) {
                self.mode = .menu
            }
        }
        .ignoresSafeArea()
    }

    private func handleCameraResult(_ result: CameraCaptureResult) {
        switch result {
        case .photo(let data):
            do {
                let filename = try ShutterMediaLibrary.storePhoto(data)
                let record = ShutterRecord(type: .photo, mediaFilename: filename)
                viewModel.saveShutterRecord(record)
                dismiss()
            } catch {
                withAnimation(.easeInOut(duration: 0.2)) {
                    mode = .menu
                }
            }
        case .video(let url):
            do {
                let filename = try ShutterMediaLibrary.copyVideoFile(from: url)
                let asset = AVURLAsset(url: url)
                let duration = CMTimeGetSeconds(asset.duration)
                let record = ShutterRecord(
                    type: .video,
                    mediaFilename: filename,
                    duration: duration.isFinite ? duration : nil
                )
                viewModel.saveShutterRecord(record)
                dismiss()
            } catch {
                withAnimation(.easeInOut(duration: 0.2)) {
                    mode = .menu
                }
            }
        }
    }
}
