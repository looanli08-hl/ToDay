import SwiftUI

struct ManualTimeEntrySheet: View {
    let onSave: (_ title: String, _ start: Date, _ end: Date) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var startTime: Date = Date().addingTimeInterval(-3600)
    @State private var endTime: Date = Date()
    @FocusState private var titleFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("添加时段")
                        .font(.system(size: 22, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(.primary)

                    Text("手动记录一段时间里做了什么。")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(UIColor.tertiaryLabel))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

                VStack(spacing: 16) {
                    // Title input
                    VStack(alignment: .leading, spacing: 6) {
                        Text("在做什么")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(UIColor.tertiaryLabel))
                            .textCase(.uppercase)
                            .tracking(1.2)

                        TextField("比如：读书、写代码、散步…", text: $title)
                            .font(.system(size: 16))
                            .focused($titleFocused)
                            .padding(14)
                            .background(Color(UIColor.tertiarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    // Time pickers
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("开始")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color(UIColor.tertiaryLabel))
                                .textCase(.uppercase)
                                .tracking(1.2)

                            DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .environment(\.locale, Locale(identifier: "zh_CN"))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("结束")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color(UIColor.tertiaryLabel))
                                .textCase(.uppercase)
                                .tracking(1.2)

                            DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .environment(\.locale, Locale(identifier: "zh_CN"))
                        }

                        Spacer()
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                // Save button
                Button {
                    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty, endTime > startTime else { return }
                    onSave(trimmed, startTime, endTime)
                } label: {
                    Text("保存")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color(UIColor.quaternaryLabel)
                                : Color.accentColor
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .padding(.top, 16)
            .background(Color(UIColor.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear { titleFocused = true }
    }
}
