import SwiftUI

struct EchoCardView: View {
    let echoItem: EchoItem
    let shutterRecord: ShutterRecord?
    let onTap: () -> Void
    let onDismiss: () -> Void
    let onSnooze: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: offset label + type icon
            HStack {
                Text(echoItem.offsetLabel.uppercased())
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                if let record = shutterRecord {
                    Image(systemName: iconName(for: record.type))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Content preview
            if let record = shutterRecord {
                Text(record.displayText)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
            } else {
                Text("记录已删除")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .italic()
            }

            // Timestamp
            if let record = shutterRecord {
                Text(Self.dateFormatter.string(from: record.createdAt))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    onTap()
                } label: {
                    Text("查看")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(TodayTheme.teal)
                }
                .buttonStyle(.bordered)
                .tint(TodayTheme.teal)

                Button {
                    onSnooze()
                } label: {
                    Text("明天再看")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private func iconName(for type: ShutterType) -> String {
        switch type {
        case .text:  return "text.quote"
        case .voice: return "waveform"
        case .photo: return "photo"
        case .video: return "video"
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 HH:mm"
        return f
    }()
}
