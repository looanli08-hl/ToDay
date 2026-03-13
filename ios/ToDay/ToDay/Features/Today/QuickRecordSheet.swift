import PhotosUI
import SwiftUI
import UIKit

enum QuickRecordSheetMode {
    case flexible
    case pointOnly
}

struct QuickRecordSheet: View {
    private static let maxPhotoCount = 3

    @Environment(\.dismiss) private var dismiss
    @State private var selectedMood: MoodRecord.Mood?
    @State private var note: String = ""
    @State private var createdAt: Date = Date()
    @State private var isSubmitting = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var draftPhotos: [DraftPhoto] = []
    @State private var selectedDetent: PresentationDetent = .large
    @State private var photoErrorMessage: String?

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
            .background(TodayTheme.background)
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
                            .foregroundStyle(TodayTheme.inkSoft)
                            .frame(width: 32, height: 32)
                            .background(TodayTheme.card)
                            .clipShape(Circle())
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                actionBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .background(TodayTheme.background.opacity(0.96))
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

    private func createRecord(isSession: Bool) -> MoodRecord? {
        guard let mood = selectedMood else { return nil }

        do {
            let attachments = try draftPhotos.map { try MoodPhotoLibrary.storeImageData($0.data) }
            if isSession {
                return MoodRecord.active(
                    mood: mood,
                    note: note,
                    createdAt: createdAt,
                    photoAttachments: attachments
                )
            }

            return MoodRecord(
                mood: mood,
                note: note,
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
                        .font(.system(size: 28, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(TodayTheme.ink)

                    Text(sheetSubtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(TodayTheme.inkMuted)
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
                        .foregroundStyle(TodayTheme.inkMuted)

                    Text(photoSectionCaption)
                        .font(.system(size: 12))
                        .foregroundStyle(TodayTheme.inkFaint)
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
                        .foregroundStyle(TodayTheme.inkSoft)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(TodayTheme.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(TodayTheme.border, lineWidth: 1)
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
                                            .stroke(TodayTheme.border, lineWidth: 1)
                                    )

                                Button {
                                    draftPhotos.removeAll { $0.id == photo.id }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 22, height: 22)
                                        .background(TodayTheme.ink.opacity(0.7))
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
                .foregroundStyle(TodayTheme.inkMuted)

            TextField("写一句话记录当下…", text: $note)
                .textFieldStyle(.plain)
                .padding(14)
                .background(TodayTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(TodayTheme.border, lineWidth: 1)
                )
        }
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(timeFieldTitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(TodayTheme.inkMuted)

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
            .background(TodayTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(TodayTheme.border, lineWidth: 1)
            )
        }
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button(mode == .pointOnly ? "保存打点" : "打点") {
                guard let record = createRecord(isSession: false) else { return }
                submit(record)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(mode == .pointOnly ? .white : TodayTheme.inkSoft)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(mode == .pointOnly ? TodayTheme.teal : TodayTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(mode == .pointOnly ? Color.clear : TodayTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .disabled(selectedMood == nil || isSubmitting)
            .opacity(selectedMood == nil || isSubmitting ? 0.45 : 1)

            if mode == .flexible {
                Button("开始一段") {
                    guard let record = createRecord(isSession: true) else { return }
                    submit(record)
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(TodayTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .disabled(selectedMood == nil || isSubmitting)
                .opacity(selectedMood == nil || isSubmitting ? 0.45 : 1)
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
            return "POINT / SESSION"
        case .pointOnly:
            return "POINT ONLY"
        }
    }

    private var modeBadgeTint: Color {
        switch mode {
        case .flexible:
            return TodayTheme.accent
        case .pointOnly:
            return TodayTheme.teal
        }
    }

    private var modeBadgeBackground: Color {
        switch mode {
        case .flexible:
            return TodayTheme.accentSoft
        case .pointOnly:
            return TodayTheme.tealSoft
        }
    }

    private var moodGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
            ForEach(MoodRecord.Mood.allCases) { mood in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedMood = mood
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(mood.emoji)
                            .font(.title)
                        Text(mood.rawValue)
                            .font(.subheadline.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        selectedMood == mood
                            ? Color(red: 0.95, green: 0.90, blue: 0.82)
                            : Color(uiColor: .secondarySystemBackground)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                selectedMood == mood
                                    ? Color(red: 0.74, green: 0.66, blue: 0.57)
                                    : Color.clear,
                                lineWidth: 2
                            )
                    )
                }
                .buttonStyle(.plain)
            }
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
        let remainingSlots = max(0, Self.maxPhotoCount - draftPhotos.count)

        for item in items.prefix(remainingSlots) {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                continue
            }

            importedPhotos.append(DraftPhoto(data: data, image: image))
        }

        await MainActor.run {
            photoErrorMessage = importedPhotos.isEmpty ? "照片读取失败，请重新选择。" : nil
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
