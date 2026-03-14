import SwiftUI

struct WatchMiniTimelineView: View {
    let events: [WatchTimelineEventSnapshot]
    let selectedEventID: UUID?
    let summary: String
    let dataSource: WatchViewModel.TimelineDataSource
    let onSelect: (WatchTimelineEventSnapshot) -> Void

    @State private var crownValue: Double = 0
    @State private var selectedIndex = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if events.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                                Button {
                                    selectedIndex = index
                                    onSelect(event)
                                } label: {
                                    timelineRow(event, isCurrent: event.id == selectedEventID)
                                }
                                .buttonStyle(.plain)
                                .id(event.id)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 12)
                    }
                    .focusable(true)
                    .digitalCrownRotation(
                        $crownValue,
                        from: 0,
                        through: Double(max(events.count - 1, 0)),
                        by: 1,
                        sensitivity: .medium,
                        isContinuous: false,
                        isHapticFeedbackEnabled: true
                    )
                    .onAppear {
                        syncSelection(with: events)
                        scrollToSelection(proxy: proxy, animated: false)
                    }
                    .onChange(of: selectedEventID) { _, _ in
                        syncSelection(with: events)
                        scrollToSelection(proxy: proxy, animated: true)
                    }
                    .onChange(of: events.map(\.id)) { _, _ in
                        syncSelection(with: events)
                        scrollToSelection(proxy: proxy, animated: false)
                    }
                    .onChange(of: crownValue) { _, newValue in
                        guard !events.isEmpty else { return }
                        selectedIndex = min(max(Int(newValue.rounded()), 0), events.count - 1)
                        scrollToSelection(proxy: proxy, animated: true)
                    }
                }
            }
        }
        .padding(.top, 4)
        .background(WatchTheme.background.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("今日片段")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(WatchTheme.text)

                Label(dataSource.label, systemImage: WatchTheme.sourceIcon(for: dataSource))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(WatchTheme.sourceFill(for: dataSource))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(WatchTheme.sourceBackground(for: dataSource))
                    .clipShape(Capsule())
            }

            Text(summary)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(WatchTheme.textMuted)
                .lineLimit(2)
        }
        .padding(.horizontal, 10)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今天还没有片段")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(WatchTheme.text)

            Text("戴着手表活动一会儿，或先记录一个心情。")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(WatchTheme.textMuted)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WatchTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(WatchTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 10)
    }

    private func timelineRow(_ event: WatchTimelineEventSnapshot, isCurrent: Bool) -> some View {
        HStack(spacing: 10) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(WatchTheme.eventAccent(for: event.kindRawValue).opacity(0.16))
                        .frame(width: 28, height: 28)

                    Image(systemName: event.iconName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(WatchTheme.eventAccent(for: event.kindRawValue))
                }

                Circle()
                    .fill(isCurrent ? WatchTheme.accent : WatchTheme.border)
                    .frame(width: isCurrent ? 7 : 4, height: isCurrent ? 7 : 4)
            }
            .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.resolvedName)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(WatchTheme.text)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(event.timeRangeLabel)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(WatchTheme.textMuted)
                        .lineLimit(1)

                    if event.isLive {
                        Text("进行中")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(WatchTheme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(WatchTheme.accent.opacity(0.14))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer(minLength: 8)

            if isCurrent {
                Text("现在")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(WatchTheme.accent)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isCurrent ? WatchTheme.elevatedSoft : WatchTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isCurrent ? WatchTheme.accent.opacity(0.55) : WatchTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func syncSelection(with events: [WatchTimelineEventSnapshot]) {
        guard !events.isEmpty else {
            selectedIndex = 0
            crownValue = 0
            return
        }

        if let selectedEventID,
           let matchedIndex = events.firstIndex(where: { $0.id == selectedEventID }) {
            selectedIndex = matchedIndex
            crownValue = Double(matchedIndex)
            return
        }

        selectedIndex = min(selectedIndex, events.count - 1)
        crownValue = Double(selectedIndex)
    }

    private func scrollToSelection(proxy: ScrollViewProxy, animated: Bool) {
        guard !events.isEmpty else { return }
        let eventID = events[min(max(selectedIndex, 0), events.count - 1)].id

        if animated {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(eventID, anchor: .center)
            }
        } else {
            proxy.scrollTo(eventID, anchor: .center)
        }
    }
}

private extension WatchTimelineEventSnapshot {
    var iconName: String {
        switch kindRawValue {
        case "sleep":
            return "bed.double.fill"
        case "workout":
            if resolvedName.contains("跑") {
                return "figure.run"
            }
            if resolvedName.contains("骑") {
                return "bicycle"
            }
            return "figure.strengthtraining.traditional"
        case "commute":
            return "tram.fill"
        case "activeWalk":
            return "figure.walk"
        case "quietTime":
            return "sparkles.rectangle.stack"
        case "userAnnotated":
            return "pencil.and.scribble"
        case "mood":
            return MoodRecord.Mood(storedValue: displayName)?.emoji == nil ? "face.smiling" : "heart.circle.fill"
        case "session":
            return "scope"
        default:
            return "circle.hexagongrid.fill"
        }
    }

    var timeRangeLabel: String {
        "\(startDate.formatted(Self.timeFormat)) - \(endDate.formatted(Self.timeFormat))"
    }

    private static let timeFormat: Date.FormatStyle = .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)
}
