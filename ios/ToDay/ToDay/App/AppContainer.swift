import Foundation

enum AppContainer {
    @MainActor
    static func makeTodayViewModel() -> TodayViewModel {
        TodayViewModel(
            provider: makeTimelineProvider(),
            recordStore: makeMoodRecordStore()
        )
    }

    static func makeTimelineProvider() -> any TimelineDataProviding {
        let environment = ProcessInfo.processInfo.environment

        if environment["TODAY_USE_HEALTHKIT"] == "1" {
            return HealthKitTimelineDataProvider()
        }

        return MockTimelineDataProvider()
    }

    static func makeMoodRecordStore() -> any MoodRecordStoring {
        UserDefaultsMoodRecordStore()
    }
}
