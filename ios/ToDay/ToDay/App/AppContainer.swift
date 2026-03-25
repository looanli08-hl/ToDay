import Foundation
import HealthKit
import SwiftData
#if os(iOS)
import WatchConnectivity
#endif

enum AppContainer {
    static let modelContainer = makeModelContainer()
    private static let legacyMoodRecordStoreKey = "today.manualRecords"
    private static let moodRecordStore = SwiftDataMoodRecordStore(container: modelContainer)
    private static let shutterRecordStore = SwiftDataShutterRecordStore(container: modelContainer)
    private static let spendingRecordStore = SwiftDataSpendingRecordStore(container: modelContainer)
#if os(iOS)
    static let phoneConnectivityManager = makePhoneConnectivityManager()
#endif

    @MainActor
    static func makeTodayViewModel() -> TodayViewModel {
        let viewModel = TodayViewModel(
            provider: makeTimelineProvider(),
            recordStore: makeMoodRecordStore(),
            phoneConnectivityManager: phoneConnectivityManager,
            modelContainer: modelContainer
        )
        phoneConnectivityManager.bind(todayViewModel: viewModel)
        return viewModel
    }

    static func makeTimelineProvider() -> any TimelineDataProviding {
        let environment = ProcessInfo.processInfo.environment
        if environment["TODAY_USE_MOCK"] == "1" {
            return MockTimelineDataProvider()
        }

        #if targetEnvironment(simulator)
        return MockTimelineDataProvider()
        #else
        if HKHealthStore.isHealthDataAvailable() {
            return HealthKitTimelineDataProvider()
        }
        return MockTimelineDataProvider()
        #endif
    }

    static func makeMoodRecordStore() -> any MoodRecordStoring {
        moodRecordStore
    }

    static func makeShutterRecordStore() -> any ShutterRecordStoring {
        shutterRecordStore
    }

    static func makeSpendingRecordStore() -> any SpendingRecordStoring {
        spendingRecordStore
    }

    private static func makeModelContainer() -> ModelContainer {
        do {
            let container = try ModelContainer(
                for: MoodRecordEntity.self,
                DayTimelineEntity.self,
                ShutterRecordEntity.self,
                SpendingRecordEntity.self
            )
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

#if os(iOS)
    private static func makePhoneConnectivityManager() -> PhoneConnectivityManager {
        let manager = PhoneConnectivityManager.shared
        manager.configure(recordStore: moodRecordStore)
        return manager
    }
#endif
}
