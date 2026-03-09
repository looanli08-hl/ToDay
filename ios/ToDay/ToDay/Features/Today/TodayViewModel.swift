import Foundation

@MainActor
final class TodayViewModel: ObservableObject {
    @Published private(set) var timeline: DayTimeline?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var showQuickRecord = false

    private let provider: any TimelineDataProviding
    private var hasLoadedOnce = false
    private(set) var manualRecords: [MoodRecord] = []

    init(provider: any TimelineDataProviding) {
        self.provider = provider
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

        do {
            let base = try await provider.loadTimeline(for: Date())
            timeline = mergedTimeline(base: base)
            hasLoadedOnce = true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        isLoading = false
    }

    func addMoodRecord(_ record: MoodRecord) {
        manualRecords.insert(record, at: 0)
        if let base = timeline {
            timeline = mergedTimeline(base: base)
        }
    }

    private func mergedTimeline(base: DayTimeline) -> DayTimeline {
        let manualEntries = manualRecords.map { $0.toTimelineEntry() }
        return DayTimeline(
            date: base.date,
            summary: base.summary,
            source: base.source,
            stats: base.stats,
            entries: manualEntries + base.entries
        )
    }
}
