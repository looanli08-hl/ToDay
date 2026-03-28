import CoreLocation
import Foundation

/// Converts raw sensor readings into timeline events by cross-referencing
/// motion, location, device state, and pedometer data.
final class PhoneInferenceEngine {

    // MARK: - Constants

    private enum Threshold {
        static let sleepMinGapHours: TimeInterval = 2 * 3600          // 2 hours
        static let napMinGapMinutes: TimeInterval = 40 * 60           // 40 minutes
        static let commuteMinDuration: TimeInterval = 2 * 60          // 2 minutes
        static let walkMinDurationForActiveWalk: TimeInterval = 10 * 60 // 10 minutes
        static let walkMinDuration: TimeInterval = 1 * 60             // 1 minute
        static let visitMinStay: TimeInterval = 5 * 60                // 5 minutes
        static let blankMinDuration: TimeInterval = 15 * 60           // 15 minutes
        static let mergeGap: TimeInterval = 3 * 60                    // 3 minutes
        static let placeMatchRadius: Double = 200                     // metres
    }

    // MARK: - Public API

    func inferEvents(
        from readings: [SensorReading],
        on date: Date,
        places: [KnownPlace]
    ) -> [InferredEvent] {
        let sorted = readings.sorted { $0.timestamp < $1.timestamp }
        var coveredIntervals: [DateInterval] = []
        var events: [InferredEvent] = []

        // Priority 1: Sleep
        let sleepEvents = inferSleep(from: sorted)
        for event in sleepEvents {
            events.append(event)
            coveredIntervals.append(DateInterval(start: event.startDate, end: event.endDate))
        }

        // Priority 2: Commute
        let commuteEvents = inferCommute(from: sorted, places: places, covered: coveredIntervals)
        for event in commuteEvents {
            events.append(event)
            coveredIntervals.append(DateInterval(start: event.startDate, end: event.endDate))
        }

        // Priority 3: Exercise
        let exerciseEvents = inferExercise(from: sorted, covered: coveredIntervals)
        for event in exerciseEvents {
            events.append(event)
            coveredIntervals.append(DateInterval(start: event.startDate, end: event.endDate))
        }

        // Priority 4: Location stays
        let stayEvents = inferLocationStays(from: sorted, places: places, covered: coveredIntervals)
        for event in stayEvents {
            events.append(event)
            coveredIntervals.append(DateInterval(start: event.startDate, end: event.endDate))
        }

        // Priority 5: Blank periods
        let blankEvents = inferBlankPeriods(from: sorted, covered: coveredIntervals)
        events.append(contentsOf: blankEvents)

        // Merge consecutive same-type events
        events = mergeConsecutiveEvents(events)

        // Sort by start date
        events.sort { $0.startDate < $1.startDate }

        return events
    }

    // MARK: - Sleep Inference

    private func inferSleep(from readings: [SensorReading]) -> [InferredEvent] {
        let deviceEvents = readings.filter { $0.sensorType == .deviceState }
        var results: [InferredEvent] = []

        for (index, reading) in deviceEvents.enumerated() {
            guard case .deviceState(let event) = reading.payload,
                  event == .screenLock else { continue }

            let lockTime = reading.timestamp
            let hour = Calendar.current.component(.hour, from: lockTime)

            // Find the next screenUnlock
            let nextUnlock = deviceEvents[(index + 1)...].first { r in
                if case .deviceState(let e) = r.payload { return e == .screenUnlock }
                return false
            }

            let unlockTime = nextUnlock?.timestamp

            // Night sleep: lock after 20:00 or before 4:00, gap > 2 hours
            let isNightWindow = hour >= 20 || hour < 4
            if isNightWindow {
                if let unlock = unlockTime {
                    let gap = unlock.timeIntervalSince(lockTime)
                    if gap >= Threshold.sleepMinGapHours {
                        results.append(InferredEvent(
                            kind: .sleep,
                            startDate: lockTime,
                            endDate: unlock,
                            confidence: .medium,
                            displayName: "睡眠"
                        ))
                        continue
                    }
                }

                // No forward unlock found (or gap too short). For cross-midnight sleep
                // on the same calendar day, look for a morning unlock (before 12:00) that
                // appears earlier in timestamp order — it represents the next-morning wake.
                let morningUnlock = deviceEvents.first { r in
                    guard case .deviceState(let e) = r.payload, e == .screenUnlock else { return false }
                    let h = Calendar.current.component(.hour, from: r.timestamp)
                    return h < 12 && r.timestamp < lockTime
                }

                if let wake = morningUnlock {
                    // On the same calendar day, wake.timestamp < lockTime because the
                    // morning reading has an earlier hour. The real duration wraps through
                    // midnight. We shift the wake time forward by 24h so that
                    // endDate > startDate (required by DateInterval).
                    let wakeTime: Date
                    if wake.timestamp < lockTime {
                        wakeTime = wake.timestamp.addingTimeInterval(24 * 3600)
                    } else {
                        wakeTime = wake.timestamp
                    }
                    let realDuration = wakeTime.timeIntervalSince(lockTime)
                    if realDuration >= Threshold.sleepMinGapHours {
                        results.append(InferredEvent(
                            kind: .sleep,
                            startDate: lockTime,
                            endDate: wakeTime,
                            confidence: .medium,
                            displayName: "睡眠"
                        ))
                        continue
                    }
                }

                continue
            }

            // Nap: lock between 11:00-17:00, gap > 40 min
            let isNapWindow = hour >= 11 && hour < 17
            if isNapWindow, let unlock = unlockTime {
                let gap = unlock.timeIntervalSince(lockTime)
                if gap >= Threshold.napMinGapMinutes {
                    results.append(InferredEvent(
                        kind: .sleep,
                        startDate: lockTime,
                        endDate: unlock,
                        confidence: .medium,
                        displayName: "小睡"
                    ))
                }
            }
        }

        return results
    }

