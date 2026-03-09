import Foundation

enum AppContainer {
    @MainActor
    static func makeTodayViewModel() -> TodayViewModel {
        TodayViewModel(provider: makeTimelineProvider())
    }

    static func makeTimelineProvider() -> any TimelineDataProviding {
        let environment = ProcessInfo.processInfo.environment

        if environment["TODAY_USE_HEALTHKIT"] == "1" {
            return HealthKitTimelineDataProvider()
        }

        return MockTimelineDataProvider()
    }
}
