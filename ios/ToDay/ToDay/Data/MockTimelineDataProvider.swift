import Foundation
import HealthKit

struct MockTimelineDataProvider: TimelineDataProviding {
    let source: TimelineSource = .mock
    private let eventInferenceEngine = MockEventInferenceEngine()
    private let calendar: Calendar = .current

    func loadTimeline(for date: Date) async throws -> DayTimeline {
        let rawData = makeRawData(for: date)
        let startOfDay = calendar.startOfDay(for: date)

        func time(_ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(
                byAdding: .minute,
                value: (hour * 60) + minute,
                to: startOfDay
            ) ?? startOfDay
        }

        var entries = try await eventInferenceEngine.inferEvents(from: rawData, on: date)

        entries.sort { $0.startDate < $1.startDate }

        return DayTimeline(
            date: date,
            summary: "这是一个完整模拟日：睡眠、通勤、跑步、照片、地点和心情都会落到同一张画卷里，方便你在模拟器里直接验证长卷与详情体验。",
            source: source,
            stats: makeStats(from: rawData),
            entries: entries
        )
    }

    private func makeRawData(for date: Date) -> DayRawData {
        let startOfDay = calendar.startOfDay(for: date)

        func time(_ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(
                byAdding: .minute,
                value: (hour * 60) + minute,
                to: startOfDay
            ) ?? startOfDay
        }

        let homeCoordinate = CoordinateValue(latitude: 39.9042, longitude: 116.4074)
        let officeCoordinate = CoordinateValue(latitude: 39.9836, longitude: 116.3155)
        let cafeCoordinate = CoordinateValue(latitude: 39.9854, longitude: 116.3138)
        let trailCoordinate = CoordinateValue(latitude: 39.9916, longitude: 116.3089)

        let heartRateSamples = makeSamples(
            from: [
                (0, 15, 53), (1, 20, 51), (2, 10, 50), (3, 35, 54), (4, 25, 52), (5, 30, 56), (6, 35, 58),
                (7, 10, 64), (7, 40, 86),
                (8, 30, 72), (9, 0, 68), (9, 30, 76), (10, 15, 69), (11, 30, 71),
                (12, 10, 78), (12, 45, 82),
                (13, 30, 73),
                (14, 5, 128), (14, 12, 142), (14, 20, 151), (14, 28, 158), (14, 36, 154), (14, 43, 146),
                (15, 10, 88), (16, 0, 74), (17, 0, 72), (17, 40, 91),
                (18, 30, 76), (19, 10, 71), (20, 0, 68), (21, 15, 66), (22, 30, 59), (23, 20, 56)
            ],
            on: startOfDay
        )

        let stepSamples = makeSamples(
            from: [
                (7, 30, 450), (7, 40, 520), (7, 50, 640),
                (8, 50, 80), (10, 20, 60), (11, 10, 70),
                (12, 15, 140), (12, 40, 180),
                (14, 5, 920), (14, 15, 1_080), (14, 25, 1_120), (14, 35, 1_050), (14, 43, 980),
                (15, 30, 110),
                (17, 32, 480), (17, 42, 560), (17, 52, 620),
                (19, 45, 90)
            ],
            on: startOfDay,
            durationMinutes: 8
        )

        let activeEnergySamples = makeSamples(
            from: [
                (7, 30, 24), (7, 42, 28), (7, 54, 32),
                (12, 10, 18), (12, 48, 22),
                (14, 5, 80), (14, 15, 92), (14, 25, 96), (14, 35, 88), (14, 43, 74),
                (17, 34, 26), (17, 46, 30), (17, 58, 28)
            ],
            on: startOfDay,
            durationMinutes: 10
        )

        let sleepSamples = [
            SleepSample(startDate: time(0, 0), endDate: time(1, 25), stage: .light),
            SleepSample(startDate: time(1, 25), endDate: time(2, 40), stage: .deep),
            SleepSample(startDate: time(2, 40), endDate: time(3, 25), stage: .rem),
            SleepSample(startDate: time(3, 25), endDate: time(5, 10), stage: .light),
            SleepSample(startDate: time(5, 10), endDate: time(6, 0), stage: .deep),
            SleepSample(startDate: time(6, 0), endDate: time(6, 35), stage: .rem),
            SleepSample(startDate: time(6, 35), endDate: time(7, 0), stage: .light)
        ]

        let workouts = [
            WorkoutSample(
                startDate: time(14, 0),
                endDate: time(14, 45),
                activityType: HKWorkoutActivityType.running.rawValue,
                activeEnergy: 430,
                distance: 6_100
            )
        ]

        let moodRecords = [
            MoodRecord(
                mood: .focused,
                note: "上午状态很稳，基本没被打断。",
                createdAt: time(9, 30),
                endedAt: time(9, 30),
                isTracking: false,
                captureMode: .point
            ),
            MoodRecord(
                mood: .calm,
                note: "跑完以后整个人松下来。",
                createdAt: time(20, 0),
                endedAt: time(20, 0),
                isTracking: false,
                captureMode: .point
            )
        ]

        let locationVisits = [
            LocationVisit(
                coordinate: homeCoordinate,
                arrivalDate: time(0, 0),
                departureDate: time(7, 25),
                placeName: "家"
            ),
            LocationVisit(
                coordinate: CoordinateValue(latitude: 39.9420, longitude: 116.3600),
                arrivalDate: time(7, 32),
                departureDate: time(7, 58),
                placeName: "通勤路上"
            ),
            LocationVisit(
                coordinate: officeCoordinate,
                arrivalDate: time(8, 0),
                departureDate: time(11, 58),
                placeName: "公司"
            ),
            LocationVisit(
                coordinate: cafeCoordinate,
                arrivalDate: time(12, 3),
                departureDate: time(12, 56),
                placeName: "附近餐厅"
            ),
            LocationVisit(
                coordinate: officeCoordinate,
                arrivalDate: time(13, 4),
                departureDate: time(13, 58),
                placeName: "公司"
            ),
            LocationVisit(
                coordinate: trailCoordinate,
                arrivalDate: time(14, 0),
                departureDate: time(14, 45),
                placeName: "河滨步道"
            ),
            LocationVisit(
                coordinate: officeCoordinate,
                arrivalDate: time(14, 50),
                departureDate: time(17, 28),
                placeName: "公司"
            ),
            LocationVisit(
                coordinate: CoordinateValue(latitude: 39.9340, longitude: 116.3750),
                arrivalDate: time(17, 32),
                departureDate: time(17, 58),
                placeName: "回家路上"
            ),
            LocationVisit(
                coordinate: homeCoordinate,
                arrivalDate: time(18, 0),
                departureDate: time(24, 0),
                placeName: "家"
            )
        ]

        let hourlyWeather = [
            HourlyWeather(date: time(7, 0), temperature: 20, condition: .clear, symbolName: "sunrise.fill"),
            HourlyWeather(date: time(8, 0), temperature: 22, condition: .clear, symbolName: "sun.max.fill"),
            HourlyWeather(date: time(12, 0), temperature: 25, condition: .clear, symbolName: "sun.max.fill"),
            HourlyWeather(date: time(14, 0), temperature: 27, condition: .clear, symbolName: "sun.max.fill"),
            HourlyWeather(date: time(17, 0), temperature: 24, condition: .cloudy, symbolName: "cloud.sun.fill"),
            HourlyWeather(date: time(20, 0), temperature: 21, condition: .cloudy, symbolName: "cloud.moon.fill"),
            HourlyWeather(date: time(22, 0), temperature: 18, condition: .clear, symbolName: "moon.stars.fill")
        ]

        let photos = [
            PhotoReference(
                id: "mock.photo.lunch.1",
                creationDate: time(12, 18),
                location: cafeCoordinate,
                pixelWidth: 1_280,
                pixelHeight: 960
            ),
            PhotoReference(
                id: "mock.photo.run.1",
                creationDate: time(14, 16),
                location: trailCoordinate,
                pixelWidth: 1_440,
                pixelHeight: 1_080
            ),
            PhotoReference(
                id: "mock.photo.run.2",
                creationDate: time(14, 39),
                location: trailCoordinate,
                pixelWidth: 1_440,
                pixelHeight: 1_080
            )
        ]

        return DayRawData(
            date: date,
            activitySummary: ActivitySummaryData(
                activeEnergyBurned: 540,
                activeEnergyGoal: 600,
                exerciseMinutes: 46,
                exerciseGoal: 30,
                standHours: 10,
                standGoal: 12
            ),
            hourlyWeather: hourlyWeather,
            locationVisits: locationVisits,
            photos: photos,
            heartRateSamples: heartRateSamples,
            stepSamples: stepSamples,
            sleepSamples: sleepSamples,
            workouts: workouts,
            activeEnergySamples: activeEnergySamples,
            moodRecords: moodRecords
        )
    }

