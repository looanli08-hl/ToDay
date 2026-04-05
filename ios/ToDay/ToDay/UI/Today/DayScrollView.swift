import SwiftUI

struct DayScrollView: View {
    let entries: [InferredEvent]
    let date: Date
    let isToday: Bool
    var onEventTap: ((InferredEvent) -> Void)?

    private let calendar = Calendar.current
    private let timeColumnWidth: CGFloat = 44
    private let connectorWidth: CGFloat = 20
    private let minRowHeight: CGFloat = 44
    private let maxRowHeight: CGFloat = 180

    var body: some View {
        ZStack {
            // Time-of-day gradient background
            timeGradient
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous))

            VStack(spacing: AppSpacing.xxs) {
                if entries.isEmpty {
                    emptyGapRow
                } else {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, event in
                        eventRow(event, index: index)
                    }
                }

                // Current time needle
                if isToday {
                    currentTimeNeedle
                }
            }
            .padding(.vertical, AppSpacing.md)
        }
    }

    // MARK: - Time Gradient

    private var timeGradient: some View {
        LinearGradient(
            stops: [
                .init(color: AppColor.timelineNight, location: 0.0),
                .init(color: AppColor.timelineNight, location: 5.0 / 24.0),
                .init(color: AppColor.timelineSunrise, location: 7.0 / 24.0),
                .init(color: AppColor.timelineGold, location: 12.0 / 24.0),
                .init(color: AppColor.timelineNoon, location: 14.0 / 24.0),
                .init(color: AppColor.timelineSunset, location: 18.0 / 24.0),
                .init(color: AppColor.timelineViolet, location: 20.0 / 24.0),
                .init(color: AppColor.timelineNight, location: 1.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Event Row

    @ViewBuilder
    private func eventRow(_ event: InferredEvent, index: Int) -> some View {
        let rowHeight = proportionalHeight(for: event)

        HStack(alignment: .top, spacing: 0) {
            // Time column
            VStack(alignment: .trailing, spacing: 2) {
                Text(timeText(event.startDate))
                    .font(AppFont.small())
                    .foregroundStyle(AppColor.label.opacity(0.6))

                if event.duration > 60 {
                    Text(timeText(event.endDate))
                        .font(AppFont.small())
                        .foregroundStyle(AppColor.label.opacity(0.35))
                }
            }
            .frame(width: timeColumnWidth, alignment: .trailing)

            // Connector
            VStack(spacing: 0) {
                Circle()
                    .fill(eventColor(event))
                    .frame(width: 8, height: 8)

                if rowHeight > 16 {
                    Rectangle()
                        .fill(AppColor.label.opacity(0.1))
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: connectorWidth)

            // Event card
            if event.kind == .mood {
                moodRow(event)
            } else if event.kind == .dataGap {
                dataGapRow(event)
            } else {
                EventCardView(event: event)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onEventTap?(event)
                    }
            }
        }
        .frame(minHeight: rowHeight, alignment: .top)
        .padding(.horizontal, AppSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.kindBadgeTitle) \(event.resolvedName), \(event.scrollDurationText)")
    }

    // MARK: - Mood Row

    private func moodRow(_ event: InferredEvent) -> some View {
        HStack(spacing: AppSpacing.xxs) {
            Circle()
                .fill(AppColor.mood)
                .frame(width: 7, height: 7)

            Text(event.resolvedName)
                .font(AppFont.small())
                .foregroundStyle(AppColor.mood)

            if let note = event.subtitle, !note.isEmpty {
                Text(note)
                    .font(AppFont.small())
                    .foregroundStyle(AppColor.labelTertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xxs)
        .background(AppColor.mood.opacity(0.08))
        .clipShape(Capsule())
        .frame(minHeight: 38)
    }

    // MARK: - Data Gap Row

    private func dataGapRow(_ event: InferredEvent) -> some View {
        HStack {
            Text("这段时间没有记录 \u{00B7} \(event.scrollDurationText)")
                .font(AppFont.small())
                .foregroundStyle(AppColor.labelQuaternary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.sm)
    }

    // MARK: - Empty Gap Row

    private var emptyGapRow: some View {
        VStack(spacing: AppSpacing.md) {
            Text("还没有事件")
                .font(AppFont.bodyRegular())
                .foregroundStyle(AppColor.labelTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }

    // MARK: - Current Time Needle

    private var currentTimeNeedle: some View {
        HStack(spacing: 0) {
            Spacer()
                .frame(width: timeColumnWidth)

            ZStack {
                Circle()
                    .fill(AppColor.accent)
                    .frame(width: 6, height: 6)
            }
            .frame(width: connectorWidth)

            Rectangle()
                .fill(AppColor.separator)
                .frame(height: 1.5)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, AppSpacing.xs)
        .allowsHitTesting(false)
    }

    // MARK: - Helpers

    private func proportionalHeight(for event: InferredEvent) -> CGFloat {
        let minutes = event.duration / 60.0
        if event.kind == .mood { return 38 }
        if minutes < 5 { return minRowHeight }
        let scaled = minRowHeight + (minutes / 60.0) * 40.0
        return min(max(scaled, minRowHeight), maxRowHeight)
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func eventColor(_ event: InferredEvent) -> Color {
        AppColor.color(for: event.kind)
    }
}
