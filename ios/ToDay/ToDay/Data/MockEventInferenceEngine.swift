import Foundation

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

        return [
            InferredEvent(
                kind: .sleep,
                startDate: time(0, 0),
                endDate: time(7, 0),
                confidence: .high,
                displayName: "睡眠",
                subtitle: "深睡 2h, 浅睡 3h, REM 1.5h",
                associatedMetrics: EventMetrics(
                    averageHeartRate: 56,
                    maxHeartRate: 68,
                    minHeartRate: 48,
                    heartRateSamples: mockHeartRateSamples(from: time(0, 0), to: time(7, 0), values: [52, 55, 57, 60]),
                    stepCount: 12,
                    activeEnergy: 40,
                    distance: nil,
                    workoutType: nil
                )
            ),
            InferredEvent(
                kind: .quietTime,
                startDate: time(7, 0),
                endDate: time(7, 30),
                confidence: .low,
                displayName: "安静时光",
                associatedMetrics: EventMetrics(
                    averageHeartRate: 64,
                    maxHeartRate: 70,
                    minHeartRate: 58,
                    heartRateSamples: mockHeartRateSamples(from: time(7, 0), to: time(7, 30), values: [62, 64, 66]),
                    stepCount: 18,
                    activeEnergy: 16,
                    distance: nil,
                    workoutType: nil
                )
            ),
            InferredEvent(
                kind: .commute,
                startDate: time(7, 30),
                endDate: time(8, 0),
                confidence: .medium,
                displayName: "步行通勤",
                subtitle: "早晨通勤",
                associatedMetrics: EventMetrics(
                    averageHeartRate: 88,
                    maxHeartRate: 110,
                    minHeartRate: 74,
                    heartRateSamples: mockHeartRateSamples(from: time(7, 30), to: time(8, 0), values: [80, 86, 92, 96]),
                    stepCount: 2600,
                    activeEnergy: 110,
                    distance: 1800,
                    workoutType: nil
                )
            ),
            InferredEvent(
                kind: .quietTime,
                startDate: time(8, 0),
                endDate: time(12, 0),
                confidence: .low,
                displayName: "安静的上午",
                associatedMetrics: EventMetrics(
                    averageHeartRate: 68,
                    maxHeartRate: 78,
                    minHeartRate: 60,
                    heartRateSamples: mockHeartRateSamples(from: time(8, 0), to: time(12, 0), values: [66, 69, 67, 70]),
                    stepCount: 420,
                    activeEnergy: 90,
                    distance: nil,
                    workoutType: nil
                )
            ),
            InferredEvent(
                kind: .mood,
                startDate: time(9, 30),
                endDate: time(9, 30),
                confidence: .high,
                displayName: "心情：专注",
                photoAttachments: []
            ),
            InferredEvent(
                kind: .quietTime,
                startDate: time(12, 0),
                endDate: time(13, 0),
                confidence: .low,
                displayName: "午间时光",
                associatedMetrics: EventMetrics(
                    averageHeartRate: 71,
                    maxHeartRate: 82,
                    minHeartRate: 63,
                    heartRateSamples: mockHeartRateSamples(from: time(12, 0), to: time(13, 0), values: [68, 72, 75]),
                    stepCount: 240,
                    activeEnergy: 62,
                    distance: nil,
                    workoutType: nil
                )
            ),
            InferredEvent(
                kind: .quietTime,
                startDate: time(13, 0),
                endDate: time(14, 0),
                confidence: .low,
                displayName: "安静的下午",
                associatedMetrics: EventMetrics(
                    averageHeartRate: 67,
                    maxHeartRate: 74,
                    minHeartRate: 61,
                    heartRateSamples: mockHeartRateSamples(from: time(13, 0), to: time(14, 0), values: [65, 67, 69]),
                    stepCount: 120,
                    activeEnergy: 36,
                    distance: nil,
                    workoutType: nil
                )
            ),
            InferredEvent(
                kind: .workout,
                startDate: time(14, 0),
                endDate: time(14, 45),
                confidence: .high,
                displayName: "跑步",
                subtitle: "45 分钟 · 5.2 km",
                associatedMetrics: EventMetrics(
                    averageHeartRate: 138,
                    maxHeartRate: 162,
                    minHeartRate: 112,
                    heartRateSamples: mockHeartRateSamples(from: time(14, 0), to: time(14, 45), values: [124, 136, 148, 156]),
                    stepCount: 5400,
                    activeEnergy: 430,
                    distance: 5200,
                    workoutType: "跑步"
                )
            ),
            InferredEvent(
                kind: .quietTime,
                startDate: time(14, 45),
                endDate: time(17, 30),
                confidence: .low,
                displayName: "安静的下午",
                associatedMetrics: EventMetrics(
                    averageHeartRate: 73,
                    maxHeartRate: 82,
                    minHeartRate: 64,
                    heartRateSamples: mockHeartRateSamples(from: time(14, 45), to: time(17, 30), values: [70, 72, 75, 74]),
                    stepCount: 360,
                    activeEnergy: 88,
                    distance: nil,
                    workoutType: nil
                )
            ),
            InferredEvent(
                kind: .commute,
                startDate: time(17, 30),
                endDate: time(18, 0),
                confidence: .medium,
                displayName: "步行通勤",
                subtitle: "傍晚返程",
                associatedMetrics: EventMetrics(
                    averageHeartRate: 92,
                    maxHeartRate: 116,
                    minHeartRate: 78,
                    heartRateSamples: mockHeartRateSamples(from: time(17, 30), to: time(18, 0), values: [84, 90, 96, 100]),
                    stepCount: 2800,
                    activeEnergy: 122,
                    distance: 1900,
                    workoutType: nil
                )
            ),
            InferredEvent(
                kind: .quietTime,
                startDate: time(18, 0),
                endDate: time(22, 0),
                confidence: .low,
                displayName: "安静的夜晚",
                associatedMetrics: EventMetrics(
                    averageHeartRate: 70,
                    maxHeartRate: 79,
                    minHeartRate: 61,
                    heartRateSamples: mockHeartRateSamples(from: time(18, 0), to: time(22, 0), values: [68, 71, 73, 69]),
                    stepCount: 220,
                    activeEnergy: 58,
                    distance: nil,
                    workoutType: nil
                )
            ),
            InferredEvent(
                kind: .mood,
                startDate: time(20, 0),
                endDate: time(20, 0),
                confidence: .high,
                displayName: "心情：平静",
                photoAttachments: []
            )
        ]
    }

    private func mockHeartRateSamples(from startDate: Date, to endDate: Date, values: [Double]) -> [(date: Date, value: Double)] {
        guard !values.isEmpty else { return [] }
        let step = endDate.timeIntervalSince(startDate) / Double(values.count + 1)
        return values.enumerated().map { index, value in
            (date: startDate.addingTimeInterval(step * Double(index + 1)), value: value)
        }
    }
}
