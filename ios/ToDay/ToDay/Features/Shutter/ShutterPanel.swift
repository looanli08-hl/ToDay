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
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
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
                        if mode == .menu {
                            Text("关闭")
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.body.weight(.medium))
                                Text("返回")
                            }
                        }
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

    private var navigationTitle: String {
        switch mode {
        case .menu: return "快门"
        case .text: return "文字快门"
        case .voice: return "语音快门"
        case .camera(.photo): return "拍照"
        case .camera(.video): return "视频"
        }
    }

    // MARK: - Menu View

    private var menuView: some View {
        List {
            Section {
                Text("捕捉此刻的灵光一现，不用分类、不用打标签。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
            }

            Section {
                shutterRow(
                    icon: "text.cursor",
                    title: "文字",
                    subtitle: "写下脑海里的念头",
                    tint: .accentColor
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mode = .text
                    }
                }

                shutterRow(
                    icon: "mic.fill",
                    title: "语音",
                    subtitle: "说出来，比打字更快",
                    tint: TodayTheme.purple
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mode = .voice
                    }
                }

                shutterRow(
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

                shutterRow(
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
        }
        .listStyle(.insetGrouped)
    }

    private func shutterRow(
        icon: String,
        title: String,
        subtitle: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
            }
        }
    }

    // MARK: - Text View

    private var textView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("写完按发送，会自动出现在时间线上。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