    // MARK: - Commute Inference

    private func inferCommute(
        from readings: [SensorReading],
        places: [KnownPlace],
        covered: [DateInterval]
    ) -> [InferredEvent] {
        let motionReadings = readings.filter { r in
            if case .motion(let activity, _) = r.payload {
                return activity == .automotive
            }
            return false
        }
        let locationReadings = readings.filter { $0.sensorType == .location }

        var results: [InferredEvent] = []

        for motion in motionReadings {
            let start = motion.timestamp
            let end = motion.endTimestamp ?? start
            let duration = end.timeIntervalSince(start)

            guard duration >= Threshold.commuteMinDuration else { continue }
            let interval = DateInterval(start: start, end: end)
            guard !isOverlapping(interval, with: covered) else { continue }

            // Check for location changes during the commute window
            let relevantLocations = locationReadings.filter { loc in
                loc.timestamp >= start && loc.timestamp <= end
            }

            let hasLocationChange = relevantLocations.count >= 2

            guard hasLocationChange || duration >= Threshold.commuteMinDuration else { continue }

            // Try to resolve origin/destination place names
            var displayParts: [String] = ["通勤"]

            if let firstLoc = relevantLocations.first,
               let lastLoc = relevantLocations.last,
               firstLoc.id != lastLoc.id {
                if case .location(let lat1, let lon1, _) = firstLoc.payload {
                    if let origin = findPlace(latitude: lat1, longitude: lon1, in: places) {
                        displayParts.append("从 \(origin)")
                    }
                }
                if case .location(let lat2, let lon2, _) = lastLoc.payload {
                    if let destination = findPlace(latitude: lat2, longitude: lon2, in: places) {
                        displayParts.append("到 \(destination)")
                    }
                }
            }

            results.append(InferredEvent(
                kind: .commute,
                startDate: start,
                endDate: end,
                confidence: .medium,
                displayName: displayParts.joined(separator: " ")
            ))
        }

        return results
    }

    // MARK: - Exercise Inference

    private func inferExercise(
        from readings: [SensorReading],
        covered: [DateInterval]
    ) -> [InferredEvent] {
        let motionReadings = readings.filter { $0.sensorType == .motion }
        var results: [InferredEvent] = []

        // Group consecutive motion readings by activity type
        let activitySegments = buildActivitySegments(from: motionReadings)

        for segment in activitySegments {
            let interval = DateInterval(start: segment.start, end: segment.end)
            guard !isOverlapping(interval, with: covered) else { continue }

            let duration = segment.end.timeIntervalSince(segment.start)

            switch segment.activity {
            case .running:
                // Running: any duration
                results.append(InferredEvent(
                    kind: .workout,
                    startDate: segment.start,
                    endDate: segment.end,
                    confidence: .medium,
                    displayName: "跑步"
                ))

            case .cycling:
                // Cycling: any duration
                results.append(InferredEvent(
                    kind: .workout,
                    startDate: segment.start,
                    endDate: segment.end,
                    confidence: .medium,
                    displayName: "骑行"
                ))

            case .walking:
                // Walking > 10 min → activeWalk, also >= 1 min recorded
                if duration >= Threshold.walkMinDuration {
                    results.append(InferredEvent(
                        kind: .activeWalk,
                        startDate: segment.start,
                        endDate: segment.end,
                        confidence: duration >= Threshold.walkMinDurationForActiveWalk ? .medium : .low,
                        displayName: "步行"
                    ))
                }

            default:
                break
            }
        }

        return results
    }

    // MARK: - Location Stay Inference