    private func makeStats(from rawData: DayRawData) -> [TimelineStat] {
        guard let activitySummary = rawData.activitySummary else {
            return [
                TimelineStat(title: "模式", value: "模拟"),
                TimelineStat(title: "天气", value: "已接入"),
                TimelineStat(title: "照片", value: "\(rawData.photos.count)")
            ]
        }

        return [
            TimelineStat(
                title: "活动",
                value: "\(formatWholeNumber(activitySummary.activeEnergyBurned))/\(formatWholeNumber(activitySummary.activeEnergyGoal)) 千卡"
            ),
            TimelineStat(
                title: "锻炼",
                value: "\(formatWholeNumber(activitySummary.exerciseMinutes))/\(formatWholeNumber(activitySummary.exerciseGoal)) 分钟"
            ),
            TimelineStat(
                title: "站立",
                value: "\(activitySummary.standHours)/\(activitySummary.standGoal) 小时"
            )
        ]
    }

    private func makeSamples(
        from values: [(Int, Int, Double)],
        on startOfDay: Date,
        durationMinutes: Int = 5
    ) -> [DateValueSample] {
        values.map { hour, minute, value in
            let startDate = calendar.date(
                byAdding: .minute,
                value: (hour * 60) + minute,
                to: startOfDay
            ) ?? startOfDay
            let endDate = calendar.date(byAdding: .minute, value: durationMinutes, to: startDate) ?? startDate
            return DateValueSample(startDate: startDate, endDate: endDate, value: value)
        }
    }

    private func formatWholeNumber(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }
}
