import SwiftUI

struct DayScrollView: View {
    let entries: [InferredEvent]
    let date: Date
    let isToday: Bool
    var onEventTap: ((InferredEvent) -> Void)?

    private let calendar = Calendar.current

    /// Groups entries into primary events with inline mood/memo annotations.
    private var groupedEntries: [(event: InferredEvent, memos: [InferredEvent])] {
        let primaryEvents = entries.filter { $0.kind != .mood }
        let moodEvents = entries.filter { $0.kind == .mood }

        var result: [(event: InferredEvent, memos: [InferredEvent])] = []
        var assignedMoodIDs: Set<UUID> = []

        for event in primaryEvents {
            let inlineMemos = moodEvents.filter { memo in
                !assignedMoodIDs.contains(memo.id)
                    && memo.startDate >= event.startDate
                    && memo.startDate < event.endDate
            }
            for memo in inlineMemos {
                assignedMoodIDs.insert(memo.id)
            }
            result.append((event: event, memos: inlineMemos))
        }

        // Standalone mood events that don't fall within any primary event
        for mood in moodEvents where !assignedMoodIDs.contains(mood.id) {
            result.append((event: mood, memos: []))
        }

        // Sort by startDate to preserve chronological order
        result.sort { $0.event.startDate < $1.event.startDate }
        return result
    }

    var body: some View {
        ZStack {
            // The gradient IS the hero — the scroll painting
            TimeGradient.dayPainting
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous))

            VStack(spacing: 0) {
                if entries.isEmpty {
                    emptyGapRow
                } else {
                    ForEach(Array(groupedEntries.enumerated()), id: \.element.event.id) { index, group in
                        eventRow(group.event, memos: group.memos, index: index)
                    }
                }

                // Current time needle
                if isToday {
                    currentTimeNeedle
                        .padding(.top, AppSpacing.sm)
                }
            }
            .padding(.vertical, AppSpacing.lg)
        }
    }

    // MARK: - Event Row

    @ViewBuilder
    private func eventRow(_ event: InferredEvent, memos: [InferredEvent], index: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Breathing space between cards
            if index > 0 {
                // Subtle connector line between events
                HStack(spacing: 0) {
                    Spacer()
                        .frame(width: AppSpacing.lg)

                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 1)
                        .frame(height: AppSpacing.md)

                    Spacer()
                }
                .padding(.vertical, AppSpacing.xxs)
            }

            // Time label — tiny, floating above the card
            HStack(spacing: AppSpacing.xxs) {
                // Event dot
                Circle()
                    .fill(eventColor(event))
                    .frame(width: 6, height: 6)

                Text(timeText(event.startDate))
                    .font(AppFont.micro())
                    .foregroundStyle(Color.white.opacity(0.7))
                    .tracking(0.5)

                if event.duration > 60 {
                    Text("-")
                        .font(AppFont.micro())
                        .foregroundStyle(Color.white.opacity(0.4))

                    Text(timeText(event.endDate))
                        .font(AppFont.micro())
                        .foregroundStyle(Color.white.opacity(0.4))
                }
            }
            .padding(.leading, AppSpacing.lg - 3)
            .padding(.bottom, AppSpacing.xxs)

            // Event card
            HStack(spacing: 0) {
                // Thin connector from dot
                Spacer()
                    .frame(width: AppSpacing.lg)

                if event.kind == .mood {
                    moodRow(event)
                } else if event.kind == .dataGap {
                    dataGapRow(event)
                } else {
                    EventCardView(event: event, inlineMemos: memos)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onEventTap?(event)
                        }
                }
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.kindBadgeTitle) \(event.resolvedName), \(event.scrollDurationText)")
    }

    // MARK: - Mood Row

    private func moodRow(_ event: InferredEvent) -> some View {
        HStack(spacing: AppSpacing.xxs) {
            Circle()
                .fill(AppColor.mood)
                .frame(width: 5, height: 5)

            Text(event.resolvedName)
                .font(AppFont.memo())
                .foregroundStyle(AppColor.mood)

            if let note = event.subtitle, !note.isEmpty {
                Text(note)
                    .font(AppFont.memo())
                    .foregroundStyle(AppColor.labelTertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(.ultraThinMaterial)
        .background(AppColor.mood.opacity(0.06))
        .clipShape(Capsule())
    }

    // MARK: - Data Gap Row

    private func dataGapRow(_ event: InferredEvent) -> some View {
        HStack(spacing: AppSpacing.xxs) {
            Text("\u{00B7}\u{00B7}\u{00B7}")
                .font(AppFont.small())
                .foregroundStyle(Color.white.opacity(0.3))

            Text(event.scrollDurationText)
                .font(AppFont.micro())
                .foregroundStyle(Color.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
    }

    // MARK: - Empty Gap Row

    private var emptyGapRow: some View {
        VStack(spacing: AppSpacing.md) {
            Text("the day unfolds...")
                .font(AppFont.whisper())
                .foregroundStyle(Color.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, minHeight: 160)
    }

    // MARK: - Current Time Needle

    private var currentTimeNeedle: some View {
        HStack(spacing: AppSpacing.xxs) {
            Spacer()
                .frame(width: AppSpacing.lg - 3)

            Circle()
                .fill(AppColor.accent)
                .frame(width: 6, height: 6)

            Rectangle()
                .fill(AppColor.accent.opacity(0.4))
                .frame(height: 1)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, AppSpacing.sm)
        .allowsHitTesting(false)
    }

    // MARK: - Helpers

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