    private func inferLocationStays(
        from readings: [SensorReading],
        places: [KnownPlace],
        covered: [DateInterval]
    ) -> [InferredEvent] {
        let visitReadings = readings.filter { r in
            if case .visit = r.payload { return true }
            return false
        }

        var results: [InferredEvent] = []

        for visit in visitReadings {
            guard case .visit(let lat, let lon, let arrival, let departure) = visit.payload else {
                continue
            }

            let arrivalDate = arrival
            let departureDate = departure ?? visit.endTimestamp ?? visit.timestamp
            let stay = departureDate.timeIntervalSince(arrivalDate)

            guard stay >= Threshold.visitMinStay else { continue }

            let interval = DateInterval(start: arrivalDate, end: departureDate)
            guard !isOverlapping(interval, with: covered) else { continue }

            let placeName = findPlace(latitude: lat, longitude: lon, in: places) ?? "未知地点"

            results.append(InferredEvent(
                kind: .quietTime,
                startDate: arrivalDate,
                endDate: departureDate,
                confidence: .medium,
                displayName: placeName
            ))
        }

        return results
    }

    // MARK: - Blank Period Inference

    private func inferBlankPeriods(
        from readings: [SensorReading],
        covered: [DateInterval]
    ) -> [InferredEvent] {
        let deviceEvents = readings.filter { $0.sensorType == .deviceState }
        let motionReadings = readings.filter { $0.sensorType == .motion }
        var results: [InferredEvent] = []

        // Find screen lock periods with no unlock for > 15 min during 6:00-22:00
        for (index, reading) in deviceEvents.enumerated() {
            guard case .deviceState(let event) = reading.payload,
                  event == .screenLock else { continue }

            let lockTime = reading.timestamp
            let lockHour = Calendar.current.component(.hour, from: lockTime)
            guard lockHour >= 6 && lockHour < 22 else { continue }

            // Find next screenUnlock
            let nextUnlock = deviceEvents[(index + 1)...].first { r in
                if case .deviceState(let e) = r.payload { return e == .screenUnlock }
                return false
            }

            guard let unlockTime = nextUnlock?.timestamp else { continue }
            let gap = unlockTime.timeIntervalSince(lockTime)
            guard gap >= Threshold.blankMinDuration else { continue }

            let interval = DateInterval(start: lockTime, end: unlockTime)
            guard !isOverlapping(interval, with: covered) else { continue }

            // Check for stationary motion during this period
            let isStationary = motionReadings.contains { motion in
                guard case .motion(let activity, _) = motion.payload,
                      activity == .stationary else { return false }
                let motionStart = motion.timestamp
                let motionEnd = motion.endTimestamp ?? motionStart
                // The stationary period overlaps with the lock period
                return motionStart < unlockTime && motionEnd > lockTime
            }

            guard isStationary else { continue }

            results.append(InferredEvent(
                kind: .quietTime,
                startDate: lockTime,
                endDate: unlockTime,
                confidence: .low,
                displayName: "离开了手机"
            ))
        }

        return results
    }

    // MARK: - Helpers

    private struct ActivitySegment {
        let activity: MotionActivity
        let start: Date
        let end: Date
    }

    private func buildActivitySegments(from motionReadings: [SensorReading]) -> [ActivitySegment] {
        var segments: [ActivitySegment] = []

        for reading in motionReadings {
            guard case .motion(let activity, _) = reading.payload else { continue }

            let start = reading.timestamp
            let end = reading.endTimestamp ?? start

            // Try to merge with last segment if same activity and close in time
            if let last = segments.last,
               last.activity == activity,
               start.timeIntervalSince(last.end) < Threshold.mergeGap {
                segments[segments.count - 1] = ActivitySegment(
                    activity: activity,
                    start: last.start,
                    end: max(last.end, end)
                )
            } else {
                segments.append(ActivitySegment(activity: activity, start: start, end: end))
            }
        }

        return segments
    }

    private func isOverlapping(_ interval: DateInterval, with covered: [DateInterval]) -> Bool {
        covered.contains { $0.intersects(interval) }
    }

    private func findPlace(latitude: Double, longitude: Double, in places: [KnownPlace]) -> String? {
        let target = CLLocation(latitude: latitude, longitude: longitude)
        let match = places.first { place in
            let loc = CLLocation(latitude: place.latitude, longitude: place.longitude)
            return target.distance(from: loc) < max(place.radius, Threshold.placeMatchRadius)
        }
        return match?.name
    }

    private func mergeConsecutiveEvents(_ events: [InferredEvent]) -> [InferredEvent] {
        guard !events.isEmpty else { return events }

        let sorted = events.sorted { $0.startDate < $1.startDate }
        var merged: [InferredEvent] = [sorted[0]]

        for event in sorted.dropFirst() {
            guard let last = merged.last,
                  last.kind == event.kind,
                  last.displayName == event.displayName,
                  event.startDate.timeIntervalSince(last.endDate) < Threshold.mergeGap else {
                merged.append(event)
                continue
            }

            // Merge: extend the last event's end date
            let mergedEvent = InferredEvent(
                kind: last.kind,
                startDate: last.startDate,
                endDate: max(last.endDate, event.endDate),
                confidence: min(last.confidence, event.confidence),
                displayName: last.displayName
            )
            merged[merged.count - 1] = mergedEvent
        }

        return merged
    }
}
