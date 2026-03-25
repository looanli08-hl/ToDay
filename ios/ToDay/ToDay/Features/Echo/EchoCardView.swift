import SwiftUI

struct EchoCardView: View {
    let echoItem: EchoItem
    let shutterRecord: ShutterRecord?
    let onTap: () -> Void
    let onDismiss: () -> Void
    let onSnooze: () -> Void

    var body: some View {
        ContentCard {
            VStack(alignment: .leading, spacing: 12) {
                // Header: offset label + type badge
                HStack {
                    EyebrowLabel(echoItem.offsetLabel.uppercased())

                    Spacer()

                    if let record = shutterRecord {
                        Image(systemName: iconName(for: record.type))
                            .font(.system(size: 12))
                            .foregroundStyle(TodayTheme.inkMuted)
                    }
                }

                // Content preview
                if let record = shutterRecord {
                    Text(record.displayText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(TodayTheme.ink)
                        .lineLimit(3)
                } else {
                    Text("记录已删除")
                        .font(.system(size: 14))
                        .foregroundStyle(TodayTheme.inkMuted)
                        .italic()
                }

                // Timestamp
                if let record = shutterRecord {
                    Text(Self.dateFormatter.string(from: record.createdAt))
                        .font(.system(size: 12))
                        .foregroundStyle(TodayTheme.inkFaint)
                }

                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        onTap()
                    } label: {
                        Text("查看")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(TodayTheme.teal)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(TodayTheme.tealSoft)
                            .clipShape(Capsule())
                    }

                    Button {
                        onSnooze()
                    } label: {
                        Text("明天再看")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(TodayTheme.inkMuted)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(TodayTheme.elevatedCard)
                            .clipShape(Capsule())
                    }

                    Spacer()

                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(TodayTheme.inkFaint)
                            .frame(width: 28, height: 28)
                            .background(TodayTheme.elevatedCard)
                            .clipShape(Circle())
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

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 HH:mm"
        return f
    }()
}
