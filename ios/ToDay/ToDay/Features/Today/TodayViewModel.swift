import Foundation

struct TodayInsightSummary {
    let headline: String
    let narrative: String
    let badges: [String]
}

struct RecentDayDigest: Identifiable {
    let date: Date
    let title: String
    let detail: String
    let mood: MoodRecord.Mood?

    var id: Date { date }
}

@MainActor
final class TodayViewModel: ObservableObject {
    @Published private(set) var timeline: DayTimeline?
    @Published private(set) var insightSummary: TodayInsightSummary?
    @Published private(set) var recentDigests: [RecentDayDigest] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var showQuickRecord = false

    private let provider: any TimelineDataProviding
    private let recordStore: any MoodRecordStoring
    private let calendar = Calendar.current
    private var hasLoadedOnce = false
    private(set) var manualRecords: [MoodRecord] = []

    init(
        provider: any TimelineDataProviding,
        recordStore: any MoodRecordStoring
    ) {
        self.provider = provider
        self.recordStore = recordStore
        self.manualRecords = recordStore.loadRecords()
        refreshDerivedState(referenceDate: Date())
    }

    func loadIfNeeded() async {
        guard !hasLoadedOnce else { return }
        await load(forceReload: false)
    }

    func load(forceReload: Bool) async {
        guard !isLoading else { return }
        if hasLoadedOnce && !forceReload { return }

        isLoading = true
        errorMessage = nil
        manualRecords = recordStore.loadRecords()
        refreshDerivedState(referenceDate: Date())

        do {
            let base = try await provider.loadTimeline(for: Date())
            let merged = mergedTimeline(base: base)
            timeline = merged
            refreshDerivedState(referenceDate: merged.date)
            hasLoadedOnce = true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        isLoading = false
    }

    func addMoodRecord(_ record: MoodRecord) {
        manualRecords.insert(record, at: 0)
        manualRecords.sort { $0.createdAt > $1.createdAt }
        persistRecords()

        if let base = timeline {
            let merged = mergedTimeline(base: base)
            timeline = merged
            refreshDerivedState(referenceDate: merged.date)
        } else {
            refreshDerivedState(referenceDate: Date())
        }
    }

    private func mergedTimeline(base: DayTimeline) -> DayTimeline {
        let recordsForDay = manualRecords
            .filter { calendar.isDate($0.createdAt, inSameDayAs: base.date) }
            .sorted { $0.createdAt > $1.createdAt }
        let manualEntries = recordsForDay.map { $0.toTimelineEntry() }
        let notesCount = recordsForDay.filter { !$0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count

        var mergedStats = base.stats
        mergedStats.append(TimelineStat(title: "记录", value: "\(recordsForDay.count)"))

        if notesCount > 0 {
            mergedStats.append(TimelineStat(title: "备注", value: "\(notesCount)"))
        }

        return DayTimeline(
            date: base.date,
            summary: base.summary,
            source: base.source,
            stats: mergedStats,
            entries: manualEntries + base.entries
        )
    }

    private func refreshDerivedState(referenceDate: Date) {
        recentDigests = buildRecentDigests()
        insightSummary = buildInsightSummary(referenceDate: referenceDate)
    }

    private func buildInsightSummary(referenceDate: Date) -> TodayInsightSummary {
        let recordsForDay = manualRecords
            .filter { calendar.isDate($0.createdAt, inSameDayAs: referenceDate) }
            .sorted { $0.createdAt > $1.createdAt }
        let dominantMood = dominantMood(in: recordsForDay)
        let noteCount = recordsForDay.filter { !$0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        let latestNote = recordsForDay.first { !$0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let timelineEntryCount = timeline?.entries.count ?? 0

        if recordsForDay.isEmpty {
            let badges = [
                timeline.map { "\($0.entries.count) 个片段" },
                timeline.map { $0.source.badgeTitle },
                "本地优先"
            ].compactMap { $0 }

            return TodayInsightSummary(
                headline: "今天还没有形成你的个人总结",
                narrative: "先记下一次情绪、一个事件或一句备注，ToDay 才会从“发生了什么”开始过渡到“今天像什么”。",
                badges: badges
            )
        }

        var badges: [String] = ["\(recordsForDay.count) 条记录"]
        if noteCount > 0 {
            badges.append("\(noteCount) 条备注")
        }
        if let dominantMood {
            badges.append("主情绪 \(dominantMood.rawValue)")
        }
        if timelineEntryCount > 0 {
            badges.append("\(timelineEntryCount) 个片段")
        }

        let headline = dominantMood.map { "今天的主线偏向\($0.rawValue)" } ?? "今天开始出现自己的节奏"

        var narrativeParts = [moodNarrative(for: dominantMood)]

        if let latestNote {
            narrativeParts.append("你最近记下了“\(latestNote.note)”。")
        }

        if recordsForDay.count >= 3 {
            narrativeParts.append("今天的手动记录已经足够形成一条初步时间线。")
        } else {
            narrativeParts.append("再补几条记录，今天的总结会更像你真实过的一天。")
        }

        if timelineEntryCount > 0 {
            narrativeParts.append("系统时间线已经能和你的手动记录一起工作。")
        }

        return TodayInsightSummary(
            headline: headline,
            narrative: narrativeParts.joined(separator: " "),
            badges: badges
        )
    }

    private func buildRecentDigests() -> [RecentDayDigest] {
        let grouped = Dictionary(grouping: manualRecords) { calendar.startOfDay(for: $0.createdAt) }

        return grouped.keys
            .sorted(by: >)
            .prefix(7)
            .compactMap { date in
                guard let records = grouped[date] else { return nil }
                let dominantMood = dominantMood(in: records)
                let notesCount = records.filter { !$0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
                let title = dominantMood?.rawValue ?? "记录日"
                let detailParts = [
                    "\(records.count) 条记录",
                    notesCount > 0 ? "\(notesCount) 条备注" : nil,
                    dominantMood.map { "主情绪 \($0.rawValue)" }
                ].compactMap { $0 }

                return RecentDayDigest(
                    date: date,
                    title: title,
                    detail: detailParts.joined(separator: " · "),
                    mood: dominantMood
                )
            }
    }

    private func dominantMood(in records: [MoodRecord]) -> MoodRecord.Mood? {
        let counts = records.reduce(into: [MoodRecord.Mood: Int]()) { partialResult, record in
            partialResult[record.mood, default: 0] += 1
        }

        return counts.max { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key.rawValue > rhs.key.rawValue
            }
            return lhs.value < rhs.value
        }?.key
    }

    private func moodNarrative(for mood: MoodRecord.Mood?) -> String {
        switch mood {
        case .happy:
            return "今天整体偏轻快，值得记住那些让状态变好的片段。"
        case .calm:
            return "今天更像是平稳推进的一天，节奏相对柔和。"
        case .tired:
            return "今天像是在低电量下推进，最好给自己留出恢复空间。"
        case .irritated:
            return "今天的情绪里有些摩擦感，回看触发点会比硬扛更有价值。"
        case .focused:
            return "今天有一条比较明确的专注主线，适合回看哪段时间最顺。"
        case .zoning:
            return "今天更像在缓慢漂浮，可能需要更轻一点的记录方式。"
        case .none:
            return "今天已经开始积累一些片段，但还没有形成明确主情绪。"
        }
    }

    private func persistRecords() {
        do {
            try recordStore.saveRecords(manualRecords)
        } catch {
            errorMessage = "本地记录保存失败：\(error.localizedDescription)"
        }
    }
}
