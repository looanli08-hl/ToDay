import SwiftUI

/// A card representing one Echo message in the message list.
/// Shows type icon, title, preview, source badge, and time.
/// Unread messages use bold title styling.
struct EchoMessageCard: View {
    let entity: EchoMessageEntity

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            // Type icon
            Text(entity.messageType.icon)
                .font(.title3)
                .frame(width: 32, height: 32)

            // Content
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                // Title + time row
                HStack(alignment: .firstTextBaseline) {
                    Text(entity.displayTitle)
                        .font(entity.isRead ? AppFont.subheadline : AppFont.headline)
                        .foregroundStyle(AppColor.label)
                        .lineLimit(1)

                    Spacer()

                    Text(Self.relativeTime(entity.createdAt))
                        .font(AppFont.caption)
                        .foregroundStyle(AppColor.labelTertiary)
                }

                // Preview
                if !entity.preview.isEmpty {
                    Text(entity.preview)
                        .font(AppFont.body)
                        .foregroundStyle(AppColor.labelSecondary)
                        .lineLimit(2)
                }

                // Source badge
                if !entity.sourceDescription.isEmpty {
                    HStack(spacing: AppSpacing.xxs) {
                        Text("📌")
                            .font(.caption2)
                        Text(entity.sourceDescription)
                            .font(AppFont.caption)
                            .foregroundStyle(AppColor.labelTertiary)
                    }
                    .padding(.top, AppSpacing.xxxs)
                }
            }

            // Unread dot
            if !entity.isRead {
                Circle()
                    .fill(AppColor.echo)
                    .frame(width: 8, height: 8)
                    .padding(.top, AppSpacing.xs)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        .appShadow(.subtle)
    }

    // MARK: - Time Formatting

    private static func relativeTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "M月d日"
            return formatter.string(from: date)
        }
    }
}
