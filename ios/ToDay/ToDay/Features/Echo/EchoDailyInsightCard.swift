import SwiftUI

/// Card displayed at the top of the Echo screen showing today's AI-generated insight.
/// Tappable to start a conversation about the insight.
struct EchoDailyInsightCard: View {
    let insightText: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                // Header
                HStack {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(AppColor.echo)

                    Text("今日洞察")
                        .font(AppFont.captionBold)
                        .foregroundStyle(AppColor.echo)

                    Spacer()

                    Text("点击继续聊")
                        .font(AppFont.caption)
                        .foregroundStyle(AppColor.labelTertiary)
                }

                // Insight text
                Text(insightText)
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.label)
                    .lineSpacing(4)
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
            }
            .padding(AppSpacing.md)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .strokeBorder(AppColor.soft(AppColor.echo), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, AppSpacing.md)
    }
}
