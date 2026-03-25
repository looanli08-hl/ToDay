import SwiftData
import XCTest
@testable import ToDay

@MainActor
final class TimelineMergeTests: XCTestCase {
    func testSpendingRecordsMergedIntoTimeline() async throws {
        let vm = makeViewModel()
        await vm.load(forceReload: true)

        // Count mock spending events already in the timeline
        let baseSpendingCount = vm.timeline?.entries.filter { $0.kind == .spending }.count ?? 0

        // Add a spending record
        let record = SpendingRecord(amount: 35, category: .food, note: "午餐")
        vm.addSpendingRecord(record)

        // Timeline should contain the new spending event plus any mock ones
        let spendingEvents = vm.timeline?.entries.filter { $0.kind == .spending } ?? []
        XCTAssertEqual(spendingEvents.count, baseSpendingCount + 1)
        XCTAssertTrue(spendingEvents.contains(where: { $0.displayName.contains("¥35") }))
    }

    func testScreenTimeRecordMergedIntoTimeline() async throws {
        let vm = makeViewModel()
        await vm.load(forceReload: true)

        // Count mock screen time events already in the timeline
        let baseScreenTimeCount = vm.timeline?.entries.filter { $0.kind == .screenTime }.count ?? 0

        // Add a screen time record
        let dateKey = Self.dateKeyFormatter.string(from: Date())
        let record = ScreenTimeRecord(
            dateKey: dateKey,
            totalScreenTime: 5400,
            appUsages: [
                AppUsage(appName: "Safari", category: "浏览", duration: 3600)
            ],
            pickupCount: 20
        )
        vm.saveScreenTimeRecord(record)

        // Timeline should contain the new screen time event plus any mock ones
        let screenTimeEvents = vm.timeline?.entries.filter { $0.kind == .screenTime } ?? []
        XCTAssertGreaterThanOrEqual(screenTimeEvents.count, baseScreenTimeCount + 1)
        XCTAssertTrue(screenTimeEvents.contains(where: { $0.displayName.contains("1h 30m") }))
    }

    func testSpendingRecordRemoval() async throws {
        let vm = makeViewModel()
        await vm.load(forceReload: true)

        let record = SpendingRecord(amount: 50, category: .shopping)
        vm.addSpendingRecord(record)

        XCTAssertFalse(vm.spendingRecords(forCurrentDay: true).isEmpty)

        vm.removeSpendingRecord(id: record.id)

        XCTAssertTrue(vm.spendingRecords(forCurrentDay: true).isEmpty)
    }

    // MARK: - Helpers

    private static let dateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private func makeViewModel() -> TodayViewModel {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: MoodRecordEntity.self,
            DayTimelineEntity.self,
            ShutterRecordEntity.self,
            SpendingRecordEntity.self,
            ScreenTimeRecordEntity.self,
            configurations: config
        )
        let moodStore = SwiftDataMoodRecordStore(container: container)
        let spendingStore = SwiftDataSpendingRecordStore(container: container)
        let screenTimeStore = SwiftDataScreenTimeRecordStore(container: container)

        return TodayViewModel(
            provider: MockTimelineDataProvider(),
            recordStore: moodStore,
            spendingRecordStore: spendingStore,
            screenTimeRecordStore: screenTimeStore,
            modelContainer: container
        )
    }
}
