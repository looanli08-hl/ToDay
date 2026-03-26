import SwiftUI

struct ShutterAlbumScreen: View {
    @ObservedObject var viewModel: TodayViewModel

    @State private var selectedFilter: ShutterFilter = .all

    enum ShutterFilter: String, CaseIterable {
        case all = "全部"
        case text = "文字"
        case voice = "语音"
        case photo = "照片"
        case video = "视频"

        var shutterType: ShutterType? {
            switch self {
            case .all: return nil
            case .text: return .text
            case .voice: return .voice
            case .photo: return .photo
            case .video: return .video
            }
        }
    }

    private var filteredRecords: [ShutterRecord] {
        let all = viewModel.shutterRecords.sorted { $0.createdAt > $1.createdAt }
        guard let type = selectedFilter.shutterType else { return all }
        return all.filter { $0.type == type }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterChips
                Divider()
                ScrollView {
                    if filteredRecords.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: AppSpacing.sm) {
                            ForEach(filteredRecords) { record in
                                recordCard(for: record)
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.top, AppSpacing.md)
                        .padding(.bottom, 100)
                    }
                }
                .background(AppColor.background)
            }
            .navigationTitle("快门")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                ForEach(ShutterFilter.allCases, id: \.self) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilter = filter
                        }
                    } label: {
                        Text(filter.rawValue)
                            .font(.system(size: 14, weight: selectedFilter == filter ? .semibold : .regular))
                            .foregroundStyle(selectedFilter == filter ? .white : AppColor.labelSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(selectedFilter == filter ? AppColor.accent : AppColor.surface)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
        .padding(.vertical, AppSpacing.sm)
        .background(AppColor.surface)
    }

    // MARK: - Record Cards

    @ViewBuilder
    private func recordCard(for record: ShutterRecord) -> some View {
        switch record.type {
        case .photo, .video:
            mediaCard(for: record)
        case .text:
            textRow(for: record)
        case .voice:
            voiceRow(for: record)
        }
    }

    // MARK: - Media Card (photo / video)

    private func mediaCard(for record: ShutterRecord) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let filename = record.mediaFilename {
                let fileURL = ShutterMediaLibrary.fileURL(for: filename)
                if record.type == .photo {
                    photoThumbnail(url: fileURL)
                } else {
                    videoThumbnail(url: fileURL)
                }
            }

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                if let text = record.textContent, !text.isEmpty {
                    Text(text)
                        .font(.system(size: 15))
                        .foregroundStyle(AppColor.label)
                        .lineLimit(3)
                }

                HStack(spacing: AppSpacing.xs) {
                    Text(formattedTime(record.createdAt))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppColor.labelTertiary)

                    if record.latitude != nil && record.longitude != nil {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(AppColor.labelTertiary)
                    }

                    Spacer()

                    if record.type == .video {
                        Label("视频", systemImage: "video.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppColor.labelSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppColor.soft(AppColor.shutter))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(AppSpacing.sm)
        }
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        .appShadow(.subtle)
    }

    private func photoThumbnail(url: URL) -> some View {
        Group {
            if let uiImage = UIImage(contentsOfFile: url.path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipped()
            } else {
                imagePlaceholder
            }
        }
    }

    private func videoThumbnail(url: URL) -> some View {
        ZStack {
            imagePlaceholder
            Image(systemName: "play.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.85))
                .shadow(radius: 4)
        }
    }

    private var imagePlaceholder: some View {
        Rectangle()
            .fill(AppColor.surfaceElevated)
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .overlay(
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(AppColor.labelQuaternary)
            )
    }

    // MARK: - Text Row

    private func textRow(for record: ShutterRecord) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 16))
                .foregroundStyle(AppColor.shutter)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(record.textContent ?? "文字记录")
                    .font(.system(size: 15))
                    .foregroundStyle(AppColor.label)
                    .lineLimit(4)

                HStack(spacing: AppSpacing.xs) {
                    Text(formattedTime(record.createdAt))
                        .font(.system(size: 12))
                        .foregroundStyle(AppColor.labelTertiary)

                    if record.latitude != nil && record.longitude != nil {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(AppColor.labelTertiary)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(AppSpacing.sm)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        .appShadow(.subtle)
    }

    // MARK: - Voice Row

    private func voiceRow(for record: ShutterRecord) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: "mic.fill")
                .font(.system(size: 16))
                .foregroundStyle(AppColor.mood)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                if let transcript = record.voiceTranscript, !transcript.isEmpty {
                    Text(transcript)
                        .font(.system(size: 15))
                        .foregroundStyle(AppColor.label)
                        .lineLimit(3)
                } else {
                    Text(voiceDurationText(record.duration))
                        .font(.system(size: 15))
                        .foregroundStyle(AppColor.label)
                }

                HStack(spacing: AppSpacing.xs) {
                    Text(formattedTime(record.createdAt))
                        .font(.system(size: 12))
                        .foregroundStyle(AppColor.labelTertiary)

                    if let dur = record.duration {
                        Text("\(Int(dur))秒")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColor.labelTertiary)
                    }

                    if record.latitude != nil && record.longitude != nil {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(AppColor.labelTertiary)
                    }
                }
            }

            Spacer(minLength: 0)

            Label("语音", systemImage: "waveform")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColor.labelSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(AppColor.soft(AppColor.mood))
                .clipShape(Capsule())
        }
        .padding(AppSpacing.sm)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        .appShadow(.subtle)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "camera.aperture")
                .font(.system(size: 40))
                .foregroundStyle(AppColor.labelQuaternary)

            Text("还没有快门记录")
                .font(.headline)
                .foregroundStyle(AppColor.labelSecondary)

            Text("用快门捕捉生活碎片，文字、语音、照片、视频都可以。")
                .font(.subheadline)
                .foregroundStyle(AppColor.labelTertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity)
        .padding(60)
    }

    // MARK: - Formatting Helpers

    private func formattedTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")

        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "M月d日 HH:mm"
        }

        return formatter.string(from: date)
    }

    private func voiceDurationText(_ duration: TimeInterval?) -> String {
        guard let dur = duration else { return "语音记录" }
        return "语音 \(Int(dur))秒"
    }
}
