import Foundation

extension MoodRecord.Mood {
    var timelineKind: TimelineEntry.Kind {
        switch self {
        case .happy, .calm:
            return .mood
        case .tired, .zoning:
            return .pause
        case .irritated:
            return .mood
        case .focused:
            return .focus
        }
    }
}

extension MoodRecord {
    func displayTimeLabel(referenceDate: Date = Date(), calendar: Calendar = .current) -> String {
        toTimelineEntry(referenceDate: referenceDate, calendar: calendar).moment.label
    }

    func toTimelineEntry(referenceDate: Date = Date(), calendar: Calendar = .current) -> TimelineEntry {
        let resolvedEndDate = displayEndDate(referenceDate: referenceDate, calendar: calendar)
        let durationMinutes = max(Int(resolvedEndDate.timeIntervalSince(createdAt) / 60), 1)
        let detailPrefix = note.isEmpty
            ? "\(mood.emoji) \(mood.rawValue)"
            : "\(mood.emoji) \(mood.rawValue) · \(note)"

        let detail: String
        if isOngoing {
            detail = "\(detailPrefix) · 正在进行，已持续 \(durationDescription(minutes: durationMinutes))"
        } else if captureMode == .session {
            detail = "\(detailPrefix) · 持续 \(durationDescription(minutes: durationMinutes))"
        } else {
            detail = detailPrefix
        }

        let startMinute = minuteOfDay(for: createdAt, calendar: calendar)
        let endMinute = minuteOfDay(for: resolvedEndDate, calendar: calendar)
        let boundedEndMinute = max(endMinute, startMinute + 1)
        let moment: TimelineMoment

        if isOngoing {
            moment = .active(startMinuteOfDay: startMinute, currentMinuteOfDay: boundedEndMinute)
        } else if captureMode == .session {
            moment = .range(startMinuteOfDay: startMinute, endMinuteOfDay: boundedEndMinute)
        } else {
            moment = .point(at: startMinute)
        }

        return TimelineEntry(
            id: id.uuidString,
            title: mood.rawValue,
            detail: detail,
            moment: moment,
            kind: mood.timelineKind,
            durationMinutes: captureMode == .session || isOngoing ? durationMinutes : nil,
            isLive: isOngoing,
            photoAttachments: photoAttachments
        )
    }

    private func minuteOfDay(for date: Date, calendar: Calendar) -> Int {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return (hour * 60) + minute
    }

    private func durationDescription(minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let remainder = minutes % 60

            if remainder == 0 {
                return "\(hours) 小时"
            }

            return "\(hours) 小时 \(remainder) 分钟"
        }

        return "\(minutes) 分钟"
    }
}
