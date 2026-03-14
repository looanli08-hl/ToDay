import SwiftUI
import WatchKit

struct QuickAnnotationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var customTitle = ""

    let contextTitle: String?
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 6) {
                Text(contextTitle ?? "快捷标注")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(WatchTheme.text)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 4)

                ForEach(Self.presets, id: \.title) { preset in
                    Button {
                        submit(title: preset.title)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: preset.iconName)
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 20)

                            Text(preset.title)
                                .font(.system(size: 16, weight: .bold, design: .rounded))

                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(WatchTheme.text)
                        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                        .padding(.horizontal, 12)
                        .background(WatchTheme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(WatchTheme.border, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("自定义")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(WatchTheme.textMuted)

                    TextField("说出或写下活动", text: $customTitle)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(WatchTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Button {
                        submit(title: customTitle.trimmingCharacters(in: .whitespacesAndNewlines))
                    } label: {
                        HStack {
                            Image(systemName: "checkmark")
                            Text("完成标注")
                        }
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(customTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? WatchTheme.textFaint : WatchTheme.text)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(WatchTheme.elevated)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(customTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
        }
        .background(WatchTheme.background.ignoresSafeArea())
    }

    private static let presets: [(title: String, iconName: String)] = [
        ("工作", "briefcase.fill"),
        ("用餐", "fork.knife"),
        ("通勤", "tram.fill"),
        ("运动", "figure.run"),
        ("休息", "bed.double.fill"),
        ("其他", "ellipsis.circle.fill")
    ]

    private func submit(title: String) {
        guard !title.isEmpty else { return }
        onSelect(title)
        WKInterfaceDevice.current().play(.success)
        dismiss()
    }
}
