import Foundation

@MainActor
final class MonetizationViewModel: ObservableObject {
    enum Plan: String, CaseIterable, Identifiable {
        case monthly
        case yearly

        var id: String { rawValue }

        var title: String {
            switch self {
            case .monthly:
                return "月度"
            case .yearly:
                return "年度"
            }
        }

        var priceLabel: String {
            switch self {
            case .monthly:
                return "￥18 / 月"
            case .yearly:
                return "￥128 / 年"
            }
        }

        var helperText: String {
            switch self {
            case .monthly:
                return "适合先试一段时间"
            case .yearly:
                return "更适合长期记录者"
            }
        }

        var badge: String? {
            switch self {
            case .monthly:
                return nil
            case .yearly:
                return "推荐"
            }
        }
    }

    @Published private(set) var isProUnlocked: Bool
    @Published var selectedPlan: Plan

    let freeHistoryLimit = 3

    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "today.previewProUnlocked",
        selectedPlan: Plan = .yearly
    ) {
        self.defaults = defaults
        self.key = key
        self.selectedPlan = selectedPlan
        self.isProUnlocked = defaults.bool(forKey: key)
    }

    func unlockPreviewPro() {
        isProUnlocked = true
        defaults.set(true, forKey: key)
    }

    func resetPreviewPro() {
        isProUnlocked = false
        defaults.set(false, forKey: key)
    }
}
