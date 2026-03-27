import SwiftUI

/// Quick-select annotation sheet for blank/uncertain timeline segments.
/// User taps a quiet time gap → this sheet appears with common categories.
struct EventAnnotationSheet: View {
    let event: InferredEvent
    let onAnnotate: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var customText = ""
    @State private var showCustomInput = false

    private let categories: [(icon: String, title: String, color: Color)] = [
        ("desktopcomputer", "工作", Color.blue),
        ("fork.knife", "用餐", Color.orange),
        ("cup.and.saucer.fill", "休息", Color.teal),
        ("person.2.fill", "社交", Color.purple),
        ("car.fill", "通勤", Color.green),
        ("book.fill", "学习", Color.indigo),
        ("tv.fill", "娱乐", Color.pink),
        ("cart.fill", "购物", Color.mint),
        ("figure.run", "运动", Color.red),
        ("house.fill", "居家", Color.brown),
        ("ellipsis.circle.fill", "其他", Color.gray),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Time range header
                    timeHeader

                    // Quick-select grid
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        ForEach(categories, id: \.title) { category in
                            categoryButton(category)
                        }
                    }

                    // Custom input
                    if showCustomInput {
                        customInputSection
                    }
                }
                .padding(20)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("这段时间你在做什么？")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private var timeHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(timeRangeText)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text(durationText)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.primary)
            }
            Spacer()
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.quaternary)
        }
        .padding(16)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
    }

    private func categoryButton(_ category: (icon: String, title: String, color: Color)) -> some View {
        Button {
            if category.title == "其他" {
                showCustomInput = true
            } else {
                onAnnotate(category.title)
                dismiss()
            }
        } label: {
            VStack(spacing: 10) {
                Image(systemName: category.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(category.color)
                    .frame(width: 48, height: 48)
                    .background(category.color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text(category.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var customInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("自定义标注")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1)

            HStack(spacing: 12) {
                TextField("你在做什么？", text: $customText)
                    .textFieldStyle(.roundedBorder)

                Button("确定") {
                    let trimmed = customText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onAnnotate(trimmed)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(customText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
    }

    private var timeRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: event.startDate)) - \(formatter.string(from: event.endDate))"
    }

    private var durationText: String {
        let minutes = max(Int(event.endDate.timeIntervalSince(event.startDate) / 60), 1)
        if minutes >= 60 {
            let hours = minutes / 60
            let remainder = minutes % 60
            return remainder == 0 ? "\(hours) 小时" : "\(hours) 小时 \(remainder) 分钟"
        }
        return "\(minutes) 分钟"
    }
}
