import SwiftUI
import UIKit

struct OverviewStat: Identifiable {
    let label: String
    let value: String
    let tint: Color
    let background: Color

    var id: String { label }
}

private struct RiverPoint: Identifiable {
    let index: Int
    let x: CGFloat
    let centerY: CGFloat
    let topY: CGFloat
    let bottomY: CGFloat
    let intensity: CGFloat
    let color: Color
    let progress: Double

    var id: Int { index }
}

struct OverviewStatCard: View {
    let stat: OverviewStat

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(stat.label)
                .font(.system(size: 11))
                .foregroundStyle(TodayTheme.inkMuted)

            Text(stat.value)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(stat.tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .frame(width: 92, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(stat.background)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(TodayTheme.border, lineWidth: 1)
        )
    }
}

struct TodayFlowSignatureView: View {
    let entries: [InferredEvent]

    var body: some View {
        GeometryReader { proxy in
            let points = flowPoints(in: proxy.size)

            ZStack {
                flowBody(points: points)
                    .fill(flowGradient(points: points).opacity(0.35))

                flowCenterLine(points: points)
                    .stroke(flowGradient(points: points), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))

                ForEach(points.filter(isPeakPoint)) { point in
                    Circle()
                        .fill(point.color)
                        .frame(width: 7, height: 7)
                        .shadow(color: point.color.opacity(0.28), radius: 8, x: 0, y: 0)
                        .position(x: point.x, y: point.centerY)
                }
            }
        }
    }

    private func flowPoints(in size: CGSize) -> [RiverPoint] {
        guard !entries.isEmpty else { return [] }

        let allSamples = entries
            .compactMap { $0.associatedMetrics?.heartRateSamples }
            .flatMap { $0 }
            .removingDuplicates()
            .sorted { $0.date < $1.date }

        guard allSamples.count >= 4 else {
            return fallbackFlowPoints(in: size)
        }

        let width = max(size.width, 1)
        let minHR = allSamples.map(\.value).min() ?? 40
        let maxHR = allSamples.map(\.value).max() ?? 180
        let hrRange = max(maxHR - minHR, 20)

        return allSamples.enumerated().map { index, sample in
            let progress = minuteProgress(for: sample.date)
            let x = width * CGFloat(progress)
            let normalized = CGFloat((sample.value - minHR) / hrRange)
            let intensity = normalized
            let centerY = size.height * (1.0 - normalized * 0.7 - 0.15)
            let amplitude = 3 + normalized * 8
            let color = color(for: sample.date)

            return RiverPoint(
                index: index,
                x: x,
                centerY: centerY,
                topY: centerY - amplitude,
                bottomY: centerY + amplitude,
                intensity: intensity,
                color: color,
                progress: progress
            )
        }
    }

    private func fallbackFlowPoints(in size: CGSize) -> [RiverPoint] {
        let width = max(size.width, 1)

        return entries.enumerated().map { index, entry in
            let progress = Double(entry.timelineStartMinuteOfDay) / Double(24 * 60)
            let x = width * CGFloat(progress)
            let intensity = entry.kind.flowIntensity
            let centerY = size.height * (0.84 - intensity * 0.5)
            let amplitude = 8 + (intensity * 16)

            return RiverPoint(
                index: index,
                x: x,
                centerY: centerY,
                topY: centerY - amplitude,
                bottomY: centerY + amplitude,
                intensity: intensity,
                color: entry.kind.flowColor,
                progress: progress
            )
        }
    }

    private func flowBody(points: [RiverPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }

        let topPoints = points.map { CGPoint(x: $0.x, y: $0.topY) }
        let bottomPoints = points.reversed().map { CGPoint(x: $0.x, y: $0.bottomY) }

        path.move(to: CGPoint(x: first.x, y: first.topY))
        addSmoothSegments(for: topPoints, to: &path)
        addSmoothSegments(for: bottomPoints, to: &path)
        path.closeSubpath()
        return path
    }

    private func flowCenterLine(points: [RiverPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        let centerPoints = points.map { CGPoint(x: $0.x, y: $0.centerY) }
        path.move(to: CGPoint(x: first.x, y: first.centerY))
        addSmoothSegments(for: centerPoints, to: &path)
        return path
    }

    private func addSmoothSegments(for points: [CGPoint], to path: inout Path) {
        guard points.count > 1 else { return }

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let midpoint = CGPoint(
                x: (previous.x + current.x) / 2,
                y: (previous.y + current.y) / 2
            )

            path.addQuadCurve(to: midpoint, control: previous)

            if index == points.count - 1 {
                path.addQuadCurve(to: current, control: midpoint)
            }
        }
    }

    private func flowGradient(points: [RiverPoint]) -> LinearGradient {
        let stops = points.isEmpty ? [Gradient.Stop(color: TodayTheme.inkFaint, location: 0)] : points.map { point in
            Gradient.Stop(
                color: point.color,
                location: point.progress
            )
        }

        return LinearGradient(
            gradient: Gradient(stops: stops),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func isPeakPoint(_ point: RiverPoint) -> Bool {
        guard point.intensity >= 0.75 else { return false }
        guard let event = event(at: date(for: point.progress)) else { return false }
        return event.kind == .workout || event.kind == .activeWalk
    }

    private func minuteProgress(for date: Date) -> Double {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let minute = min(max(date.timeIntervalSince(startOfDay) / 60, 0), Double(24 * 60))
        return minute / Double(24 * 60)
    }

    private func date(for progress: Double) -> Date {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: entries.first?.startDate ?? Date())
        return startOfDay.addingTimeInterval(progress * Double(24 * 60 * 60))
    }

    private func event(at date: Date) -> InferredEvent? {
        entries.first { entry in
            entry.startDate <= date && date < entry.endDate
        }
    }

    private func color(for date: Date) -> Color {
        event(at: date)?.kind.flowColor ?? TodayTheme.inkFaint
    }
}

