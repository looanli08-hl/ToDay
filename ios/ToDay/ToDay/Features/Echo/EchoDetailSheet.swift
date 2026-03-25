import SwiftUI

struct EchoDetailSheet: View {
    let echoItem: EchoItem
    let shutterRecord: ShutterRecord?
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Offset badge
                Section {
                    HStack {
                        Text(echoItem.offsetLabel)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(TodayTheme.teal)
                        Spacer()
                    }
                }

                if let record = shutterRecord {
                    // Type indicator + content
                    Section {
                        HStack(spacing: 6) {
                            Image(systemName: iconName(for: record.type))
                                .font(.caption)
                            Text(typeLabel(for: record.type))
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)

                        if let text = record.textContent, !text.isEmpty {
                            Text(text)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .lineSpacing(4)
                        }

                        if let transcript = record.voiceTranscript, !transcript.isEmpty {
                            Text(transcript)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .lineSpacing(4)
                        }

                        if record.type == .voice, let duration = record.duration {
                            HStack(spacing: 6) {
                                Image(systemName: "waveform")
                                    .font(.caption)
                                Text(formatDuration(duration))
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }

                    // Context
                    Section {
                        LabeledContent("记录时间") {
                            Text(Self.fullDateFormatter.string(from: record.createdAt))
                        }

                        if record.latitude != nil && record.longitude != nil {
                            LabeledContent("位置") {
                                Text("(\(String(format: "%.4f", record.latitude!)), \(String(format: "%.4f", record.longitude!)))")
                            }
                        }
                    }
                } else {
                    // Record deleted
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.questionmark")
                                .font(.largeTitle)
                                .foregroundStyle(.quaternary)
                            Text("原始记录已被删除")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .navigationTitle("回响详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        onDismiss()
                        dismiss()
                    }
                }
            }
        }
    }

    private func iconName(for type: ShutterType) -> String {
        switch type {
        case .text:  return "text.quote"
        case .voice: return "waveform"
        case .photo: return "photo"
        case .video: return "video"
        }
    }

    private func typeLabel(for type: ShutterType) -> String {
        switch type {
        case .text:  return "文字记录"
        case .voice: return "语音记录"
        case .photo: return "照片"
        case .video: return "视频"
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        if seconds < 60 {
            return "\(seconds)秒"
        }
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return "\(minutes)分\(remainingSeconds)秒"
    }

    private static let fullDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月d日 EEEE HH:mm"
        return f
    }()
}
