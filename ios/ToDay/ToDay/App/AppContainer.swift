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
    private static let screenTimeRecordStore = SwiftDataScreenTimeRecordStore(container: modelContainer)
    private static let echoItemStore = SwiftDataEchoItemStore(container: modelContainer)
    // MARK: - Sensor Infrastructure
    private static let sensorDataStore = SensorDataStore(container: modelContainer)
    private static let placeManager = PlaceManager()
    private static let phoneInferenceEngine = PhoneInferenceEngine()
    private static let deviceStateCollector = DeviceStateCollector(store: sensorDataStore)
    private static let locationCollector = LocationCollector(store: sensorDataStore)
    // MARK: - Echo AI Infrastructure
    private static let echoAIService = EchoAIService()
    private static let echoMemoryManager = EchoMemoryManager(container: modelContainer)
    private static let echoPromptBuilder = EchoPromptBuilder(memoryManager: echoMemoryManager)
    private static let echoDailySummaryGenerator = EchoDailySummaryGenerator(
        aiService: echoAIService,
        memoryManager: echoMemoryManager,
        promptBuilder: echoPromptBuilder
    )
    private static let echoWeeklyProfileUpdater = EchoWeeklyProfileUpdater(
        aiService: echoAIService,
        memoryManager: echoMemoryManager,
        promptBuilder: echoPromptBuilder
    )
    private static let echoScheduler = EchoScheduler(
        dailySummaryGenerator: echoDailySummaryGenerator,
        weeklyProfileUpdater: echoWeeklyProfileUpdater,
        memoryManager: echoMemoryManager
    )
    private static let echoMessageStore = SwiftDataEchoMessageStore(container: modelContainer)
#if os(iOS)
    static let phoneConnectivityManager = makePhoneConnectivityManager()
#endif

    @MainActor
    static func makeTodayViewModel() -> TodayViewModel {
        let viewModel = TodayViewModel(
            provider: makeTimelineProvider(),
            recordStore: makeMoodRecordStore(),
            shutterRecordStore: makeShutterRecordStore(),
            spendingRecordStore: makeSpendingRecordStore(),
            screenTimeRecordStore: makeScreenTimeRecordStore(),
            echoEngine: echoEngine,
            phoneConnectivityManager: phoneConnectivityManager,
            modelContainer: modelContainer
        )
        phoneConnectivityManager.bind(todayViewModel: viewModel)
        return viewModel
    }

    static func availableCollectors() -> [any SensorCollecting] {
        var collectors: [any SensorCollecting] = [
            MotionCollector(),
            PedometerCollector(),
            deviceStateCollector,
            locationCollector,
        ]
        let hkCollector = HealthKitCollector()
        if hkCollector.isAvailable {
            collectors.append(hkCollector)
        }
        return collectors
    }

    static func getDeviceStateCollector() -> DeviceStateCollector { deviceStateCollector }
    static func getLocationCollector() -> LocationCollector { locationCollector }
    static func getSensorDataStore() -> SensorDataStore { sensorDataStore }

    static func makeTimelineProvider() -> any TimelineDataProviding {
        let environment = ProcessInfo.processInfo.environment
        if environment["TODAY_USE_MOCK"] == "1" {
            return MockTimelineDataProvider()
        }

        #if targetEnvironment(simulator)
        return MockTimelineDataProvider()
        #else
        return PhoneTimelineDataProvider(
            collectors: availableCollectors(),
            store: sensorDataStore,
            inferenceEngine: phoneInferenceEngine,
            placeManager: placeManager
        )
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

    static func makeScreenTimeRecordStore() -> any ScreenTimeRecordStoring {
        screenTimeRecordStore
    }

    static func makeEchoItemStore() -> any EchoItemStoring {
        echoItemStore
    }

    @MainActor
    private static let echoEngine = EchoEngine(
        echoStore: echoItemStore,
        shutterRecordStore: shutterRecordStore
    )

    @MainActor
    static func makeEchoViewModel() -> EchoViewModel {
        EchoViewModel(
            echoEngine: echoEngine,
            shutterRecordStore: makeShutterRecordStore(),
            screenTimeStore: makeScreenTimeRecordStore()
        )
    }

    @MainActor
    static func makeEchoChatViewModel() -> EchoChatViewModel {
        EchoChatViewModel(
            aiService: echoAIService,
            memoryManager: echoMemoryManager,
            promptBuilder: echoPromptBuilder,
            container: modelContainer
        )
    }

    @MainActor
    static func getEchoEngine() -> EchoEngine {
        echoEngine
    }

    static func getEchoAIService() -> EchoAIService {
        echoAIService
    }

    static func getEchoMemoryManager() -> EchoMemoryManager {
        echoMemoryManager
    }

    static func getEchoPromptBuilder() -> EchoPromptBuilder {
        echoPromptBuilder
    }

    static func getEchoDailySummaryGenerator() -> EchoDailySummaryGenerator {
        echoDailySummaryGenerator
    }

    static func getEchoWeeklyProfileUpdater() -> EchoWeeklyProfileUpdater {
        echoWeeklyProfileUpdater
    }

    static func getEchoScheduler() -> EchoScheduler {
        echoScheduler
    }

    @MainActor
    static let echoMessageManager: EchoMessageManager = {
        let manager = EchoMessageManager(store: echoMessageStore, container: modelContainer)
        echoScheduler.setMessageManager(manager)
        return manager
    }()

    @MainActor
    static func getEchoMessageManager() -> EchoMessageManager {
        echoMessageManager
    }

    @MainActor
    static func makeEchoThreadViewModel(for message: EchoMessageEntity) -> EchoThreadViewModel {
        EchoThreadViewModel(
            threadId: message.threadId,
            sourceData: message.sourceData,
            messageType: message.messageType,
            sourceDescription: message.sourceData?.sourceDescription ?? "",
            aiService: echoAIService,
            memoryManager: echoMemoryManager,
            promptBuilder: echoPromptBuilder,
            container: modelContainer
        )
    }

    private static func makeModelContainer() -> ModelContainer {
        do {
            let container = try ModelContainer(
                for: MoodRecordEntity.self,
                DayTimelineEntity.self,
                ShutterRecordEntity.self,
                SpendingRecordEntity.self,
                ScreenTimeRecordEntity.self,
                EchoItemEntity.self,
                UserProfileEntity.self,
                DailySummaryEntity.self,
                ConversationMemoryEntity.self,
                EchoChatSessionEntity.self,
                EchoChatMessageEntity.self,
                EchoMessageEntity.self,
                SensorReadingEntity.self,
                CustomMoodEntity.self
            )
            migrateLegacyMoodRecordsIfNeeded(into: container)
            let context = ModelContext(container)
            CustomMoodEntity.seedDefaultsIfNeeded(in: context)
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
