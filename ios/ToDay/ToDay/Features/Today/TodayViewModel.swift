import Foundation

struct TodayInsightSummary {
    let headline: String
    let narrative: String
    let badges: [String]
}

struct WeeklyInsightSummary {
    let headline: String
    let narrative: String
    let badges: [String]
}

struct RecentDayDigest: Identifiable {
    let date: Date
    let title: String
    let detail: String
    let mood: MoodRecord.Mood?
    let notePreview: String?
    let recordCount: Int

    var id: Date { date }
}

@MainActor
final class TodayViewModel: ObservableObject {
    @Published private(set) var timeline: DayTimeline?
    @Published private(set) var insightSummary: TodayInsightSummary?
    @Published private(set) var weeklyInsight: WeeklyInsightSummary?
    @Published private(set) var recentDigests: [RecentDayDigest] = []
    @Published private(set) var historyDigests: [RecentDayDigest] = []
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
        let recordsForDay = records(on: base.date)
        let manualEntries = recordsForDay.map { $0.toTimelineEntry() }
        let notesCount = recordsForDay.filter(hasNote).count

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
        historyDigests = buildHistoryDigests(limit: 21)
        recentDigests = Array(historyDigests.prefix(7))
        insightSummary = buildInsightSummary(referenceDate: referenceDate)
        weeklyInsight = buildWeeklyInsight(referenceDate: referenceDate)
    }

    private func buildInsightSummary(referenceDate: Date) -> TodayInsightSummary {
        let recordsForDay = records(on: referenceDate)
        let dominantMood = dominantMood(in: recordsForDay)
        let noteCount = recordsForDay.filter(hasNote).count
        let latestNote = recordsForDay.first(where: hasNote)
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

    private func buildWeeklyInsight(referenceDate: Date) -> WeeklyInsightSummary {
        let referenceDay = calendar.startOfDay(for: referenceDate)
        let startDay = calendar.date(byAdding: .day, value: -6, to: referenceDay) ?? referenceDay
        let records = manualRecords.filter { $0.createdAt >= startDay }
        let grouped = Dictionary(grouping: records) { calendar.startOfDay(for: $0.createdAt) }
        let activeDays = grouped.count
        let totalRecords = records.count
        let dominantMood = dominantMood(in: records)
        let streak = currentStreak(referenceDay: referenceDay, groupedDays: Set(grouped.keys))
        let dominantPeriod = dominantRecordingPeriod(in: records)

        if totalRecords == 0 {
            return WeeklyInsightSummary(
                headline: "连续洞察会从最近 7 天开始长出来",
                narrative: "当你开始持续记录，ToDay 会逐渐告诉你最近一周更像在恢复、推进、拉扯还是漂浮。",
                badges: ["0/7 活跃天", "等待记录", "Pro 适合长期回看"]
            )
        }

        var badges = ["\(activeDays)/7 活跃天", "\(totalRecords) 条记录"]
        if streak > 0 {
            badges.append("连续 \(streak) 天")
        }
        if let dominantMood {
            badges.append("主情绪 \(dominantMood.rawValue)")
        }
        if let dominantPeriod {
            badges.append("高峰在\(dominantPeriod)")
        }

        let headline: String
        switch dominantMood {
        case .happy:
            headline = "最近 7 天更像在往上抬"
        case .calm:
            headline = "最近 7 天偏平稳推进"
        case .tired:
            headline = "最近 7 天更需要恢复"
        case .irritated:
            headline = "最近 7 天有些拉扯感"
        case .focused:
            headline = "最近 7 天存在明显推进段"
        case .zoning:
            headline = "最近 7 天像在缓慢漂浮"
        case .none:
            headline = "最近 7 天已经开始形成自己的节奏"
        }

        let periodText = dominantPeriod.map { "记录更多发生在\($0)。" } ?? "记录时间还没有形成稳定偏好。"
        let streakText = streak > 1 ? "你已经连续 \(streak) 天留下痕迹。" : "当前还处在轻量记录阶段。"
        let activityText = "最近 7 天里有 \(activeDays) 天留下记录，总共 \(totalRecords) 条。"

        return WeeklyInsightSummary(
            headline: headline,
            narrative: [activityText, streakText, periodText].joined(separator: " "),
            badges: badges
        )
    }

    private func buildHistoryDigests(limit: Int) -> [RecentDayDigest] {
        let grouped = Dictionary(grouping: manualRecords) { calendar.startOfDay(for: $0.createdAt) }

        return grouped.keys
            .sorted(by: >)
            .prefix(limit)
            .compactMap { date in
                guard let records = grouped[date] else { return nil }
                let sortedRecords = records.sorted { $0.createdAt > $1.createdAt }
                let dominantMood = dominantMood(in: sortedRecords)
                let notesCount = sortedRecords.filter(hasNote).count
                let title = dominantMood?.rawValue ?? "记录日"
                let detailParts = [
                    "\(sortedRecords.count) 条记录",
                    notesCount > 0 ? "\(notesCount) 条备注" : nil,
                    dominantMood.map { "主情绪 \($0.rawValue)" }
                ].compactMap { $0 }
                let notePreview = sortedRecords.first(where: hasNote)?.note

                return RecentDayDigest(
                    date: date,
                    title: title,
                    detail: detailParts.joined(separator: " · "),
                    mood: dominantMood,
                    notePreview: notePreview,
                    recordCount: sortedRecords.count
                )
            }
    }

    private func records(on date: Date) -> [MoodRecord] {
        manualRecords
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .sorted { $0.createdAt > $1.createdAt }
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

    private func dominantRecordingPeriod(in records: [MoodRecord]) -> String? {
        let counts = records.reduce(into: [String: Int]()) { partialResult, record in
            let hour = calendar.component(.hour, from: record.createdAt)
            let label: String

            switch hour {
            case 5..<12:
                label = "上午"
            case 12..<18:
                label = "白天"
            default:
                label = "晚上"
            }

            partialResult[label, default: 0] += 1
        }

        return counts.max(by: { $0.value < $1.value })?.key
    }

    private func currentStreak(referenceDay: Date, groupedDays: Set<Date>) -> Int {
        var streak = 0
        var cursor = referenceDay

        while groupedDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        return streak
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

    private func hasNote(_ record: MoodRecord) -> Bool {
        !record.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func persistRecords() {
        do {
            try recordStore.saveRecords(manualRecords)
        } catch {
            errorMessage = "本地记录保存失败：\(error.localizedDescription)"
        }
    }
}
