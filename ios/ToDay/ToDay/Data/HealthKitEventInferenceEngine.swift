import Foundation

struct HealthKitEventInferenceEngine: EventInferring {
    private let calendar: Calendar
    private let mergeGapThreshold: TimeInterval = 5 * 60
    private let minimumInferredDuration: TimeInterval = 5 * 60

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func inferEvents(from rawData: DayRawData, on date: Date) async throws -> [InferredEvent] {
        let dayInterval = makeDayInterval(for: date)
        let moodEvents = buildMoodEvents(from: rawData.moodRecords, in: dayInterval)

        guard hasAnyHealthData(in: rawData) else {
            let quiet = buildAllDayQuietEvent(in: dayInterval, heartRateSamples: rawData.heartRateSamples)
            return sortEvents([attachMetrics(to: quiet, using: rawData)] + moodEvents)
        }

        var occupied: [DateInterval] = []
        var intervalEvents: [InferredEvent] = []

        let highCandidates = buildSleepEvents(from: rawData.sleepSamples, in: dayInterval) +
            buildWorkoutEvents(from: rawData.workouts, in: dayInterval)

        for candidate in highCandidates.sorted(by: eventSortOrder) {
            for fragment in subtract(candidateInterval(for: candidate), by: occupied) {
                let clippedEvent = candidate.withInterval(fragment)
                intervalEvents.append(clippedEvent)
                occupied.append(fragment)
            }
        }

        occupied = mergeIntervals(occupied)

        let mediumCandidates = buildMovementEvents(
            from: rawData.stepSamples,
            heartRateSamples: rawData.heartRateSamples,
            in: dayInterval,
            excluding: occupied
        )

        for candidate in mediumCandidates.sorted(by: eventSortOrder) {
            for fragment in subtract(candidateInterval(for: candidate), by: occupied) {
                let clippedEvent = candidate.withInterval(fragment)
                guard clippedEvent.duration >= minimumInferredDuration else { continue }
                intervalEvents.append(clippedEvent)
                occupied.append(fragment)
            }
        }

        occupied = mergeIntervals(occupied)

        let quietEvents = buildQuietTimeEvents(
            in: dayInterval,
            excluding: occupied,
            heartRateSamples: rawData.heartRateSamples
        )

        intervalEvents.append(contentsOf: quietEvents)

        let filteredIntervals = intervalEvents
            .filter { event in
                event.confidence == .high || event.kind == .mood || event.duration >= minimumInferredDuration
            }
            .map { attachMetrics(to: $0, using: rawData) }

        return sortEvents(filteredIntervals + moodEvents.map { attachMetrics(to: $0, using: rawData) })
    }

    private func hasAnyHealthData(in rawData: DayRawData) -> Bool {
        !rawData.heartRateSamples.isEmpty ||
        !rawData.stepSamples.isEmpty ||
        !rawData.sleepSamples.isEmpty ||
        !rawData.workouts.isEmpty ||
        !rawData.activeEnergySamples.isEmpty
    }

    private func buildSleepEvents(from samples: [SleepSample], in dayInterval: DateInterval) -> [InferredEvent] {
        let clippedSamples = samples
            .compactMap { sample -> (interval: DateInterval, stage: SleepStage)? in
                let interval = DateInterval(start: sample.startDate, end: sample.endDate)
                guard let clipped = interval.intersection(with: dayInterval), clipped.duration > 0 else {
                    return nil
                }
                return (clipped, sample.stage)
            }
            .sorted { $0.interval.start < $1.interval.start }

        guard !clippedSamples.isEmpty else { return [] }

        var groups: [[(interval: DateInterval, stage: SleepStage)]] = []

        for sample in clippedSamples {
            if var lastGroup = groups.popLast() {
                let lastEnd = lastGroup.last?.interval.end ?? sample.interval.start
                if sample.interval.start.timeIntervalSince(lastEnd) <= mergeGapThreshold {
                    lastGroup.append(sample)
                    groups.append(lastGroup)
                } else {
                    groups.append(lastGroup)
                    groups.append([sample])
                }
            } else {
                groups.append([sample])
            }
        }

        return groups.compactMap { group in
            guard let first = group.first, let last = group.last else { return nil }
            let sleepStages = group.map { sample in
                SleepStageSegment(
                    start: sample.interval.start,
                    end: sample.interval.end,
                    stage: sample.stage
                )
            }
            return InferredEvent(
                kind: .sleep,
                startDate: first.interval.start,
                endDate: last.interval.end,
                confidence: .high,
                displayName: "睡眠",
                subtitle: sleepSubtitle(for: group),
                associatedMetrics: EventMetrics(sleepStages: sleepStages)
            )
        }
    }

