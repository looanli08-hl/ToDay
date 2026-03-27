import Foundation

protocol TimelineDataProviding {
    var source: TimelineSource { get }
    func loadTimeline(for date: Date) async throws -> DayTimeline
}

enum TimelineDataError: LocalizedError {
    case healthDataUnavailable
    case authorizationDenied
    case noDataForToday
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            return "这台设备暂时无法使用健康数据，先继续用模拟模式把产品打磨顺。"
        case .authorizationDenied:
            return "健康数据授权被拒绝了，但你仍然可以继续用本地记录和模拟数据。"
        case .noDataForToday:
            return "今天还没有可见的健康数据样本。"
        case let .queryFailed(message):
            return "HealthKit 查询失败：\(message)"
        }
    }
}
