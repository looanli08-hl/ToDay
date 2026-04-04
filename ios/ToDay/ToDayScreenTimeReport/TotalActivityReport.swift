import DeviceActivity
import SwiftUI

@available(iOS 16.0, *)
struct TotalActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .init(rawValue: "TotalActivity")

    let content: (ActivityReport) -> TotalActivityView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ActivityReport {
        var categoryUsages: [CategoryUsage] = []
        var totalDuration: TimeInterval = 0

        for await activityData in data {
            for await categoryActivity in activityData.activitySegments {
                for await category in categoryActivity.categories {
                    let duration = category.totalActivityDuration
                    totalDuration += duration
                    let name = category.category.localizedDisplayName ?? "其他"
                    categoryUsages.append(CategoryUsage(name: name, duration: duration))
                }
            }
        }

        // Sort by duration descending
        categoryUsages.sort { $0.duration > $1.duration }

        // Write summary to shared UserDefaults for main app to read
        let summary = ScreenTimeSummary(
            date: Date(),
            totalDuration: totalDuration,
            categories: categoryUsages
        )
        if let data = try? JSONEncoder().encode(summary) {
            UserDefaults(suiteName: "group.com.looanli.today")?
                .set(data, forKey: "today.screenTime.summary")
        }

        return ActivityReport(totalDuration: totalDuration, categories: categoryUsages)
    }
}

struct ActivityReport {
    let totalDuration: TimeInterval
    let categories: [CategoryUsage]
}

struct CategoryUsage: Codable, Identifiable {
    var id: String { name }
    let name: String
    let duration: TimeInterval

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    var icon: String {
        switch name.lowercased() {
        case let n where n.contains("social") || n.contains("社交"): return "bubble.left.and.bubble.right.fill"
        case let n where n.contains("game") || n.contains("游戏"): return "gamecontroller.fill"
        case let n where n.contains("entertainment") || n.contains("娱乐"): return "film.fill"
        case let n where n.contains("productivity") || n.contains("效率"): return "doc.text.fill"
        case let n where n.contains("education") || n.contains("教育"): return "book.fill"
        case let n where n.contains("reading") || n.contains("阅读"): return "book.fill"
        default: return "app.fill"
        }
    }
}

struct ScreenTimeSummary: Codable {
    let date: Date
    let totalDuration: TimeInterval
    let categories: [CategoryUsage]
}

@available(iOS 16.0, *)
struct TotalActivityView: View {
    let report: ActivityReport

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Total
            HStack {
                Text("今日屏幕时间")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formattedTotal)
                    .font(.title2.bold())
            }

            if !report.categories.isEmpty {
                Divider()

                // Per-category breakdown
                ForEach(report.categories.prefix(5)) { category in
                    HStack(spacing: 10) {
                        Image(systemName: category.icon)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(width: 24)

                        Text(category.name)
                            .font(.subheadline)

                        Spacer()

                        Text(category.formattedDuration)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
    }

    private var formattedTotal: String {
        let hours = Int(report.totalDuration) / 3600
        let minutes = (Int(report.totalDuration) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