    private func buildWorkoutEvents(from workouts: [WorkoutSample], in dayInterval: DateInterval) -> [InferredEvent] {
        workouts
            .compactMap { workout -> InferredEvent? in
                let interval = DateInterval(start: workout.startDate, end: workout.endDate)
                guard let clipped = interval.intersection(with: dayInterval), clipped.duration > 0 else {
                    return nil
                }

                let durationMinutes = max(Int(clipped.duration / 60), 1)
                let subtitleParts = [
                    "\(durationMinutes) 分钟",
                    workout.activeEnergy.map { "\(Int($0.rounded())) 千卡" },
                    workout.distance.map { formatDistance($0) }
                ].compactMap { $0 }

                return InferredEvent(
                    kind: .workout,
                    startDate: clipped.start,
                    endDate: clipped.end,
                    confidence: .high,
                    displayName: workout.displayName,
                    subtitle: subtitleParts.isEmpty ? nil : subtitleParts.joined(separator: " · ")
                )
            }
            .sorted(by: eventSortOrder)
    }

    private func buildMovementEvents(
        from stepSamples: [DateValueSample],
        heartRateSamples samples: [DateValueSample],
        in dayInterval: DateInterval,
        excluding occupied: [DateInterval]
    ) -> [InferredEvent] {
        let restingHeartRate = restingHeartRateBaseline(from: samples)
        let adjustedSamples = stepSamples
            .flatMap { sample in
                let interval = DateInterval(start: sample.startDate, end: sample.endDate)
                guard let clipped = interval.intersection(with: dayInterval), clipped.duration > 0 else {
                    return [DateValueSample]()
                }

                return subtract(clipped, by: occupied).compactMap { availableInterval -> DateValueSample? in
                    let fraction = availableInterval.duration / clipped.duration
                    let adjustedValue = sample.value * fraction
                    guard adjustedValue > 0 else { return nil }

                    return DateValueSample(
                        startDate: availableInterval.start,
                        endDate: availableInterval.end,
                        value: adjustedValue
                    )
                }
            }
            .sorted(by: { (lhs: DateValueSample, rhs: DateValueSample) in
                lhs.startDate < rhs.startDate
            })

        guard !adjustedSamples.isEmpty else { return [] }

        var clusters: [[DateValueSample]] = []

        for sample in adjustedSamples {
            if var lastCluster = clusters.popLast() {
                let lastEnd = lastCluster.last?.endDate ?? sample.startDate
                if sample.startDate.timeIntervalSince(lastEnd) <= mergeGapThreshold {
                    lastCluster.append(sample)
                    clusters.append(lastCluster)
                } else {
                    clusters.append(lastCluster)
                    clusters.append([sample])
                }
            } else {
                clusters.append([sample])
            }
        }

        return clusters.compactMap { cluster -> InferredEvent? in
            guard let first = cluster.first, let last = cluster.last else { return nil }

            let interval = DateInterval(start: first.startDate, end: last.endDate)
            guard interval.duration >= 10 * 60 else { return nil }

            let totalSteps = Int(cluster.reduce(0.0) { $0 + $1.value }.rounded())
            let cadencePerMinute = Double(totalSteps) / max(interval.duration / 60, 1)
            let clusterHeartSamples = self.heartRateSamples(
                overlapping: interval,
                samples: samples
            )
            let averageHeartRate = clusterHeartSamples.isEmpty
                ? nil
                : clusterHeartSamples.map(\.value).reduce(0, +) / Double(clusterHeartSamples.count)
            let elevatedHeartRateThreshold = restingHeartRate.map { $0 + 30 }
            let hasHeartRateSignal = averageHeartRate != nil && elevatedHeartRateThreshold != nil
            let isHighHeartRate = if let averageHeartRate, let elevatedHeartRateThreshold {
                averageHeartRate > elevatedHeartRateThreshold
            } else {
                false
            }
            let isHighCadence = cadencePerMinute > 60

            let classification: (kind: EventKind, confidence: EventConfidence)? = {
                if isHighHeartRate, isHighCadence {
                    return (.activeWalk, .high)
                }

                if isHighHeartRate, !isHighCadence {
                    return (.quietTime, .medium)
                }

                if hasHeartRateSignal, !isHighHeartRate, isHighCadence {
                    return (.activeWalk, .medium)
                }

                let fallbackKind = classifyMovementEvent(startDate: interval.start, duration: interval.duration)
                return fallbackKind == .commute || fallbackKind == .activeWalk
                    ? (fallbackKind, .medium)
                    : nil
                }()

            guard let classification else { return nil }

            let title: String
            switch classification.kind {
            case .commute:
                title = "步行通勤"
            case .activeWalk:
                title = "活跃步行"
            case .quietTime:
                title = quietTimeName(for: interval.start)
            default:
                title = "活动"
            }

            let subtitleParts = [
                "\(max(totalSteps, 1)) 步",
                averageHeartRate.map { "平均 \(Int($0.rounded())) 次/分" }
            ].compactMap { $0 }

            return InferredEvent(
                kind: classification.kind,
                startDate: interval.start,
                endDate: interval.end,
                confidence: classification.confidence,
                displayName: title,
                subtitle: subtitleParts.joined(separator: " · ")
            )
        }
    }

