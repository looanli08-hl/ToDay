import SwiftUI

struct EchoDetailSheet: View {
    let echoItem: EchoItem
    let shutterRecord: ShutterRecord?
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Offset label
                    HStack {
                        Text(echoItem.offsetLabel)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(TodayTheme.teal)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(TodayTheme.tealSoft)
                            .clipShape(Capsule())

                        Spacer()
                    }

                    if let record = shutterRecord {
                        // Content
                        VStack(alignment: .leading, spacing: 12) {
                            // Type indicator
                            HStack(spacing: 6) {
                                Image(systemName: iconName(for: record.type))
                                    .font(.system(size: 13))
                                    .foregroundStyle(TodayTheme.inkMuted)
                                Text(typeLabel(for: record.type))
                                    .font(.system(size: 13))
                                    .foregroundStyle(TodayTheme.inkMuted)
                            }

                            // Main content
                            if let text = record.textContent, !text.isEmpty {
                                Text(text)
                                    .font(.system(size: 18, weight: .regular))
                                    .foregroundStyle(TodayTheme.ink)
                                    .lineSpacing(6)
                            }

                            if let transcript = record.voiceTranscript, !transcript.isEmpty {
                                Text(transcript)
                                    .font(.system(size: 18, weight: .regular))
                                    .foregroundStyle(TodayTheme.ink)
                                    .lineSpacing(6)
                            }

                            if record.type == .voice, let duration = record.duration {
                                HStack(spacing: 6) {
                                    Image(systemName: "waveform")
                                        .font(.system(size: 13))
                                    Text(formatDuration(duration))
                                        .font(.system(size: 13))
                                }
                                .foregroundStyle(TodayTheme.inkMuted)
                            }
                        }

                        Divider()
                            .overlay(TodayTheme.border)

                        // Context: when
                        VStack(alignment: .leading, spacing: 8) {
                            EyebrowLabel("记录时间")
                            Text(Self.fullDateFormatter.string(from: record.createdAt))
                                .font(.system(size: 15))
                                .foregroundStyle(TodayTheme.ink)
                        }

                        // Context: location (if available)
                        if record.latitude != nil && record.longitude != nil {
                            VStack(alignment: .leading, spacing: 8) {
                                EyebrowLabel("位置")
                                Text("(\(String(format: "%.4f", record.latitude!)), \(String(format: "%.4f", record.longitude!)))")
                                    .font(.system(size: 15))
                                    .foregroundStyle(TodayTheme.ink)
                            }
                        }
                    } else {
                        // Record deleted
                        VStack(spacing: 12) {
                            Image(systemName: "doc.questionmark")
                                .font(.system(size: 32))
                                .foregroundStyle(TodayTheme.inkFaint)
                            Text("原始记录已被删除")
                                .font(.system(size: 15))
                                .foregroundStyle(TodayTheme.inkMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
                .padding(20)
            }
            .background(TodayTheme.background)
            .navigationTitle("回响详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        onDismiss()
                        dismiss()
                    }
                    .foregroundStyle(TodayTheme.teal)
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
