import SwiftUI

struct EventCardView: View {
    let event: InferredEvent
    var inlineMemos: [InferredEvent] = []

    var body: some View {
        HStack(spacing: 0) {
            // Refined color accent bar — 3pt, the primary type indicator
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(AppColor.color(for: event.kind))
                .frame(width: 3)
                .padding(.vertical, AppSpacing.xs)

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                // Event name + duration on same line
                HStack(alignment: .firstTextBaseline) {
                    Text(event.resolvedName)
                        .font(AppFont.body())
                        .foregroundStyle(AppColor.label)
                        .lineLimit(2)

                    Spacer()

                    Text(event.scrollDurationText)
                        .font(AppFont.small())
                        .foregroundStyle(AppColor.labelTertiary)
                }

                // Detail line — very small, warm metadata
                if let detail = detailText {
                    Text(detail)
                        .font(AppFont.micro())
                        .foregroundStyle(AppColor.labelQuaternary)
                        .lineLimit(1)
                        .padding(.top, AppSpacing.xxxs)
                }

                // Inline mood/memo annotations — handwritten-feeling notes
                if !inlineMemos.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        ForEach(inlineMemos) { memo in
                            inlineMemoView(memo)
                        }
                    }
                    .padding(.top, AppSpacing.xxs)
                }
            }
            .padding(.leading, AppSpacing.sm)
            .padding(.trailing, AppSpacing.sm)
            .padding(.vertical, AppSpacing.sm)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            // Layered material: subtle event-type tint over ultra-thin glass
            ZStack {
                Color.white.opacity(0.5)
                AppColor.cardTint(for: event.kind)
            }
        )
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        .appShadow(.subtle)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.kindBadgeTitle), \(event.resolvedName)")
        .accessibilityValue(event.scrollDurationText)
    }

    // MARK: - Inline Memo

    private func inlineMemoView(_ memo: InferredEvent) -> some View {
        HStack(spacing: AppSpacing.xxs) {
            // Subtle serif italic — like a handwritten margin note
            if let note = memo.subtitle, !note.isEmpty {
                Text(note)
                    .font(AppFont.memo())
                    .foregroundStyle(AppColor.mood.opacity(0.8))
                    .lineLimit(2)
            } else {
                Text(memo.resolvedName)
                    .font(AppFont.memo())
                    .foregroundStyle(AppColor.mood.opacity(0.8))
                    .lineLimit(1)
            }

            Spacer()

            Text(memoTimeText(memo.startDate))
                .font(AppFont.micro())
                .foregroundStyle(AppColor.labelQuaternary)
        }
        .padding(.leading, AppSpacing.xs)
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
