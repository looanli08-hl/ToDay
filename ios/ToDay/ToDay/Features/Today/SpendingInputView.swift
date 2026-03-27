import SwiftUI

struct SpendingInputView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String = ""
    @State private var selectedCategory: SpendingCategory = .food
    @State private var note: String = ""
    @State private var createdAt: Date = Date()
    @State private var isSubmitting = false

    let onSave: (SpendingRecord) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    amountSection
                    categoryGrid
                    noteSection
                    timeSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 120)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .clipShape(Circle())
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                saveButton
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .background(Color(UIColor.systemGroupedBackground).opacity(0.96))
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("记一笔")
                    .font(.system(size: 28, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(.primary)

                Text("金额 + 分类，轻松记下每一笔开销。")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
                    .lineSpacing(3)
            }

            Spacer()

            Text("消费")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(TodayTheme.teal)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(TodayTheme.tealSoft)
                .clipShape(Capsule())
        }
    }

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("金额")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(UIColor.tertiaryLabel))

            HStack(spacing: 8) {
                Text("¥")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)

                TextField("0", text: $amountText)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
            }
            .padding(14)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(UIColor.separator), lineWidth: 1)
            )
        }
    }

    private var categoryGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("分类")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(UIColor.tertiaryLabel))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(SpendingCategory.allCases, id: \.self) { category in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedCategory = category
                        }
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: category.iconName)
                                .font(.system(size: 18))
                            Text(category.displayName)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            selectedCategory == category
                                ? TodayTheme.tealSoft
                                : Color(UIColor.secondarySystemGroupedBackground)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(
                                    selectedCategory == category
                                        ? TodayTheme.teal
                                        : Color.clear,
                                    lineWidth: 2
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(
                        selectedCategory == category
                            ? TodayTheme.teal
                            : .secondary
                    )
                }
            }
        }
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("备注")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(UIColor.tertiaryLabel))

            TextField("写一句话备注…", text: $note)
                .textFieldStyle(.plain)
                .padding(14)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(UIColor.separator), lineWidth: 1)
                )
        }
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("消费时间")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(UIColor.tertiaryLabel))

            DatePicker(
                "消费时间",
                selection: $createdAt,
                in: ...Date(),
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(UIColor.separator), lineWidth: 1)
            )
        }
    }

    private var saveButton: some View {
        Button {
            guard !isSubmitting else { return }
            guard let amount = parsedAmount, amount > 0 else { return }

            isSubmitting = true
            let record = SpendingRecord(
                amount: amount,
                category: selectedCategory,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note.trimmingCharacters(in: .whitespacesAndNewlines),
                createdAt: createdAt
            )
            onSave(record)
            dismiss()
        } label: {
            Text("保存")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(TodayTheme.teal)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(parsedAmount == nil || parsedAmount == 0 || isSubmitting)
        .opacity(parsedAmount == nil || parsedAmount == 0 || isSubmitting ? 0.45 : 1)
    }

    // MARK: - Helpers

    private var parsedAmount: Double? {
        Double(amountText.trimmingCharacters(in: .whitespaces))
    }
}
