import Charts
import Photos
import SwiftUI

struct EventDetailView: View {
    let event: InferredEvent
    var onAnnotate: (() -> Void)?

    private let chineseLocale = Locale(identifier: "zh_CN")

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerCard
                    photoSection

                    if event.kind == .workout || event.kind == .commute || event.kind == .activeWalk {
                        workoutSection
                    }

                    if event.kind == .sleep {
                        sleepSection
                    }

                    if event.isBlankCandidate {
                        annotationSection
                    }
                }
                .padding(20)
            }
            .background(TodayTheme.background)
            .navigationTitle("片段详情")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var headerCard: some View {
        ContentCard(background: event.cardFill.opacity(event.kind == .quietTime ? 0.35 : 0.92)) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(event.resolvedName)
                        .font(.system(size: 28, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(event.kind == .quietTime ? TodayTheme.ink : event.primaryTextColor)

                    Text(timeRangeText)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(event.kind == .quietTime ? TodayTheme.inkMuted : event.secondaryTextColor)

                    Text(event.scrollDurationText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(event.kind == .quietTime ? TodayTheme.inkSoft : event.primaryTextColor)
                }

                Spacer()

                Text(event.kindBadgeTitle)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(event.kind == .quietTime ? TodayTheme.inkSoft : event.primaryTextColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(event.badgeBackground)
                    .clipShape(Capsule())
            }

            if let subtitle = event.subtitle, !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(event.kind == .quietTime ? TodayTheme.inkMuted : event.secondaryTextColor)
                    .lineSpacing(4)
            }

            HStack(spacing: 12) {
                detailChip(
                    title: "天气",
                    value: weatherText,
                    systemImage: event.associatedMetrics?.weather?.symbolName
                )

                detailChip(
                    title: "地点",
                    value: event.associatedMetrics?.location?.placeName ?? "未记录"
                )
            }
        }
    }

    @ViewBuilder
    private var photoSection: some View {
        if let photos = event.associatedMetrics?.photos, !photos.isEmpty {
            ContentCard {
                EyebrowLabel("PHOTOS")
                Text("相关照片")
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(TodayTheme.ink)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(photos) { photo in
                            PhotoThumbnailView(localIdentifier: photo.id)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var workoutSection: some View {
        ContentCard {
            EyebrowLabel("VITALS")
            Text("心率与负荷")
                .font(.system(size: 22, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(TodayTheme.ink)

            if let heartRateSamples = event.associatedMetrics?.heartRateSamples, !heartRateSamples.isEmpty {
                Chart(heartRateSamples, id: \.date) { sample in
                    LineMark(
                        x: .value("时间", sample.date),
                        y: .value("心率", sample.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(TodayTheme.rose)

                    AreaMark(
                        x: .value("时间", sample.date),
                        y: .value("心率", sample.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(TodayTheme.rose.opacity(0.18))
                }
                .frame(height: 180)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4))
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }

            HStack(spacing: 10) {
                metricCard(title: "平均", value: bpmText(event.associatedMetrics?.averageHeartRate))
                metricCard(title: "最高", value: bpmText(event.associatedMetrics?.maxHeartRate))
                metricCard(title: "最低", value: bpmText(event.associatedMetrics?.minHeartRate))
            }

            HStack(spacing: 10) {
                metricCard(title: "步数", value: event.associatedMetrics?.stepCount.map(String.init) ?? "0")
                metricCard(title: "热量", value: event.associatedMetrics?.activeEnergy.map { "\(Int($0.rounded())) kcal" } ?? "0")
                metricCard(title: "距离", value: distanceText(event.associatedMetrics?.distance))
            }
        }
    }

    @ViewBuilder
    private var sleepSection: some View {
        if let sleepStages = event.associatedMetrics?.sleepStages, !sleepStages.isEmpty {
            ContentCard {
                EyebrowLabel("SLEEP STAGES")
                Text("睡眠结构")
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(TodayTheme.ink)

                SleepStageDetailBar(segments: sleepStages)
                    .frame(height: 28)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 10)], spacing: 10) {
                    ForEach(stageDurations, id: \.stage) { item in
                        metricCard(
                            title: item.stage.label,
                            value: item.durationText
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var annotationSection: some View {
        ContentCard {
            EyebrowLabel("ANNOTATE")
            Text("这段时间还没有名字")
                .font(.system(size: 22, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(TodayTheme.ink)

            Text("如果你记得这段留白发生了什么，现在就可以把它标出来。")
                .font(.system(size: 14))
                .foregroundStyle(TodayTheme.inkMuted)

            Button("标注这段时间") {
                onAnnotate?()
            }
            .buttonStyle(.plain)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(TodayTheme.teal)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func detailChip(title: String, value: String, systemImage: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(TodayTheme.inkMuted)

            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .semibold))
                }

                Text(value)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
            }
            .foregroundStyle(TodayTheme.inkSoft)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TodayTheme.card.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(TodayTheme.inkMuted)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(TodayTheme.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TodayTheme.elevatedCard.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var timeRangeText: String {
        let start = event.startDate.formatted(.dateTime.hour().minute().locale(chineseLocale))
        let end = event.endDate.formatted(.dateTime.hour().minute().locale(chineseLocale))
        return "\(start) - \(end)"
    }

    private var weatherText: String {
        guard let weather = event.associatedMetrics?.weather else { return "未匹配" }
        return "\(Int(weather.temperature.rounded()))° · \(weather.condition.localizedLabel)"
    }

    private var stageDurations: [(stage: SleepStage, durationText: String)] {
        guard let segments = event.associatedMetrics?.sleepStages else { return [] }
        let grouped = Dictionary(grouping: segments, by: \.stage)

        return grouped
            .map { stage, values in
                let duration = values.reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) }
                let minutes = max(Int(duration / 60), 1)
                return (stage: stage, durationText: minutes >= 60
                    ? "\(minutes / 60)h\(minutes % 60)m"
                    : "\(minutes)min")
            }
            .sorted { $0.stage.sortOrder < $1.stage.sortOrder }
    }

    private func bpmText(_ value: Double?) -> String {
        guard let value else { return "无" }
        return "\(Int(value.rounded())) bpm"
    }

    private func distanceText(_ value: Double?) -> String {
        guard let value else { return "无" }
        if value >= 1000 {
            return String(format: "%.1f km", value / 1000)
        }
        return "\(Int(value.rounded())) m"
    }
}

private struct SleepStageDetailBar: View {
    let segments: [SleepStageSegment]

    var body: some View {
        GeometryReader { proxy in
            let totalDuration = max(segments.reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) }, 1)

            HStack(spacing: 4) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(segment.stage.color)
                        .frame(width: max(10, proxy.size.width * (segment.end.timeIntervalSince(segment.start) / totalDuration)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct PhotoThumbnailView: View {
    let localIdentifier: String

    @State private var image: UIImage?
    private let imageManager = PHCachingImageManager()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(TodayTheme.card)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ProgressView()
                    .tint(TodayTheme.inkMuted)
            }
        }
        .frame(width: 150, height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(TodayTheme.border, lineWidth: 1)
        )
        .task(id: localIdentifier) {
            await loadImage()
        }
    }

    private func loadImage() async {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = assets.firstObject else { return }

        let options = PHImageRequestOptions()
        options.resizeMode = .fast
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        image = await withCheckedContinuation { continuation in
            imageManager.requestImage(
                for: asset,
                targetSize: CGSize(width: 300, height: 300),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}

private extension WeatherCondition {
    var localizedLabel: String {
        switch self {
        case .clear:
            return "晴"
        case .cloudy:
            return "多云"
        case .rain:
            return "雨"
        case .snow:
            return "雪"
        case .fog:
            return "雾"
        case .wind:
            return "风"
        case .thunderstorm:
            return "雷暴"
        case .unknown:
            return "未知"
        }
    }
}

private extension SleepStage {
    var color: Color {
        switch self {
        case .deep:
            return TodayTheme.scrollNight
        case .light:
            return TodayTheme.sleepIndigo
        case .rem:
            return TodayTheme.scrollSunrise
        case .awake:
            return TodayTheme.scrollGold
        case .unknown:
            return TodayTheme.inkFaint
        }
    }

    var label: String {
        switch self {
        case .deep:
            return "深睡"
        case .light:
            return "浅睡"
        case .rem:
            return "REM"
        case .awake:
            return "清醒"
        case .unknown:
            return "未知"
        }
    }

    var sortOrder: Int {
        switch self {
        case .deep:
            return 0
        case .light:
            return 1
        case .rem:
            return 2
        case .awake:
            return 3
        case .unknown:
            return 4
        }
    }
}
