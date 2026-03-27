import SwiftUI

struct AnnotationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var customTitle: String = ""

    let event: InferredEvent
    let onSave: (String) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private let presets: [AnnotationPreset] = [
        .init(icon: "briefcase", title: "工作/办公"),
        .init(icon: "book", title: "阅读"),
        .init(icon: "graduationcap", title: "学习"),
        .init(icon: "fork.knife", title: "做饭"),
        .init(icon: "takeoutbag.and.cup.and.straw", title: "用餐"),
        .init(icon: "sparkles", title: "家务"),
        .init(icon: "cart", title: "购物"),
        .init(icon: "person.2", title: "社交"),
        .init(icon: "cloud", title: "发呆"),
        .init(icon: "figure.walk", title: "散步"),
        .init(icon: "bed.double", title: "午休"),
        .init(icon: "ellipsis.circle", title: "其他")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    headerSection
                    presetGrid
                    customInputSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 120)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                confirmBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .background(Color(UIColor.systemGroupedBackground).opacity(0.96))
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("标注这段时间")
                .font(.system(size: 28, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(.primary)

            Text(timeRangeText)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(UIColor.tertiaryLabel))

            Text("选一个最接近的活动，或者直接写下这段时间真正发生了什么。")
                .font(.system(size: 14))
                .foregroundStyle(Color(UIColor.tertiaryLabel))
                .lineSpacing(4)
        }
    }

    private var presetGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("常见活动")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(UIColor.tertiaryLabel))

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(presets) { preset in
                    Button {
                        save(preset.title)
                    } label: {
                        VStack(spacing: 10) {
                            Image(systemName: preset.icon)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(TodayTheme.teal)

                            Text(preset.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.75)
                        }
                        .frame(maxWidth: .infinity, minHeight: 92)
                        .padding(.horizontal, 8)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color(UIColor.separator), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var customInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("自由输入")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(UIColor.tertiaryLabel))

            TextField("例如：赶方案、和朋友聊天、在路上发呆", text: $customTitle, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(14)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(UIColor.separator), lineWidth: 1)
                )
        }
    }

    private var confirmBar: some View {
        Button("确认标注") {
            save(customTitle)
        }
        .buttonStyle(.plain)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.accentColor)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .disabled(customTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .opacity(customTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
    }

    private var timeRangeText: String {
        let locale = Locale(identifier: "zh_CN")
        let start = event.startDate.formatted(.dateTime.hour().minute().locale(locale))
        let end = event.endDate.formatted(.dateTime.hour().minute().locale(locale))
        return "\(start) - \(end)"
    }

    private func save(_ title: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        onSave(trimmedTitle)
        dismiss()
    }
}

private struct AnnotationPreset: Identifiable {
    let icon: String
    let title: String

    var id: String { title }
}
