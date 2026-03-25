import SwiftUI

struct ScreenTimeInputView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var hours: Int = 0
    @State private var minutes: Int = 0
    @State private var pickupCount: Int = 0
    @State private var appEntries: [AppEntryDraft] = [AppEntryDraft()]
    @State private var isSubmitting = false

    let dateKey: String
    let existingRecord: ScreenTimeRecord?
    let onSave: (ScreenTimeRecord) -> Void

    init(dateKey: String, existingRecord: ScreenTimeRecord? = nil, onSave: @escaping (ScreenTimeRecord) -> Void) {
        self.dateKey = dateKey
        self.existingRecord = existingRecord
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    totalTimeSection
                    pickupSection
                    appUsageSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 120)
            }
            .background(TodayTheme.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(TodayTheme.inkSoft)
                            .frame(width: 32, height: 32)
                            .background(TodayTheme.card)
                            .clipShape(Circle())
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                saveButton
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .background(TodayTheme.background.opacity(0.96))
            }
            .onAppear {
                if let existing = existingRecord {
                    let totalSeconds = Int(existing.totalScreenTime)
                    hours = totalSeconds / 3600
                    minutes = (totalSeconds % 3600) / 60
                    pickupCount = existing.pickupCount
                    appEntries = existing.appUsages.map { usage in
                        AppEntryDraft(
                            appName: usage.appName,
                            category: usage.category,
                            durationMinutes: String(Int(usage.duration / 60))
                        )
                    }
                    if appEntries.isEmpty {
                        appEntries = [AppEntryDraft()]
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("屏幕时间")
                    .font(.system(size: 28, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(TodayTheme.ink)

                Text("记录今天的屏幕使用情况。\n可以在 设置 > 屏幕使用时间 中查看系统数据。")
                    .font(.system(size: 14))
                    .foregroundStyle(TodayTheme.inkMuted)
                    .lineSpacing(3)
            }

            Spacer()

            Text("屏幕")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(TodayTheme.blue)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(TodayTheme.blueSoft)
                .clipShape(Capsule())
        }
    }

    private var totalTimeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("总时长")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(TodayTheme.inkMuted)

            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Picker("小时", selection: $hours) {
                        ForEach(0..<24) { h in
                            Text("\(h)").tag(h)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 60, height: 100)
                    .clipped()

                    Text("小时")
                        .font(.system(size: 14))
                        .foregroundStyle(TodayTheme.inkSoft)
                }

                HStack(spacing: 6) {
                    Picker("分钟", selection: $minutes) {
                        ForEach(0..<60) { m in
                            Text("\(m)").tag(m)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 60, height: 100)
                    .clipped()

                    Text("分钟")
                        .font(.system(size: 14))
                        .foregroundStyle(TodayTheme.inkSoft)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(TodayTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(TodayTheme.border, lineWidth: 1)
            )
        }
    }

    private var pickupSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("拿起次数")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(TodayTheme.inkMuted)

            HStack(spacing: 12) {
                Button {
                    if pickupCount > 0 { pickupCount -= 1 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(TodayTheme.inkMuted)
                }
                .buttonStyle(.plain)

                Text("\(pickupCount)")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundStyle(TodayTheme.ink)
                    .frame(minWidth: 50)

                Button {
                    pickupCount += 1
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(TodayTheme.blue)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("次")
                    .font(.system(size: 14))
                    .foregroundStyle(TodayTheme.inkSoft)
            }
            .padding(14)
            .background(TodayTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(TodayTheme.border, lineWidth: 1)
            )
        }
    }

    private var appUsageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("常用 App（可选）")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(TodayTheme.inkMuted)

                Spacer()

                if appEntries.count < 5 {
                    Button {
                        appEntries.append(AppEntryDraft())
                    } label: {
                        Label("添加", systemImage: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(TodayTheme.blue)
                    }
                }
            }

            ForEach(appEntries.indices, id: \.self) { index in
                HStack(spacing: 8) {
                    TextField("App 名称", text: $appEntries[index].appName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))

                    TextField("分类", text: $appEntries[index].category)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .frame(width: 60)

                    TextField("分钟", text: $appEntries[index].durationMinutes)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, design: .monospaced))
                        .keyboardType(.numberPad)
                        .frame(width: 50)

                    if appEntries.count > 1 {
                        Button {
                            appEntries.remove(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(TodayTheme.inkFaint)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(TodayTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(TodayTheme.border, lineWidth: 1)
                )
            }
        }
    }

    private var saveButton: some View {
        Button {
            guard !isSubmitting else { return }
            let totalSeconds = TimeInterval(hours * 3600 + minutes * 60)
            guard totalSeconds > 0 else { return }

            isSubmitting = true

            let appUsages: [AppUsage] = appEntries.compactMap { entry in
                let name = entry.appName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty,
                      let mins = Int(entry.durationMinutes.trimmingCharacters(in: .whitespaces)),
                      mins > 0 else { return nil }
                return AppUsage(
                    appName: name,
                    category: entry.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "其他" : entry.category.trimmingCharacters(in: .whitespacesAndNewlines),
                    duration: TimeInterval(mins * 60)
                )
            }

            let record = ScreenTimeRecord(
                id: existingRecord?.id ?? UUID(),
                dateKey: dateKey,
                totalScreenTime: totalSeconds,
                appUsages: appUsages,
                pickupCount: pickupCount
            )
            onSave(record)
            dismiss()
        } label: {
            Text(existingRecord == nil ? "保存" : "更新")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(TodayTheme.blue)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(totalTimeInvalid || isSubmitting)
        .opacity(totalTimeInvalid || isSubmitting ? 0.45 : 1)
    }

    private var totalTimeInvalid: Bool {
        hours == 0 && minutes == 0
    }
}

private struct AppEntryDraft: Identifiable {
    let id = UUID()
    var appName: String = ""
    var category: String = ""
    var durationMinutes: String = ""
}
