import SwiftUI

struct EventCardView: View {
    let event: InferredEvent
    var inlineMemos: [InferredEvent] = []

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            // Color accent bar
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(AppColor.color(for: event.kind))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                // Kind badge + duration
                HStack {
                    Text(event.kindBadgeTitle)
                        .font(AppFont.smallBold())
                        .foregroundStyle(AppColor.color(for: event.kind))

                    Spacer()

                    Text(event.scrollDurationText)
                        .font(AppFont.small())
                        .foregroundStyle(AppColor.labelTertiary)
                }

                // Event name
                Text(event.resolvedName)
                    .font(AppFont.body())
                    .foregroundStyle(AppColor.label)
                    .lineLimit(2)

                // Detail line
                if let detail = detailText {
                    Text(detail)
                        .font(AppFont.small())
                        .foregroundStyle(AppColor.labelTertiary)
                        .lineLimit(1)
                }

                // Inline mood/memo annotations
                if !inlineMemos.isEmpty {
                    ForEach(inlineMemos) { memo in
                        inlineMemoView(memo)
                    }
                }
            }
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(UIColor.secondarySystemGroupedBackground).opacity(0.82)
        )
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        .appShadow(.subtle)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.kindBadgeTitle), \(event.resolvedName)")
        .accessibilityValue(event.scrollDurationText)
    }

    // MARK: - Inline Memo

    private func inlineMemoView(_ memo: InferredEvent) -> some View {
        HStack(spacing: AppSpacing.xxs) {
            Circle()
                .fill(AppColor.mood)
                .frame(width: 5, height: 5)

            if let note = memo.subtitle, !note.isEmpty {
                Text(note)
                    .font(AppFont.small())
                    .foregroundStyle(AppColor.mood)
                    .lineLimit(1)
            } else {
                Text(memo.resolvedName)
                    .font(AppFont.small())
                    .foregroundStyle(AppColor.mood)
                    .lineLimit(1)
            }

            Spacer()

            Text(memoTimeText(memo.startDate))
                .font(AppFont.small())
                .foregroundStyle(AppColor.labelQuaternary)
        }
        .padding(.horizontal, AppSpacing.xs)
        .padding(.vertical, 3)
        .background(AppColor.mood.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func memoTimeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    // MARK: - Detail Text

    private var detailText: String? {
        var parts: [String] = []

        if let metrics = event.associatedMetrics {
            if let location = metrics.location, let name = location.placeName {
                parts.append(name)
            }
            if let weather = metrics.weather {
                parts.append("\(Int(weather.temperature))\u{00B0}C \(weather.condition.label)")
            }
            if let steps = metrics.stepCount, steps > 0 {
                parts.append("\(steps) 步")
            }
            if let distance = metrics.distance, distance > 0 {
                parts.append(String(format: "%.1f km", distance / 1000))
            }
        }

        if let subtitle = event.subtitle, !subtitle.isEmpty, parts.isEmpty {
            return subtitle
        }

        return parts.isEmpty ? event.subtitle : parts.joined(separator: " \u{00B7} ")
    }
}
