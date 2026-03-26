import SwiftUI

struct EchoChatBubbleView: View {
    let message: EchoChatMessage
    let isLastMessage: Bool

    var body: some View {
        switch message.role {
        case .user:
            userBubble
        case .assistant:
            echoBubble
        case .system:
            systemIndicator
        }
    }

    // MARK: - User Bubble (right-aligned)

    private var userBubble: some View {
        HStack {
            Spacer(minLength: AppSpacing.xxl)

            Text(message.content)
                .font(AppFont.body)
                .foregroundStyle(AppColor.label)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(AppColor.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xxxs)
    }

    // MARK: - Echo Bubble (left-aligned, with avatar)

    private var echoBubble: some View {
        HStack(alignment: .top, spacing: AppSpacing.xs) {
            // Echo avatar
            Image(systemName: "sparkles")
                .font(.caption)
                .foregroundStyle(AppColor.echo)
                .frame(width: 28, height: 28)
                .background(AppColor.soft(AppColor.echo))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(message.content)
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.label)
                    .textSelection(.enabled)

                if isLastMessage {
                    Text(Self.timeFormatter.string(from: message.createdAt))
                        .font(AppFont.caption)
                        .foregroundStyle(AppColor.labelTertiary)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))

            Spacer(minLength: AppSpacing.xl)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xxxs)
    }

    // MARK: - System Indicator (centered, subtle)

    private var systemIndicator: some View {
        HStack {
            Spacer()
            Text(message.content)
                .font(AppFont.caption)
                .foregroundStyle(AppColor.labelTertiary)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xxs)
            Spacer()
        }
        .padding(.vertical, AppSpacing.xs)
    }

    // MARK: - Formatter

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "HH:mm"
        return f
    }()
}

// MARK: - Thinking Indicator

struct EchoThinkingView: View {
    @State private var dotCount = 0
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.xs) {
            // Echo avatar
            Image(systemName: "sparkles")
                .font(.caption)
                .foregroundStyle(AppColor.echo)
                .frame(width: 28, height: 28)
                .background(AppColor.soft(AppColor.echo))
                .clipShape(Circle())

            HStack(spacing: 4) {
                Text("Echo 正在思考")
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.labelSecondary)

                Text(String(repeating: ".", count: dotCount + 1))
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.labelTertiary)
                    .frame(width: 20, alignment: .leading)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))

            Spacer()
        }
        .padding(.horizontal, AppSpacing.md)
        .onReceive(timer) { _ in
            dotCount = (dotCount + 1) % 3
        }
    }
}