    private func buildQuietTimeEvents(
        in dayInterval: DateInterval,
        excluding occupied: [DateInterval],
        heartRateSamples: [DateValueSample]
    ) -> [InferredEvent] {
        let gaps = complement(of: dayInterval, occupied: occupied)
        let boundaries = quietTimeBoundaries(for: dayInterval.start)

        let segmented = gaps.flatMap { gap -> [InferredEvent] in
            var segments: [InferredEvent] = []
            var cursor = gap.start
            let gapEnd = gap.end

            for boundary in boundaries where boundary > cursor && boundary < gapEnd {
                let interval = DateInterval(start: cursor, end: boundary)
                if interval.duration > 0 {
                    segments.append(makeQuietEvent(for: interval))
                }
                cursor = boundary
            }

            let finalInterval = DateInterval(start: cursor, end: gapEnd)
            if finalInterval.duration > 0 {
                segments.append(makeQuietEvent(for: finalInterval))
            }

            return segments
        }

        let merged = mergeQuietTimeEvents(segmented.sorted(by: eventSortOrder))
        return merged.map { event in
            guard event.subtitle == nil,
                  let avg = averageHeartRate(for: event, heartRateSamples: heartRateSamples) else {
                return event
            }
            return event.withSubtitle("心率平稳 · \(Int(avg.rounded())) 次/分")
        }
    }

    private func buildMoodEvents(from records: [MoodRecord], in dayInterval: DateInterval) -> [InferredEvent] {
        records
            .filter { dayInterval.contains($0.createdAt) }
            .map { record in
                InferredEvent(
                    id: record.id,
                    kind: .mood,
                    startDate: record.createdAt,
                    endDate: record.createdAt,
                    confidence: .high,
                    displayName: "心情：\(record.mood.rawValue)",
                    subtitle: record.note.isEmpty ? nil : record.note,
                    photoAttachments: record.photoAttachments
                )
            }
    }

    private func attachMetrics(to event: InferredEvent, using rawData: DayRawData) -> InferredEvent {
        guard event.kind != .mood else { return event }

        let interval = candidateInterval(for: event)
        var metrics = event.associatedMetrics ?? EventMetrics()

        let heartSamples = heartRateSamples(overlapping: interval, samples: rawData.heartRateSamples)
        if !heartSamples.isEmpty {
            let values = heartSamples.map(\.value)
            metrics.averageHeartRate = values.reduce(0, +) / Double(values.count)
            metrics.maxHeartRate = values.max()
            metrics.minHeartRate = values.min()
            metrics.heartRateSamples = heartSamples.map { HeartRateSample(date: $0.startDate, value: $0.value) }
        }

        metrics.weather = closestWeather(to: event.startDate, in: rawData.hourlyWeather)
        metrics.location = overlappingLocationVisit(for: interval, in: rawData.locationVisits)

        let matchedPhotos = photos(in: interval, from: rawData.photos)
        if !matchedPhotos.isEmpty { metrics.photos = matchedPhotos }

        let stepCount = summedValue(of: rawData.stepSamples, over: interval)
        if stepCount > 0 { metrics.stepCount = Int(stepCount.rounded()) }

        let energy = summedValue(of: rawData.activeEnergySamples, over: interval)
        if energy > 0 { metrics.activeEnergy = energy }

        if event.kind == .workout {
            if let workout = rawData.workouts.first(where: {
                DateInterval(start: $0.startDate, end: $0.endDate).intersection(with: interval) != nil
            }) {
                metrics.workoutType = workout.displayName
                metrics.activeEnergy = workout.activeEnergy ?? metrics.activeEnergy
                metrics.distance = workout.distance
            }
        }

        return event.withMetrics(metrics)
    }

