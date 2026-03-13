import SwiftUI
import WatchKit

struct QuickAnnotationView: View {
    @Environment(\.dismiss) private var dismiss

    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Self.presets, id: \.title) { preset in
                    Button {
                        onSelect(preset.title)
                        WKInterfaceDevice.current().play(.success)
                        dismiss()
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
}
