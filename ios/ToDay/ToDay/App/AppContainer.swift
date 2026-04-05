import Foundation
import SwiftData

/// Composition root — wires all dependencies for the Unfold app.
/// Uses enum with static properties for singleton services,
/// and factory methods for per-screen ViewModels.
enum AppContainer {

    // MARK: - Model Container

    static let modelContainer: ModelContainer = {
        let schema = Schema([
            SensorReadingEntity.self,
            MoodRecordEntity.self,
            ShutterRecordEntity.self,
            DayTimelineEntity.self,
            CustomMoodEntity.self,
            EchoMessageEntity.self,
            EchoChatSessionEntity.self,
            EchoChatMessageEntity.self,
            UserProfileEntity.self,
            DailySummaryEntity.self,
            ConversationMemoryEntity.self,
        ])

        let config = ModelConfiguration(
            "Unfold",
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            // Seed default custom moods
            let context = ModelContext(container)
            CustomMoodEntity.seedDefaultsIfNeeded(in: context)
            return container
        } catch {
            fatalError("Unable to create ModelContainer: \(error.localizedDescription)")
        }
    }()

    // MARK: - Sensor Infrastructure

    private static let _sensorDataStore = SensorDataStore(container: modelContainer)

    static func getSensorDataStore() -> SensorDataStore {
        _sensorDataStore
    }

    private static let _placeManager = PlaceManager()

    static func getPlaceManager() -> PlaceManager {
        _placeManager
    }

    private static let _phoneInferenceEngine = PhoneInferenceEngine()

    // MARK: - Collectors

    private static let _locationCollector = LocationCollector(store: _sensorDataStore)
    private static let _deviceStateCollector = DeviceStateCollector(store: _sensorDataStore)
    private static let _motionCollector = MotionCollector()
    private static let _pedometerCollector = PedometerCollector()

    static func getLocationCollector() -> LocationCollector {
        _locationCollector
    }

    static func getDeviceStateCollector() -> DeviceStateCollector {
        _deviceStateCollector
    }

    // MARK: - AI Services

    private static let _echoAIService = EchoAIService()

    static func getEchoAIService() -> EchoAIService {
        _echoAIService
    }

    private static let _echoMemoryManager = EchoMemoryManager(container: modelContainer)

    static func getEchoMemoryManager() -> EchoMemoryManager {
        _echoMemoryManager
    }

    private static let _echoPromptBuilder = EchoPromptBuilder(
        memoryManager: _echoMemoryManager,
        timelineContainer: modelContainer
    )

    static func getEchoPromptBuilder() -> EchoPromptBuilder {
        _echoPromptBuilder
    }

    private static let _echoMessageStore = SwiftDataEchoMessageStore(container: modelContainer)

    @MainActor
    private static var _echoMessageManager: EchoMessageManager?

    @MainActor
    static func getEchoMessageManager() -> EchoMessageManager {
        if let existing = _echoMessageManager { return existing }
        let manager = EchoMessageManager(store: _echoMessageStore, container: modelContainer)
        _echoMessageManager = manager
        return manager
    }

    // MARK: - Echo Scheduler

    private static let _echoDailySummaryGenerator = EchoDailySummaryGenerator(
        aiService: _echoAIService,
        memoryManager: _echoMemoryManager,
        promptBuilder: _echoPromptBuilder
    )

    private static let _echoWeeklyProfileUpdater = EchoWeeklyProfileUpdater(
        aiService: _echoAIService,
        memoryManager: _echoMemoryManager,
        promptBuilder: _echoPromptBuilder
    )

    static let echoScheduler = EchoScheduler(
        dailySummaryGenerator: _echoDailySummaryGenerator,
        weeklyProfileUpdater: _echoWeeklyProfileUpdater,
        memoryManager: _echoMemoryManager,
        aiService: _echoAIService,
        promptBuilder: _echoPromptBuilder
    )

    // MARK: - Pattern Detection

    static let patternDetectionEngine = PatternDetectionEngine()

    // MARK: - Timeline Provider

    static func makeTimelineProvider() -> any TimelineDataProviding {
        #if targetEnvironment(simulator)
        return MockTimelineDataProvider()
        #else
        if ProcessInfo.processInfo.environment["TODAY_USE_MOCK"] == "1" {
            return MockTimelineDataProvider()
        }
        return PhoneTimelineDataProvider(
            collectors: [_locationCollector, _deviceStateCollector, _motionCollector, _pedometerCollector],
            store: _sensorDataStore,
            inferenceEngine: _phoneInferenceEngine,
            placeManager: _placeManager
        )
        #endif
    }

    // MARK: - Record Stores

    private static let _moodRecordStore = SwiftDataMoodRecordStore(container: modelContainer)
    private static let _shutterRecordStore = SwiftDataShutterRecordStore(container: modelContainer)
    private static let _annotationStore = AnnotationStore()

    @MainActor
    static func makeMoodRecordManager() -> MoodRecordManager {
        MoodRecordManager(recordStore: _moodRecordStore)
    }

    @MainActor
    static func makeShutterManager() -> ShutterManager {
        ShutterManager(recordStore: _shutterRecordStore)
    }

    static func makeAnnotationStore() -> AnnotationStore {
        _annotationStore
    }

    static func getEchoScheduler() -> EchoScheduler {
        echoScheduler
    }

    // MARK: - ViewModel Factories

    @MainActor
    static func makeTodayViewModel() -> TodayViewModel {
        TodayViewModel(
            timelineProvider: makeTimelineProvider(),
            moodRecordManager: makeMoodRecordManager(),
            shutterManager: makeShutterManager(),
            annotationStore: makeAnnotationStore(),
            echoMessageManager: getEchoMessageManager()
        )
    }

    // MARK: - App Lifecycle

    @MainActor
    static func startSensors() {
        _locationCollector.startMonitoring()
        _deviceStateCollector.startMonitoring()
    }

    @MainActor
    static func wireEchoScheduler() {
        echoScheduler.setMessageManager(getEchoMessageManager())
    }
}
