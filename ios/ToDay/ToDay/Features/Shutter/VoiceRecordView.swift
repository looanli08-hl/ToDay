import AVFoundation
import Speech
import SwiftUI

struct VoiceRecordView: View {
    let onSave: (ShutterRecord) -> Void
    let onCancel: () -> Void

    @StateObject private var recorder = TapVoiceRecorder()

    enum RecordState {
        case idle
        case recording
        case done
    }

    @State private var state: RecordState = .idle
    @State private var transcript: String = ""
    @State private var isTranscribing = false

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("语音快门")
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(TodayTheme.ink)
                Text("点击录音，再次点击停止。")
                    .font(.system(size: 13))
                    .foregroundStyle(TodayTheme.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()

            // Duration display
            Text(formattedDuration)
                .font(.system(size: 48, weight: .light, design: .monospaced))
                .foregroundStyle(state == .recording ? TodayTheme.accent : TodayTheme.inkSoft)

            // Mic button
            Button {
                handleTap()
            } label: {
                Image(systemName: state == .recording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(state == .recording ? TodayTheme.rose : TodayTheme.accent)
                    .symbolEffect(.pulse, isActive: state == .recording)
            }
            .buttonStyle(.plain)

            Text(state == .recording ? "点击停止录音" : state == .idle ? "点击开始录音" : "录音完成")
                .font(.system(size: 14))
                .foregroundStyle(TodayTheme.inkMuted)

            Spacer()

            // Transcript section (shown after recording)
            if state == .done {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("语音转文字")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(TodayTheme.inkMuted)
                            .textCase(.uppercase)
                            .tracking(1.2)

                        if isTranscribing {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }

                    Text(transcript.isEmpty ? (isTranscribing ? "正在识别…" : "未识别到文字") : transcript)
                        .font(.system(size: 15))
                        .foregroundStyle(transcript.isEmpty ? TodayTheme.inkFaint : TodayTheme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(TodayTheme.elevatedCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.horizontal, 20)

                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        // Re-record
                        recorder.reset()
                        transcript = ""
                        state = .idle
                    } label: {
                        Text("重录")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(TodayTheme.inkSoft)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(TodayTheme.card)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(TodayTheme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button {
                        saveRecording()
                    } label: {
                        Text("保存")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(TodayTheme.accent)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
    }

    private var formattedDuration: String {
        let seconds = Int(recorder.duration)
        let minutes = seconds / 60
        let remainder = seconds % 60
        return String(format: "%d:%02d", minutes, remainder)
    }

    private func handleTap() {
        switch state {
        case .idle:
            recorder.startRecording()
            state = .recording
        case .recording:
            recorder.stopRecording()
            state = .done
            transcribeAudio()
        case .done:
            break
        }
    }

    private func transcribeAudio() {
        guard let url = recorder.tempFileURL else { return }
        isTranscribing = true

        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
        let request = SFSpeechURLRecognitionRequest(url: url)

        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else {
                DispatchQueue.main.async {
                    isTranscribing = false
                }
                return
            }

            recognizer?.recognitionTask(with: request) { result, error in
                DispatchQueue.main.async {
                    if let result = result, result.isFinal {
                        transcript = result.bestTranscription.formattedString
                        isTranscribing = false
                    } else if error != nil {
                        isTranscribing = false
                    }
                }
            }
        }
    }

    private func saveRecording() {
        guard let data = recorder.recordedData else { return }
        do {
            let filename = try ShutterMediaLibrary.storeVoice(data)
            let record = ShutterRecord(
                type: .voice,
                mediaFilename: filename,
                voiceTranscript: transcript.isEmpty ? nil : transcript,
                duration: recorder.duration
            )
            onSave(record)
        } catch {
            // Save failed
        }
    }
}

@MainActor
final class TapVoiceRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var duration: TimeInterval = 0
    private(set) var recordedData: Data?
    private(set) var tempFileURL: URL?

    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var startTime: Date?

    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch { return }

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
        } catch {}
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
        }
    }

    func reset() {
        if let url = tempFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordedData = nil
        tempFileURL = nil
        duration = 0
        isRecording = false
        startTime = nil
    }
}
