import Foundation

extension MoodRecord {
    func displayTimeLabel(referenceDate: Date = Date(), calendar: Calendar = .current) -> String {
        let startLabel = Self.clockFormatter.string(from: createdAt)
        let resolvedEndDate = displayEndDate(referenceDate: referenceDate, calendar: calendar)

        if isOngoing {
            return "\(startLabel) - 现在"
        }

        guard captureMode == .session else { return startLabel }

        let endLabel = Self.clockFormatter.string(from: resolvedEndDate)
        return startLabel == endLabel ? "\(startLabel) - \(endLabel)" : "\(startLabel) - \(endLabel)"
    }

    func toInferredEvent(referenceDate: Date = Date(), calendar: Calendar = .current) -> InferredEvent {
        let resolvedEndDate = displayEndDate(referenceDate: referenceDate, calendar: calendar)
        let boundedEndDate: Date

        if isOngoing {
            boundedEndDate = max(resolvedEndDate, createdAt.addingTimeInterval(60))
        } else if captureMode == .session {
            boundedEndDate = max(resolvedEndDate, createdAt.addingTimeInterval(60))
        } else {
            boundedEndDate = createdAt
        }

        return InferredEvent(
            id: id,
            kind: .mood,
            startDate: createdAt,
            endDate: boundedEndDate,
            confidence: .high,
            isLive: isOngoing,
            displayName: mood.rawValue,
            subtitle: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note,
            photoAttachments: photoAttachments
        )
    }

    private static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
