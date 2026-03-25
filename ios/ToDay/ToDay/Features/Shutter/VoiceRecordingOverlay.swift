import AVFoundation
import SwiftUI

struct VoiceRecordingOverlay: View {
    @StateObject private var recorder = VoiceRecorder()
    let onFinish: (Data, TimeInterval) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "waveform")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.accentColor)
                    .symbolEffect(.variableColor.iterative, isActive: recorder.isRecording)

                Text(recorder.isRecording ? "正在录音…" : "准备中…")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(formattedDuration)
                    .font(.system(size: 32, weight: .light, design: .monospaced))
                    .foregroundStyle(.secondary)

                Text("松手结束录音")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
            }
            .padding(32)
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .primary.opacity(0.1), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 24)

            Spacer()
        }
        .background(Color.black.opacity(0.3))
        .ignoresSafeArea()
        .onAppear {
            recorder.startRecording()
        }
        .onDisappear {
            if recorder.isRecording {
                recorder.stopRecording()
            }
            if let data = recorder.recordedData, recorder.duration > 0.5 {
                onFinish(data, recorder.duration)
            } else {
                onCancel()
            }
        }
    }

    private var formattedDuration: String {
        let seconds = Int(recorder.duration)
        let minutes = seconds / 60
        let remainder = seconds % 60
        return String(format: "%d:%02d", minutes, remainder)
    }
}

@MainActor
final class VoiceRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var duration: TimeInterval = 0
    private(set) var recordedData: Data?

    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var startTime: Date?
    private var tempFileURL: URL?

    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("shutter_voice_\(UUID().uuidString).m4a")
        tempFileURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()
            isRecording = true
            startTime = Date()
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, let startTime = self.startTime else { return }
                    self.duration = Date().timeIntervalSince(startTime)
                }
            }
        } catch {
            // Recording failed silently
        }
    }

    func stopRecording() {
        timer?.invalidate()
        timer = nil
        audioRecorder?.stop()
        isRecording = false

        if let startTime {
            duration = Date().timeIntervalSince(startTime)
        }

        if let url = tempFileURL {
            recordedData = try? Data(contentsOf: url)
            try? FileManager.default.removeItem(at: url)
        }
    }
}
