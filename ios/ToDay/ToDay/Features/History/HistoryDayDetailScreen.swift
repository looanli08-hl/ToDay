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
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(detail.date.formatted(.dateTime.month(.abbreviated).day().locale(chineseLocale)))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(detail.title)
                .font(.title3.weight(.semibold))

            Text(detail.narrative)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HistoryBadgeRow(items: detail.badges)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.93, blue: 0.86), Color(red: 0.89, green: 0.94, blue: 0.90)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 20)
    }

    private var recordSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("当天片段")
                .font(.title3.weight(.semibold))
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
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            if record.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("这条记录还没有备注，后续可以继续补充当天发生了什么。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text(record.note)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
