import Foundation
import SwiftData

enum AppContainer {
    static let modelContainer = makeModelContainer()
    private static let legacyMoodRecordStoreKey = "today.manualRecords"

    @MainActor
    static func makeTodayViewModel() -> TodayViewModel {
        TodayViewModel(
            provider: makeTimelineProvider(),
            recordStore: makeMoodRecordStore()
        )
    }

    @MainActor
    static func makeMonetizationViewModel() -> MonetizationViewModel {
        MonetizationViewModel()
    }

    static func makeTimelineProvider() -> any TimelineDataProviding {
        let environment = ProcessInfo.processInfo.environment

        if environment["TODAY_USE_HEALTHKIT"] == "1" {
            return HealthKitTimelineDataProvider()
        }

        return MockTimelineDataProvider()
    }

    static func makeMoodRecordStore() -> any MoodRecordStoring {
        SwiftDataMoodRecordStore(container: modelContainer)
    }

    private static func makeModelContainer() -> ModelContainer {
        do {
            let container = try ModelContainer(for: MoodRecordEntity.self)
            migrateLegacyMoodRecordsIfNeeded(into: container)
            return container
        } catch {
            fatalError("无法创建 MoodRecord SwiftData 容器：\(error.localizedDescription)")
        }
    }

    private static func migrateLegacyMoodRecordsIfNeeded(into container: ModelContainer) {
        let defaults = UserDefaults.standard
        guard defaults.data(forKey: legacyMoodRecordStoreKey) != nil else { return }

        let legacyStore = UserDefaultsMoodRecordStore(defaults: defaults, key: legacyMoodRecordStoreKey)
        let legacyRecords = legacyStore.loadRecords()

        guard !legacyRecords.isEmpty else {
            defaults.removeObject(forKey: legacyMoodRecordStoreKey)
            return
        }

        do {
            try SwiftDataMoodRecordStore(container: container).saveRecords(legacyRecords)
            defaults.removeObject(forKey: legacyMoodRecordStoreKey)
        } catch {
            assertionFailure("迁移旧版 MoodRecord 数据失败：\(error.localizedDescription)")
        }
    }
}
