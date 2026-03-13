import SwiftUI

struct HistoryDayDetailScreen: View {
    @ObservedObject var viewModel: TodayViewModel

    let date: Date

    @State private var timeline: DayTimeline?
    @State private var selectedEvent: InferredEvent?
    @State private var isLoading = false

    private let chineseLocale = Locale(identifier: "zh_CN")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summaryCard

                if isLoading && timeline == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                        .tint(TodayTheme.teal)
                } else if let timeline {
                    canvasSection(timeline)
                } else {
                    emptyState
                }

                if let detail = viewModel.historyDetail(for: date) {
                    manualRecordSection(detail)
                }
            }
            .padding(.vertical, 20)
        }
        .background(TodayTheme.background)
        .navigationTitle(date.formatted(.dateTime.month(.abbreviated).day().locale(chineseLocale)))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedEvent) { event in
            EventDetailView(event: event)
        }
        .task(id: date) {
            await loadTimeline()
        }
    }

    private var summaryCard: some View {
        ContentCard(background: TodayTheme.accentSoft.opacity(0.72)) {
            EyebrowLabel("DAY SCROLL")

            Text("当天画卷")
                .font(.system(size: 23, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(TodayTheme.ink)

            Text(summaryText)
                .font(.subheadline)
                .foregroundStyle(TodayTheme.inkMuted)
                .lineSpacing(4)

            if let timeline {
                HistoryBadgeRow(items: timeline.stats.map { "\($0.title) \($0.value)" })
            } else if let detail = viewModel.historyDetail(for: date) {
                HistoryBadgeRow(items: detail.badges)
            }
        }
        .padding(.horizontal, 20)
    }

    private func canvasSection(_ timeline: DayTimeline) -> some View {
        ContentCard {
            EyebrowLabel("SCROLL REPLAY")

            Text("横向回看")
                .font(.system(size: 23, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(TodayTheme.ink)

            Text("把这一天摊成一卷，从凌晨到夜里重新看一遍。")
                .font(.system(size: 14))
                .foregroundStyle(TodayTheme.inkMuted)
                .lineSpacing(4)

            DayScrollView(
                timeline: timeline,
                onEventTap: { event in
                    selectedEvent = event
                },
                onBlankTap: { event in
                    selectedEvent = event
                }
            )
        }
        .padding(.horizontal, 20)
    }

    private func manualRecordSection(_ detail: HistoryDayDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("手动记录")
                .font(.system(size: 23, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(TodayTheme.ink)
                .padding(.horizontal, 20)

            Text(detail.narrative)
                .font(.system(size: 14))
                .foregroundStyle(TodayTheme.inkMuted)
                .lineSpacing(4)
                .padding(.horizontal, 20)

            VStack(spacing: 12) {
                ForEach(detail.records) { record in
                    HistoryMomentCard(record: record)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var emptyState: some View {
        ContentCard {
            EyebrowLabel("EMPTY")

            Text("这一天还没有可回看的画卷")
                .font(.system(size: 23, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(TodayTheme.ink)

            Text("如果这一天没有 HealthKit 轨迹，也没有手动记录，这里会保持空白。")
                .font(.subheadline)
                .foregroundStyle(TodayTheme.inkMuted)
        }
        .padding(.horizontal, 20)
    }

    private var summaryText: String {
        if let timeline {
            return timeline.summary
        }

        if let detail = viewModel.historyDetail(for: date) {
            return detail.narrative
        }

        return "这一天还没有形成完整的事件回放。"
    }

    private func loadTimeline() async {
        isLoading = true
        timeline = await viewModel.loadTimeline(for: date)
        isLoading = false
    }
}

private struct HistoryMomentCard: View {
    let record: MoodRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(record.mood.emoji) \(record.mood.rawValue)")
                        .font(.headline)

                    Text(record.displayTimeLabel())
                        .font(.caption.weight(.medium))
                        .foregroundStyle(TodayTheme.inkMuted)
                }

                Spacer()
            }

            if record.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("这条记录还没有备注，后续可以继续补充当天发生了什么。")
                    .font(.subheadline)
                    .foregroundStyle(TodayTheme.inkMuted)
            } else {
                Text(record.note)
                    .font(.subheadline)
                    .foregroundStyle(TodayTheme.inkSoft)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(TodayTheme.elevatedCard.opacity(0.72))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TodayTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(TodayTheme.border, lineWidth: 1)
        )
    }
}
