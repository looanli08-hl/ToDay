import PhotosUI
import SwiftData
import SwiftUI
import UIKit

enum QuickRecordSheetMode {
    case flexible
    case pointOnly
}

struct QuickRecordSheet: View {
    private static let maxPhotoCount = 3

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomMoodEntity.sortOrder) private var customMoods: [CustomMoodEntity]

    @State private var selectedMood: MoodRecord.Mood?
    @State private var selectedCustomMood: CustomMoodEntity?
    @State private var note: String = ""
    @State private var createdAt: Date = Date()
    @State private var isSubmitting = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var draftPhotos: [DraftPhoto] = []
    @State private var selectedDetent: PresentationDetent = .large
    @State private var photoErrorMessage: String?
    @State private var showAddMood = false
    @State private var newMoodEmoji = ""
    @State private var newMoodName = ""
    @State private var isEditingMoods = false

    let mode: QuickRecordSheetMode
    let onSave: (MoodRecord) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    moodGrid
                    noteSection
                    photoSection
                    timeSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 120)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .onChange(of: pickerItems) { _, newItems in
                Task {
                    await importPhotos(from: newItems)
                }
            }
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
                actionBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .background(Color(UIColor.systemGroupedBackground).opacity(0.96))
            }
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
    }

    private func submit(_ record: MoodRecord) {
        guard !isSubmitting else { return }
        isSubmitting = true
        onSave(record)
        dismiss()
    }

    private var resolvedMood: MoodRecord.Mood? {
        if let selectedMood { return selectedMood }
        guard let custom = selectedCustomMood else { return nil }
        // Try to match custom mood name to an existing enum case
        return MoodRecord.Mood(rawValue: custom.name) ?? .happy
    }

    private var hasSelection: Bool {
        selectedMood != nil || selectedCustomMood != nil
    }

    private func createRecord(isSession: Bool) -> MoodRecord? {
        guard let mood = resolvedMood else { return nil }

        // If using a truly custom mood (no enum match), prepend info to note
        let effectiveNote: String
        if let custom = selectedCustomMood, MoodRecord.Mood(rawValue: custom.name) == nil {
            let prefix = "\(custom.emoji) \(custom.name)"
            effectiveNote = note.isEmpty ? prefix : "\(prefix) — \(note)"
        } else {
            effectiveNote = note
        }

        do {
            let attachments = try draftPhotos.map { try MoodPhotoLibrary.storeImageData($0.data) }
            if isSession {
                return MoodRecord.active(
                    mood: mood,
                    note: effectiveNote,
                    createdAt: createdAt,
                    photoAttachments: attachments
                )
            }

            return MoodRecord(
                mood: mood,
                note: effectiveNote,
                createdAt: createdAt,
                isTracking: false,
                photoAttachments: attachments
            )
        } catch {
            photoErrorMessage = (error as? LocalizedError)?.errorDescription ?? "照片保存失败，请重试。"
            return nil
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(sheetTitle)
                        .font(.system(size: 23, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(.primary)

                    Text(sheetSubtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(Color(UIColor.tertiaryLabel))
                        .lineSpacing(3)
                }

                Spacer()

                Text(modeBadgeTitle)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(modeBadgeTint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(modeBadgeBackground)
                    .clipShape(Capsule())
            }
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("照片")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color(UIColor.tertiaryLabel))

                    Text(photoSectionCaption)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(UIColor.quaternaryLabel))
                }

                Spacer()

                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: max(0, Self.maxPhotoCount - draftPhotos.count),
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label(draftPhotos.isEmpty ? "添加照片" : "继续添加", systemImage: "photo.on.rectangle.angled")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color(UIColor.separator), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(draftPhotos.count >= Self.maxPhotoCount || isSubmitting)
            }

            if !draftPhotos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(draftPhotos) { photo in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: photo.image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 88, height: 88)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(Color(UIColor.separator), lineWidth: 1)
                                    )

                                Button {
                                    draftPhotos.removeAll { $0.id == photo.id }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 22, height: 22)
                                        .background(.primary.opacity(0.7))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .padding(6)
                            }
                        }
                    }
                }
            }

            if let photoErrorMessage {
                Text(photoErrorMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(TodayTheme.rose)
            }
        }
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("备注")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(UIColor.tertiaryLabel))

            TextField("写一句话记录当下…", text: $note)
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
            Text(timeFieldTitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(UIColor.tertiaryLabel))

            DatePicker(
                "记录时间",
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

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button {
                guard let record = createRecord(isSession: false) else { return }
                submit(record)
            } label: {
                Group {
                    if mode == .pointOnly {
                        // Primary action in pointOnly mode — gradient fill
                        Text("保存打点")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.95, green: 0.45, blue: 0.35), Color(red: 0.98, green: 0.60, blue: 0.38)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: Color(red: 0.95, green: 0.45, blue: 0.35).opacity(0.25), radius: 8, x: 0, y: 3)
                    } else {
                        // Secondary action in flexible mode — light border
                        Text("打点")
                            .font(.headline)
                            .foregroundStyle(AppColor.label)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppColor.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AppColor.labelQuaternary, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!hasSelection || isSubmitting)
            .opacity(!hasSelection || isSubmitting ? 0.45 : 1)

            if mode == .flexible {
                Button {
                    guard let record = createRecord(isSession: true) else { return }
                    submit(record)
                } label: {
                    Text("开始一段")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.95, green: 0.45, blue: 0.35), Color(red: 0.98, green: 0.60, blue: 0.38)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: Color(red: 0.95, green: 0.45, blue: 0.35).opacity(0.25), radius: 8, x: 0, y: 3)
                }
                .buttonStyle(.plain)
                .disabled(!hasSelection || isSubmitting)
                .opacity(!hasSelection || isSubmitting ? 0.45 : 1)
            }
        }
    }

    private var sheetTitle: String {
        switch mode {
        case .flexible:
            return "记录此刻"
        case .pointOnly:
            return "补一个打点"
        }
    }

    private var sheetSubtitle: String {
        switch mode {
        case .flexible:
            return "可以直接打一个瞬时片段，也可以开始一段持续状态。"
        case .pointOnly:
            return "当前有一段状态正在进行，这里补充一个瞬时片段，不会打断它。"
        }
    }

    private var timeFieldTitle: String {
        switch mode {
        case .flexible:
            return "发生时间"
        case .pointOnly:
            return "打点时间"
        }
    }

    private var modeBadgeTitle: String {
        switch mode {
        case .flexible:
            return "打点 / 记录"
        case .pointOnly:
            return "仅打点"
        }
    }

    private var modeBadgeTint: Color {
        switch mode {
        case .flexible:
            return Color.accentColor
        case .pointOnly:
            return TodayTheme.teal
        }
    }

    private var modeBadgeBackground: Color {
        switch mode {
        case .flexible:
            return Color.accentColor.opacity(0.12)
        case .pointOnly:
            return TodayTheme.tealSoft
        }
    }

    private var moodGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("心情")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditingMoods.toggle()
                    }
                } label: {
                    Text(isEditingMoods ? "完成" : "编辑")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isEditingMoods ? Color.accentColor : .secondary)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(customMoods) { mood in
                    let isSelected = selectedCustomMood?.id == mood.id
                    ZStack(alignment: .topTrailing) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedCustomMood = mood
                                selectedMood = nil
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Text(mood.emoji)
                                    .font(.title)
                                Text(mood.name)
                                    .font(.subheadline.weight(.medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                isSelected
                                    ? Color.accentColor.opacity(0.12)
                                    : Color(UIColor.secondarySystemGroupedBackground)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(
                                        isSelected ? Color.accentColor : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                        }
                        .buttonStyle(.plain)

                        if isEditingMoods {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if isSelected { selectedCustomMood = nil }
                                    modelContext.delete(mood)
                                    try? modelContext.save()
                                }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white, Color.red)
                            }
                            .buttonStyle(.plain)
                            .offset(x: 6, y: -6)
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                }

                // Add mood button
                Button {
                    showAddMood = true
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.title2.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text("添加")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color(UIColor.separator).opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showAddMood) {
            NavigationStack {
                Form {
                    Section("表情") {
                        TextField("输入一个 emoji", text: $newMoodEmoji)
                            .font(.system(size: 40))
                            .multilineTextAlignment(.center)
                    }
                    Section("名称") {
                        TextField("心情名称", text: $newMoodName)
                    }
                }
                .navigationTitle("添加心情")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { showAddMood = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            let order = customMoods.count
                            let entity = CustomMoodEntity(emoji: newMoodEmoji, name: newMoodName, sortOrder: order)
                            modelContext.insert(entity)
                            try? modelContext.save()
                            newMoodEmoji = ""
                            newMoodName = ""
                            showAddMood = false
                        }
                        .disabled(newMoodEmoji.isEmpty || newMoodName.isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private var photoSectionCaption: String {
        if draftPhotos.isEmpty {
            return "最多添加 \(Self.maxPhotoCount) 张，会跟着这条记录一起保存。"
        }

        return "已选 \(draftPhotos.count) / \(Self.maxPhotoCount) 张，保存后可在时间线里点开查看。"
    }

    private func importPhotos(from items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }

        var importedPhotos: [DraftPhoto] = []
        var failedPhotoCount = 0
        let remainingSlots = max(0, Self.maxPhotoCount - draftPhotos.count)

        for item in items.prefix(remainingSlots) {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                failedPhotoCount += 1
                continue
            }

            importedPhotos.append(DraftPhoto(data: data, image: image))
        }

        await MainActor.run {
            if failedPhotoCount == 0 {
                photoErrorMessage = nil
            } else if importedPhotos.isEmpty {
                photoErrorMessage = "照片读取失败，请重新选择。"
            } else {
                photoErrorMessage = "\(failedPhotoCount) 张照片读取失败"
            }
            draftPhotos.append(contentsOf: importedPhotos)
            pickerItems = []
        }
    }
}

private struct DraftPhoto: Identifiable {
    let id = UUID()
    let data: Data
    let image: UIImage
}