    private func closestWeather(to date: Date, in weather: [HourlyWeather]) -> HourlyWeather? {
        weather.min { lhs, rhs in
            abs(lhs.date.timeIntervalSince(date)) < abs(rhs.date.timeIntervalSince(date))
        }
    }

    private func overlappingLocationVisit(
        for interval: DateInterval,
        in visits: [LocationVisit]
    ) -> LocationVisit? {
        visits
            .filter { visit in
                DateInterval(start: visit.arrivalDate, end: visit.departureDate)
                    .intersection(with: interval) != nil
            }
            .sorted { $0.arrivalDate < $1.arrivalDate }
            .first
    }

    private func photos(
        in interval: DateInterval,
        from photos: [PhotoReference]
    ) -> [PhotoReference] {
        photos
            .filter { interval.contains($0.creationDate) }
            .sorted { $0.creationDate < $1.creationDate }
    }

    private func buildAllDayQuietEvent(in dayInterval: DateInterval, heartRateSamples: [DateValueSample]) -> InferredEvent {
        let quietEvent = InferredEvent(
            kind: .quietTime,
            startDate: dayInterval.start,
            endDate: dayInterval.end,
            confidence: .low,
            displayName: "安静时光"
        )

        if let avg = averageHeartRate(for: quietEvent, heartRateSamples: heartRateSamples) {
            return quietEvent.withSubtitle("心率平稳 · \(Int(avg.rounded())) 次/分")
        }

        return quietEvent
    }

    private func makeQuietEvent(for interval: DateInterval) -> InferredEvent {
        InferredEvent(
            kind: .quietTime,
            startDate: interval.start,
            endDate: interval.end,
            confidence: .low,
            displayName: quietTimeName(for: interval.start)
        )
    }

    private func averageHeartRate(for event: InferredEvent, heartRateSamples samples: [DateValueSample]) -> Double? {
        let samples = heartRateSamples(overlapping: candidateInterval(for: event), samples: samples)
        guard !samples.isEmpty else { return nil }
        return samples.map(\.value).reduce(0, +) / Double(samples.count)
    }

    private func restingHeartRateBaseline(from samples: [DateValueSample]) -> Double? {
        let orderedValues = samples.map(\.value).sorted()
        guard !orderedValues.isEmpty else { return nil }

        let baselineCount = max(1, Int(Double(orderedValues.count) * 0.25))
        let baselineValues = orderedValues.prefix(baselineCount)
        return baselineValues.reduce(0, +) / Double(baselineValues.count)
    }

    private func classifyMovementEvent(startDate: Date, duration: TimeInterval) -> EventKind {
        let hour = calendar.component(.hour, from: startDate)
        let isCommuteHour = (7..<9).contains(hour) || (17..<19).contains(hour)
        let isCommuteDuration = (15 * 60)...(60 * 60) ~= duration
        return isCommuteHour && isCommuteDuration ? .commute : .activeWalk
    }

    private func candidateInterval(for event: InferredEvent) -> DateInterval {
        let endDate = max(event.endDate, event.startDate)
        return DateInterval(start: event.startDate, end: endDate)
    }

    private func heartRateSamples(
        overlapping interval: DateInterval,
        samples: [DateValueSample]
    ) -> [DateValueSample] {
        samples.filter { sample in
            let sampleInterval = DateInterval(start: sample.startDate, end: sample.endDate)
            if interval.duration == 0 {
                return sampleInterval.contains(interval.start) || sample.startDate == interval.start
            }
            return sampleInterval.intersection(with: interval) != nil
        }
    }

    private func summedValue(of samples: [DateValueSample], over interval: DateInterval) -> Double {
        samples.reduce(0) { partialResult, sample in
            let sampleInterval = DateInterval(start: sample.startDate, end: sample.endDate)
            guard let overlap = sampleInterval.intersection(with: interval),
                  sampleInterval.duration > 0 else {
                return partialResult
            }

            let fraction = overlap.duration / sampleInterval.duration
            return partialResult + (sample.value * fraction)
        }
    }

    private func quietTimeBoundaries(for date: Date) -> [Date] {
        let startOfDay = calendar.startOfDay(for: date)
        return [6, 12, 14, 18, 22, 24]
            .compactMap { calendar.date(byAdding: .hour, value: $0, to: startOfDay) }
    }

