import SwiftUI

struct HistoryDayDetailScreen: View {
    let detail: HistoryDayDetail

    private let chineseLocale = Locale(identifier: "zh_CN")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summaryCard
                recordSection
            }
            .padding(.vertical, 20)
        }
        .background(TodayTheme.background)
        .navigationTitle(detail.date.formatted(.dateTime.month(.abbreviated).day().locale(chineseLocale)))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryCard: some View {
        ContentCard(background: TodayTheme.accentSoft.opacity(0.72)) {
            EyebrowLabel("DAY DETAIL")

            Text(detail.title)
                .font(.system(size: 23, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(TodayTheme.ink)

            Text(detail.narrative)
                .font(.subheadline)
                .foregroundStyle(TodayTheme.inkMuted)
                .lineSpacing(4)

            HistoryBadgeRow(items: detail.badges)
        }
        .padding(.horizontal, 20)
    }

    private var recordSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("当天片段")
                .font(.system(size: 23, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(TodayTheme.ink)
                .padding(.horizontal, 20)

            VStack(spacing: 12) {
                ForEach(detail.records) { record in
                    HistoryMomentCard(record: record)
                }
            }
            .padding(.horizontal, 20)
        }
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

                    Text(record.createdAt.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute()))
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
