import Foundation

/// Persists user annotations for inferred events in shared UserDefaults.
final class AnnotationStore {
    private var annotations: [UUID: StoredAnnotation] = [:]
    private let calendar: Calendar
    private static let storageKey = "today.eventAnnotations"

    init(calendar: Calendar = .current) {
        self.calendar = calendar
        load()
    }

    // MARK: - Queries

    func annotation(for eventID: UUID) -> StoredAnnotation? {
        annotations[eventID]
    }

    func annotations(on date: Date) -> [StoredAnnotation] {
        annotations.values
            .filter { calendar.isDate($0.startDate, inSameDayAs: date) }
            .sorted { $0.startDate < $1.startDate }
    }

    // MARK: - Mutations

    func annotate(_ event: InferredEvent, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        annotations[event.id] = StoredAnnotation(
            id: event.id,
            startDate: event.startDate,
            endDate: event.endDate,
            title: trimmed
        )
        persist()
    }

    // MARK: - Private

    private func load() {
        let shared = UserDefaults(suiteName: SharedAppGroup.identifier) ?? .standard
        let standard = UserDefaults.standard

        // Migrate legacy data from standard → shared defaults
        if shared.data(forKey: Self.storageKey) == nil,
           let legacyData = standard.data(forKey: Self.storageKey) {
            shared.set(legacyData, forKey: Self.storageKey)
            standard.removeObject(forKey: Self.storageKey)
        }

        guard let data = shared.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([StoredAnnotation].self, from: data) else {
            annotations = [:]
            return
        }

        annotations = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
    }

    private func persist() {
        let sorted = annotations.values.sorted { $0.startDate < $1.startDate }
        guard let data = try? JSONEncoder().encode(sorted) else { return }
        let shared = UserDefaults(suiteName: SharedAppGroup.identifier) ?? .standard
        shared.set(data, forKey: Self.storageKey)
    }
}

// MARK: - StoredAnnotation

struct StoredAnnotation: Codable, Hashable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let title: String

    var asEvent: InferredEvent {
        InferredEvent(
            id: id,
            kind: .userAnnotated,
            startDate: startDate,
            endDate: endDate,
            confidence: .high,
            displayName: title,
            userAnnotation: title,
            subtitle: "你补上了这段时间的名字。"
        )
    }
}
