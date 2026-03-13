import Foundation
import HealthKit

struct MockEventInferenceEngine: EventInferring {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func inferEvents(from rawData: DayRawData, on date: Date) async throws -> [InferredEvent] {
        let startOfDay = calendar.startOfDay(for: date)

        func time(_ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(
                byAdding: .minute,
                value: (hour * 60) + minute,
                to: startOfDay
            ) ?? startOfDay
        }

        var events: [InferredEvent] = [
            makeSleepEvent(rawData: rawData, start: time(0, 0), end: time(7, 0)),
            makeQuietEvent(
                rawData: rawData,
                title: "晨间安静",
                start: time(7, 0),
                end: time(7, 30),
                subtitle: "慢慢醒来，准备出门"
            ),
            makeCommuteEvent(
                rawData: rawData,
                title: "步行通勤",
                subtitle: "家 → 公司",
                start: time(7, 30),
                end: time(8, 0)
            ),
            makeQuietEvent(
                rawData: rawData,
                title: "安静上午",
                start: time(8, 0),
                end: time(12, 0),
                subtitle: "晴 22° · 办公室"
            ),
            makeQuietEvent(
                rawData: rawData,
                title: "午间时光",
                start: time(12, 0),
                end: time(13, 0),
                subtitle: "附近餐厅 · 午餐与放空"
            ),
            makeQuietEvent(
                rawData: rawData,
                title: "安静下午",
                start: time(13, 0),
                end: time(14, 0),
                subtitle: "重新进入工作节奏"
            ),
            makeWorkoutEvent(rawData: rawData, start: time(14, 0), end: time(14, 45)),
            makeQuietEvent(
                rawData: rawData,
                title: "安静下午",
                start: time(14, 45),
                end: time(17, 30),
                subtitle: "跑完后回到桌前"
            ),
            makeCommuteEvent(
                rawData: rawData,
                title: "步行通勤返程",
                subtitle: "公司 → 家",
                start: time(17, 30),
                end: time(18, 0)
            ),
            makeQuietEvent(
                rawData: rawData,
                title: "安静夜晚",
                start: time(18, 0),
                end: time(22, 0),
                subtitle: "在家收束今天"
            ),
            makeQuietEvent(
                rawData: rawData,
                title: "安静深夜",
                start: time(22, 0),
                end: time(24, 0),
                subtitle: "准备休息"
            )
        ]

        events.append(
            contentsOf: rawData.moodRecords.map {
                $0.toInferredEvent(referenceDate: date, calendar: calendar)
            }
        )

        return events.sorted { lhs, rhs in
            if lhs.startDate == rhs.startDate {
                return lhs.id.uuidString < rhs.id.uuidString
            }

            return lhs.startDate < rhs.startDate
        }
    }

    private func makeSleepEvent(rawData: DayRawData, start: Date, end: Date) -> InferredEvent {
        let metrics = makeMetrics(rawData: rawData, start: start, end: end, includeSleepStages: true)
        let stageText = sleepStageSummary(from: metrics.sleepStages ?? [])

        return InferredEvent(
            kind: .sleep,
            startDate: start,
            endDate: end,
            confidence: .high,
            displayName: "睡眠",
            subtitle: stageText,
            associatedMetrics: metrics
        )
    }

    private func makeQuietEvent(
        rawData: DayRawData,
        title: String,
        start: Date,
        end: Date,
        subtitle: String
    ) -> InferredEvent {
        InferredEvent(
            kind: .quietTime,
            startDate: start,
            endDate: end,
            confidence: .low,
            displayName: title,
            subtitle: subtitle,
            associatedMetrics: makeMetrics(rawData: rawData, start: start, end: end)
        )
    }

    private func makeCommuteEvent(
        rawData: DayRawData,
        title: String,
        subtitle: String,
        start: Date,
        end: Date
    ) -> InferredEvent {
        let metrics = makeMetrics(rawData: rawData, start: start, end: end)

        return InferredEvent(
            kind: .commute,
            startDate: start,
            endDate: end,
            confidence: .high,
            displayName: title,
            subtitle: subtitleWithDistanceAndSteps(
                base: subtitle,
                distance: metrics.distance,
                steps: metrics.stepCount
            ),
            associatedMetrics: metrics
        )
    }

    private func makeWorkoutEvent(rawData: DayRawData, start: Date, end: Date) -> InferredEvent {
        let metrics = makeMetrics(
            rawData: rawData,
            start: start,
            end: end,
            workoutType: "跑步"
        )

        return InferredEvent(
            kind: .workout,
            startDate: start,
            endDate: end,
            confidence: .high,
            displayName: "跑步",
            subtitle: workoutSubtitle(from: metrics),
            associatedMetrics: metrics
        )
    }

