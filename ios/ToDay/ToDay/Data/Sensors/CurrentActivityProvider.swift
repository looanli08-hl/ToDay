import CoreMotion
import Foundation

/// Provides a human-readable description of the user's current activity
/// by querying the most recent sensor readings.
final class CurrentActivityProvider: ObservableObject {
    @Published var statusText: String = ""
    @Published var statusIcon: String = "circle.fill"

    private let activityManager = CMMotionActivityManager()
    private let pedometer = CMPedometer()

    func refresh() {
        guard CMMotionActivityManager.isActivityAvailable() else {
            statusText = ""
            return
        }

        let now = Date()
        let fiveMinAgo = now.addingTimeInterval(-300)

        activityManager.queryActivityStarting(from: fiveMinAgo, to: now, to: .main) { [weak self] activities, _ in
            guard let self, let last = activities?.last else { return }

            let startOfDay = Calendar.current.startOfDay(for: now)
            self.pedometer.queryPedometerData(from: startOfDay, to: now) { data, _ in
                let steps = data?.numberOfSteps.intValue ?? 0
                DispatchQueue.main.async {
                    self.updateStatus(activity: last, todaySteps: steps)
                }
            }
        }
    }

    private func updateStatus(activity: CMMotionActivity, todaySteps: Int) {
        let stepsText = todaySteps > 0 ? " · 今日 \(todaySteps) 步" : ""

        if activity.running {
            statusIcon = "figure.run"
            statusText = "正在跑步" + stepsText
        } else if activity.cycling {
            statusIcon = "figure.outdoor.cycle"
            statusText = "正在骑行"
        } else if activity.automotive {
            statusIcon = "car.fill"
            statusText = "正在出行"
        } else if activity.walking {
            statusIcon = "figure.walk"
            statusText = "正在步行" + stepsText
        } else if activity.stationary {
            statusIcon = "circle.fill"
            statusText = todaySteps > 0 ? "静止中 · 今日 \(todaySteps) 步" : "静止中"
        } else {
            statusIcon = "circle.fill"
            statusText = todaySteps > 0 ? "今日 \(todaySteps) 步" : ""
        }
    }
}
