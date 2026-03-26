import SwiftUI

/// Personality picker for Echo AI in Settings.
/// Shows 3 personality options with descriptions.
struct EchoPersonalityPicker: View {
    @Binding var selection: EchoPersonality

    var body: some View {
        ForEach(EchoPersonality.allCases, id: \.self) { personality in
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    selection = personality
                }
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    VStack(alignment: .leading, spacing: AppSpacing.xxxs) {
                        Text(personality.displayName)
                            .font(AppFont.body)
                            .foregroundStyle(AppColor.label)

                        Text(descriptionFor(personality))
                            .font(AppFont.caption)
                            .foregroundStyle(AppColor.labelSecondary)
                    }

                    Spacer()

                    if selection == personality {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppColor.echo)
                    } else {
                        Image(systemName: "circle")
                            .foregroundStyle(AppColor.labelTertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func descriptionFor(_ personality: EchoPersonality) -> String {
        switch personality {
        case .gentle:
            return "安静的老朋友，不多话但句句到点上"
        case .cheerful:
            return "贴心的好朋友，热情鼓励"
        case .rational:
            return "成熟的导师，客观理性分析"
        }
    }
}