    private func makeMetrics(
        rawData: DayRawData,
        start: Date,
        end: Date,
        workoutType: String? = nil,
        includeSleepStages: Bool = false
    ) -> EventMetrics {
        let interval = DateInterval(start: start, end: end)
        let heartRateSamples = heartRateSamples(in: interval, from: rawData)
        let averageHeartRate = heartRateSamples.isEmpty ? nil : heartRateSamples.map(\.value).reduce(0, +) / Double(heartRateSamples.count)
        let maxHeartRate = heartRateSamples.map(\.value).max()
        let minHeartRate = heartRateSamples.map(\.value).min()
        let stepCount = Int(samples(in: interval, from: rawData.stepSamples).reduce(0) { $0 + $1.value }.rounded())
        let activeEnergy = samples(in: interval, from: rawData.activeEnergySamples).reduce(0) { $0 + $1.value }
        let workout = rawData.workouts.first(where: { DateInterval(start: $0.startDate, end: $0.endDate).intersection(with: interval) != nil })
        let photos = rawData.photos
            .filter { interval.contains($0.creationDate) }

        return EventMetrics(
            averageHeartRate: averageHeartRate,
            maxHeartRate: maxHeartRate,
            minHeartRate: minHeartRate,
            heartRateSamples: heartRateSamples.isEmpty ? nil : heartRateSamples,
            weather: nearestWeather(to: start, in: rawData.hourlyWeather),
            location: overlappingLocation(in: interval, visits: rawData.locationVisits),
            photos: photos.isEmpty ? nil : photos,
            sleepStages: includeSleepStages ? sleepStages(in: interval, from: rawData.sleepSamples) : nil,
            stepCount: stepCount > 0 ? stepCount : nil,
            activeEnergy: activeEnergy > 0 ? activeEnergy : nil,
            distance: workout?.distance,
            workoutType: workoutType ?? workout?.displayName
        )
    }

    private func samples(in interval: DateInterval, from values: [DateValueSample]) -> [DateValueSample] {
        values.filter { sample in
            DateInterval(start: sample.startDate, end: sample.endDate).intersection(with: interval) != nil
        }
    }

    private func heartRateSamples(in interval: DateInterval, from rawData: DayRawData) -> [HeartRateSample] {
        rawData.heartRateSamples
            .filter { sample in
                DateInterval(start: sample.startDate, end: sample.endDate).intersection(with: interval) != nil
            }
            .sorted { $0.startDate < $1.startDate }
            .map { HeartRateSample(date: $0.startDate, value: $0.value) }
    }

    private func sleepStages(in interval: DateInterval, from sleepSamples: [SleepSample]) -> [SleepStageSegment] {
        sleepSamples
            .filter { sample in
                DateInterval(start: sample.startDate, end: sample.endDate).intersection(with: interval) != nil
            }
            .sorted { $0.startDate < $1.startDate }
            .map { sample in
                SleepStageSegment(
                    start: sample.startDate,
                    end: sample.endDate,
                    stage: sample.stage
                )
            }
    }

    private func nearestWeather(to date: Date, in weather: [HourlyWeather]) -> HourlyWeather? {
        weather.min {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }
    }

    private func overlappingLocation(in interval: DateInterval, visits: [LocationVisit]) -> LocationVisit? {
        visits
            .filter { visit in
                DateInterval(start: visit.arrivalDate, end: visit.departureDate).intersection(with: interval) != nil
            }
            .sorted {
                $0.arrivalDate < $1.arrivalDate
            }
            .first
    }

    private func sleepStageSummary(from stages: [SleepStageSegment]) -> String {
        guard !stages.isEmpty else { return "整夜休息" }

        let grouped = Dictionary(grouping: stages, by: \.stage)
        let orderedStages: [SleepStage] = [.deep, .light, .rem]

        return orderedStages
            .compactMap { stage in
                guard let segments = grouped[stage], !segments.isEmpty else { return nil }
                let minutes = segments.reduce(0.0) { partial, segment in
                    partial + segment.end.timeIntervalSince(segment.start) / 60
                }
                return "\(stage.label) \(durationText(minutes: Int(minutes.rounded())))"
            }
            .joined(separator: " · ")
    }

    private func subtitleWithDistanceAndSteps(base: String, distance: Double?, steps: Int?) -> String {
        var segments = [base]

        if let distance {
            segments.append(String(format: "%.1f km", distance / 1_000))
        }

        if let steps {
            segments.append("\(steps) 步")
        }

        return segments.joined(separator: " · ")
    }

    private func workoutSubtitle(from metrics: EventMetrics) -> String {
        var segments = ["45 分钟"]

        if let distance = metrics.distance {
            segments.append(String(format: "%.1f km", distance / 1_000))
        }

        if let activeEnergy = metrics.activeEnergy {
            segments.append("\(Int(activeEnergy.rounded())) kcal")
        }

        segments.append("5'15\"/km")
        return segments.joined(separator: " · ")
    }

    private func durationText(minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60

        if hours > 0 {
            return remainder == 0 ? "\(hours)h" : "\(hours)h\(remainder)min"
        }

        return "\(minutes)min"
    }
}

private extension SleepStage {
    var label: String {
        switch self {
        case .deep:
            return "深睡"
        case .light:
            return "浅睡"
        case .rem:
            return "REM"
        case .awake:
            return "清醒"
        case .unknown:
            return "未知"
        }
    }
}