private extension Array where Element == HeartRateSample {
    func removingDuplicates() -> [HeartRateSample] {
        var seen = Set<HeartRateSample>()
        var result: [HeartRateSample] = []

        for sample in self where seen.insert(sample).inserted {
            result.append(sample)
        }

        return result
    }
}

struct TimelineStreamRow: View {
    let entry: InferredEvent
    let isExpanded: Bool
    let action: () -> Void
    let onPhotoTap: ([MoodPhotoAttachment], Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Text(entry.timelineTimeLabel)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(TodayTheme.inkMuted)
                    .frame(width: 74, alignment: .leading)

                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(entry.kind.flowBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(entry.kind.flowColor.opacity(isExpanded ? 0.24 : 0), lineWidth: 1.4)
                    )
                    .frame(width: 30, height: 30)
                    .overlay {
                        Text(entry.kind.icon)
                            .font(.system(size: 14))
                    }

                Text(entry.timelineTitle)
                    .font(.system(size: 15, weight: isExpanded ? .semibold : .regular))
                    .foregroundStyle(TodayTheme.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !entry.photoAttachments.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "photo")
                        Text("\(entry.photoAttachments.count)")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(TodayTheme.inkMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(TodayTheme.card)
                    .clipShape(Capsule())
                }

                if entry.isLive {
                    Text("进行中")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(TodayTheme.teal)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(TodayTheme.tealSoft)
                        .clipShape(Capsule())
                }

                IntensityBar(
                    durationMinutes: entry.timelineDurationMinutes,
                    fallbackProgress: entry.kind.flowIntensity,
                    color: entry.kind.flowColor
                )
                .frame(width: 56)

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(TodayTheme.inkMuted)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Text(entry.timelineDetail)
                        .font(.system(size: 14))
                        .foregroundStyle(TodayTheme.inkMuted)
                        .lineSpacing(4)

                    if !entry.photoAttachments.isEmpty {
                        TimelinePhotoStrip(attachments: entry.photoAttachments, onPhotoTap: onPhotoTap)
                    }
                }
                .padding(.leading, 84)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .background(isExpanded ? entry.kind.flowBackground : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture(perform: action)
    }
}

private struct TimelinePhotoStrip: View {
    let attachments: [MoodPhotoAttachment]
    let onPhotoTap: ([MoodPhotoAttachment], Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("记录照片")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(TodayTheme.inkMuted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(attachments.enumerated()), id: \.element.id) { index, attachment in
                        Button {
                            onPhotoTap(attachments, index)
                        } label: {
                            TimelinePhotoThumbnail(attachment: attachment)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct TimelinePhotoThumbnail: View {
    let attachment: MoodPhotoAttachment

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(TodayTheme.card)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "photo")
                        .font(.system(size: 18, weight: .medium))
                    Text("查看")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(TodayTheme.inkMuted)
            }
        }
        .frame(width: 88, height: 88)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(TodayTheme.border, lineWidth: 1)
        )
        .task(id: attachment.id) {
            image = MoodPhotoLibrary.image(for: attachment)
        }
    }
}

struct IntensityBar: View {
    let durationMinutes: Int?
    let fallbackProgress: CGFloat
    let color: Color

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(TodayTheme.border)
                .frame(height: 3)

            Capsule()
                .fill(color)
                .frame(width: max(10, 56 * visualProgress), height: 3)
        }
    }

    private var visualProgress: CGFloat {
        guard let durationMinutes else { return max(0.18, fallbackProgress) }
        let cappedMinutes = min(max(CGFloat(durationMinutes), 5), 240)
        let normalized = sqrt(cappedMinutes / 240)
        return max(0.18, normalized)
    }
}

struct RecentDayCard: View {
    let digest: RecentDayDigest
    let locale: Locale

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(digest.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(TodayTheme.inkSoft)

                    Spacer()

                    Text(digest.date.formatted(.dateTime.month(.abbreviated).day().locale(locale)))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(TodayTheme.inkMuted)
                }

                Text(digest.detail)
                    .font(.system(size: 13))
                    .foregroundStyle(TodayTheme.inkMuted)

