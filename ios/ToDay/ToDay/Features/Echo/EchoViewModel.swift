import Foundation
import SwiftData

@MainActor
final class EchoViewModel: ObservableObject {
    // MARK: - Published State

    @Published private(set) var todayEchoes: [EchoItem] = []
    @Published private(set) var historyEchoes: [EchoItem] = []
    @Published private(set) var isLoading = false
    @Published var selectedEchoItem: EchoItem?

    // MARK: - Dependencies

    private let echoEngine: EchoEngine
    private let shutterRecordStore: any ShutterRecordStoring

    // Store a reference to load shutter records for display
    private var shutterRecordCache: [UUID: ShutterRecord] = [:]

    init(
        echoEngine: EchoEngine,
        shutterRecordStore: any ShutterRecordStoring
    ) {
        self.echoEngine = echoEngine
        self.shutterRecordStore = shutterRecordStore
    }

    // MARK: - Loading

    func load(recentTimelines: [DayTimeline] = []) {
        isLoading = true

        // Load today's echoes
        todayEchoes = echoEngine.todayEchoes()

        // Load history
        historyEchoes = echoEngine.echoHistory(limit: 30)

        // Cache shutter records for display
        let allRecords = shutterRecordStore.loadAll()
        shutterRecordCache = Dictionary(uniqueKeysWithValues: allRecords.map { ($0.id, $0) })

        isLoading = false
    }

    // MARK: - Actions

    func markAsViewed(_ echoItem: EchoItem) {
        echoEngine.markAsViewed(echoID: echoItem.id)
        todayEchoes = echoEngine.todayEchoes()
        historyEchoes = echoEngine.echoHistory(limit: 30)
    }

    func dismiss(_ echoItem: EchoItem) {
        echoEngine.dismiss(echoID: echoItem.id)
        todayEchoes = echoEngine.todayEchoes()
    }

    func snooze(_ echoItem: EchoItem) {
        echoEngine.snooze(echoID: echoItem.id)
        todayEchoes = echoEngine.todayEchoes()
    }

    // MARK: - Data Lookup

    /// Get the ShutterRecord for an echo item
    func shutterRecord(for echoItem: EchoItem) -> ShutterRecord? {
        shutterRecordCache[echoItem.shutterRecordID]
    }

    // MARK: - Echo Settings (Passthrough)

    var echoHour: Int {
        get { echoEngine.echoHour }
        set {
            echoEngine.echoHour = newValue
            objectWillChange.send()
        }
    }

    var globalFrequency: EchoFrequency? {
        get { echoEngine.globalFrequency }
        set {
            echoEngine.globalFrequency = newValue
            objectWillChange.send()
        }
    }
}