    private func quietTimeName(for date: Date) -> String {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 6..<12:
            return "安静的上午"
        case 12..<14:
            return "午间时光"
        case 14..<18:
            return "安静的下午"
        case 18..<22:
            return "安静的夜晚"
        default:
            return "安静时光"
        }
    }

    private func mergeQuietTimeEvents(_ events: [InferredEvent]) -> [InferredEvent] {
        var merged: [InferredEvent] = []

        for event in events {
            guard event.kind == .quietTime else {
                merged.append(event)
                continue
            }

            if let last = merged.last,
               last.kind == .quietTime,
               abs(last.endDate.timeIntervalSince(event.startDate)) < 1,
               last.duration + event.duration < 3 * 60 * 60 {
                var combined = last
                combined = InferredEvent(
                    id: last.id,
                    kind: .quietTime,
                    startDate: last.startDate,
                    endDate: event.endDate,
                    confidence: .low,
                    displayName: quietTimeName(for: last.startDate),
                    subtitle: nil
                )
                merged[merged.count - 1] = combined
            } else {
                merged.append(event)
            }
        }

        return merged
    }

    private func sleepSubtitle(for samples: [(interval: DateInterval, stage: SleepStage)]) -> String? {
        let orderedStages: [SleepStage] = [.deep, .light, .rem, .awake, .unknown]
        let durations = Dictionary(grouping: samples, by: \.stage)
            .mapValues { stageSamples in
                stageSamples.reduce(0.0) { $0 + $1.interval.duration }
            }

        let parts = orderedStages.compactMap { stage -> String? in
            guard let duration = durations[stage], duration > 0 else { return nil }
            return "\(sleepStageLabel(stage)) \(formattedHours(duration))"
        }

        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    private func sleepStageLabel(_ stage: SleepStage) -> String {
        switch stage {
        case .awake:
            return "清醒"
        case .rem:
            return "快眼动"
        case .light:
            return "浅睡"
        case .deep:
            return "深睡"
        case .unknown:
            return "睡眠"
        }
    }

    private func formattedHours(_ duration: TimeInterval) -> String {
        let hours = duration / 3600
        if hours.rounded() == hours {
            return "\(Int(hours)) 小时"
        }
        return String(format: "%.1f 小时", hours)
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f 公里", meters / 1000)
        }
        return "\(Int(meters.rounded())) 米"
    }

    private func makeDayInterval(for date: Date) -> DateInterval {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(24 * 60 * 60)
        return DateInterval(start: start, end: end)
    }

    private func complement(of interval: DateInterval, occupied: [DateInterval]) -> [DateInterval] {
        guard !occupied.isEmpty else { return [interval] }

        let mergedOccupied = mergeIntervals(occupied)
        var gaps: [DateInterval] = []
        var cursor = interval.start

        for occupiedInterval in mergedOccupied {
            if occupiedInterval.end <= interval.start || occupiedInterval.start >= interval.end {
                continue
            }

            let clippedStart = max(occupiedInterval.start, interval.start)
            let clippedEnd = min(occupiedInterval.end, interval.end)

            if clippedStart > cursor {
                gaps.append(DateInterval(start: cursor, end: clippedStart))
            }

            cursor = max(cursor, clippedEnd)
        }

        if cursor < interval.end {
            gaps.append(DateInterval(start: cursor, end: interval.end))
        }

        return gaps.filter { $0.duration > 0 }
    }

    private func subtract(_ interval: DateInterval, by occupied: [DateInterval]) -> [DateInterval] {
        complement(of: interval, occupied: occupied)
    }

    private func mergeIntervals(_ intervals: [DateInterval]) -> [DateInterval] {
        guard !intervals.isEmpty else { return [] }

        let sorted = intervals.sorted { $0.start < $1.start }
        var merged: [DateInterval] = [sorted[0]]

        for interval in sorted.dropFirst() {
            if let last = merged.last, interval.start <= last.end {
                merged[merged.count - 1] = DateInterval(start: last.start, end: max(last.end, interval.end))
            } else {
                merged.append(interval)
            }
        }

        return merged
    }

    private func sortEvents(_ events: [InferredEvent]) -> [InferredEvent] {
        events.sorted { lhs, rhs in
            if lhs.startDate != rhs.startDate {
                return lhs.startDate < rhs.startDate
            }

            if lhs.duration != rhs.duration {
                return lhs.duration > rhs.duration
            }

            if lhs.confidence != rhs.confidence {
                return lhs.confidence > rhs.confidence
            }

            return lhs.resolvedName < rhs.resolvedName
        }
    }

    private func eventSortOrder(_ lhs: InferredEvent, _ rhs: InferredEvent) -> Bool {
        lhs.startDate < rhs.startDate
    }
}