                if let notePreview = digest.notePreview {
                    Text("“\(notePreview)”")
                        .font(.system(size: 12))
                        .foregroundStyle(TodayTheme.inkSoft)
                        .lineLimit(1)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TodayTheme.elevatedCard.opacity(0.72))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(TodayTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var color: Color {
        switch digest.mood {
        case .happy:
            return TodayTheme.accent
        case .calm:
            return TodayTheme.teal
        case .focused:
            return TodayTheme.teal
        case .grateful:
            return TodayTheme.scrollGold
        case .excited:
            return TodayTheme.workoutOrange
        case .tired:
            return TodayTheme.blue
        case .anxious:
            return TodayTheme.scrollViolet
        case .sad:
            return TodayTheme.sleepIndigo
        case .irritated:
            return TodayTheme.rose
        case .bored:
            return TodayTheme.inkFaint
        case .sleepy:
            return TodayTheme.blue
        case .satisfied:
            return TodayTheme.scrollSunrise
        case .none:
            return TodayTheme.inkFaint
        }
    }
}

extension EventKind {
    var flowColor: Color {
        switch self {
        case .sleep:
            return TodayTheme.blue
        case .workout, .commute, .activeWalk:
            return TodayTheme.rose
        case .userAnnotated:
            return TodayTheme.teal
        case .quietTime:
            return TodayTheme.inkFaint
        case .mood:
            return TodayTheme.accent
        }
    }

    var flowBackground: Color {
        switch self {
        case .sleep:
            return TodayTheme.blueSoft
        case .workout, .commute, .activeWalk:
            return TodayTheme.roseSoft
        case .userAnnotated:
            return TodayTheme.tealSoft
        case .quietTime:
            return TodayTheme.elevatedCard
        case .mood:
            return TodayTheme.accentSoft
        }
    }

    var flowIntensity: CGFloat {
        switch self {
        case .sleep:
            return 0.24
        case .workout:
            return 0.82
        case .commute, .activeWalk:
            return 0.68
        case .userAnnotated:
            return 0.90
        case .quietTime:
            return 0.20
        case .mood:
            return 0.48
        }
    }

    var icon: String {
        switch self {
        case .sleep:
            return "🌙"
        case .workout:
            return "🏃"
        case .commute:
            return "🚶"
        case .activeWalk:
            return "👟"
        case .userAnnotated:
            return "⌘"
        case .quietTime:
            return "☁️"
        case .mood:
            return "✦"
        }
    }
}

private extension InferredEvent {
    var timelineTitle: String {
        resolvedName
    }

    var timelineDetail: String {
        let note = subtitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasNote = !(note?.isEmpty ?? true)

        switch kind {
        case .mood:
            if isLive {
                if let note, hasNote {
                    return "\(note) · 正在进行，已持续 \(durationDescription)"
                }
                return "正在进行，已持续 \(durationDescription)"
            }

            if let durationMinutes = timelineDurationMinutes {
                if let note, hasNote {
                    return "\(note) · 持续 \(durationDescription(for: durationMinutes))"
                }
                return "持续 \(durationDescription(for: durationMinutes))"
            }

            if let note, hasNote {
                return note
            }
            return "记录了这一刻的状态。"
        case .sleep:
            return note ?? "系统推断出一段睡眠。"
        case .workout:
            return note ?? "系统推断出一段训练。"
        case .commute:
            return note ?? "系统推断出一段通勤。"
        case .activeWalk:
            return note ?? "系统推断出一段活跃步行。"
        case .quietTime:
            return note ?? "这段时间相对平静。"
        case .userAnnotated:
            return note ?? "这是你主动标注的一段时间。"
        }
    }

    var timelineTimeLabel: String {
        if kind == .sleep && Calendar.current.component(.hour, from: startDate) == 0 && startDate != endDate {
            return "昨夜"
        }

        let startLabel = Self.clockFormatter.string(from: startDate)

        if isLive {
            return "\(startLabel) - 现在"
        }

        guard let endDate = timelineEndDate else {
            return startLabel
        }

        let endLabel = Self.clockFormatter.string(from: endDate)
        return "\(startLabel) - \(endLabel)"
    }

    var timelineDurationMinutes: Int? {
        guard isLive || endDate > startDate else { return nil }
        return max(Int(endDate.timeIntervalSince(startDate) / 60), 1)
    }

    var timelineStartMinuteOfDay: Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: startDate)
        return ((components.hour ?? 0) * 60) + (components.minute ?? 0)
    }

    private var timelineEndDate: Date? {
        guard endDate > startDate else { return nil }
        return endDate
    }

    private var durationDescription: String {
        durationDescription(for: timelineDurationMinutes ?? 1)
    }

    private func durationDescription(for minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let remainder = minutes % 60

            if remainder == 0 {
                return "\(hours) 小时"
            }

            return "\(hours) 小时 \(remainder) 分钟"
        }

        return "\(minutes) 分钟"
    }

    private static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
