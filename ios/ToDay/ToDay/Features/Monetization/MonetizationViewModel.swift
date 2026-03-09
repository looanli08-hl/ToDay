import Foundation
import StoreKit

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

        var productID: String {
            switch self {
            case .monthly:
                return "com.looanli.today.pro.monthly"
            case .yearly:
                return "com.looanli.today.pro.yearly"
            }
        }

        var fallbackPriceLabel: String {
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

        var cycleLabel: String {
            switch self {
            case .monthly:
                return "月"
            case .yearly:
                return "年"
            }
        }

        init?(productID: String) {
            self = Self.allCases.first { $0.productID == productID } ?? .yearly

            guard self.productID == productID else {
                return nil
            }
        }
    }

    @Published private(set) var isProUnlocked = false
    @Published private(set) var hasActiveSubscription = false
    @Published private(set) var isPreviewUnlocked = false
    @Published private(set) var productsByPlan: [Plan: Product] = [:]
    @Published private(set) var isLoadingStore = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRestoring = false
    @Published private(set) var purchaseMessage: String?
    @Published private(set) var storeMessage: String?
    @Published var selectedPlan: Plan

    let freeHistoryLimit = 3

    private let defaults: UserDefaults
    private let key: String
    private var updatesTask: Task<Void, Never>?
    private var hasPreparedStore = false

    init(
        defaults: UserDefaults = .standard,
        key: String = "today.previewProUnlocked",
        selectedPlan: Plan = .yearly
    ) {
        self.defaults = defaults
        self.key = key
        self.selectedPlan = selectedPlan
        self.isPreviewUnlocked = defaults.bool(forKey: key)
        syncUnlockState()
    }

    deinit {
        updatesTask?.cancel()
    }

    var selectedPlanProduct: Product? {
        productsByPlan[selectedPlan]
    }

    var shouldShowPreviewUnlock: Bool {
        !hasActiveSubscription
    }

    var purchaseButtonTitle: String {
        if isPurchasing {
            return "正在发起购买..."
        }

        if let product = selectedPlanProduct {
            return "继续购买 \(product.displayPrice) / \(selectedPlan.cycleLabel)"
        }

        return "当前环境还未接入真实购买"
    }

    func priceLabel(for plan: Plan) -> String {
        if let product = productsByPlan[plan] {
            return "\(product.displayPrice) / \(plan.cycleLabel)"
        }

        return plan.fallbackPriceLabel
    }

    func prepareStore() async {
        startObservingTransactionsIfNeeded()
        await refreshEntitlementState()

        guard !hasPreparedStore else { return }

        isLoadingStore = true
        defer { isLoadingStore = false }

        do {
            let productIDs = Plan.allCases.map(\.productID)
            let products = try await Product.products(for: productIDs)
            productsByPlan = Dictionary(
                uniqueKeysWithValues: products.compactMap { product in
                    guard let plan = Plan(productID: product.id) else { return nil }
                    return (plan, product)
                }
            )
            if productsByPlan.isEmpty {
                storeMessage = "当前环境还没有返回真实订阅商品，先用预览版继续验证产品和转化路径。"
            } else {
                storeMessage = "会员商品已连上 App Store 商品配置，后续可以直接接入正式购买。"
            }
        } catch {
            storeMessage = "暂时无法连接 App Store 商品，当前先保留本地预览模式。"
        }

        hasPreparedStore = true
    }

    func purchaseSelectedPlan() async {
        purchaseMessage = nil

        guard let product = selectedPlanProduct else {
            purchaseMessage = "当前环境还没有真实订阅商品。你可以先解锁预览版继续验证产品。"
            return
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verify(verification)
                await transaction.finish()
                await refreshEntitlementState()
                purchaseMessage = "购买成功，Pro 已启用。"
            case .pending:
                purchaseMessage = "购买正在等待系统确认。"
            case .userCancelled:
                purchaseMessage = "你已取消本次购买。"
            @unknown default:
                purchaseMessage = "购买结果暂时无法识别。"
            }
        } catch {
            purchaseMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        purchaseMessage = nil
        isRestoring = true
        defer { isRestoring = false }

        do {
            try await AppStore.sync()
            await refreshEntitlementState()
            purchaseMessage = hasActiveSubscription ? "已恢复你现有的会员资格。" : "没有发现可恢复的有效会员。"
        } catch {
            purchaseMessage = "恢复购买失败：\(error.localizedDescription)"
        }
    }

    func unlockPreviewPro() {
        isPreviewUnlocked = true
        defaults.set(true, forKey: key)
        purchaseMessage = "已启用 Pro 本地预览版。"
        syncUnlockState()
    }

    func resetPreviewPro() {
        isPreviewUnlocked = false
        defaults.set(false, forKey: key)
        if !hasActiveSubscription {
            purchaseMessage = "已关闭预览版解锁。"
        }
        syncUnlockState()
    }

    private func startObservingTransactionsIfNeeded() {
        guard updatesTask == nil else { return }

        updatesTask = Task { [weak self] in
            guard let self else { return }

            for await update in Transaction.updates {
                do {
                    let transaction = try self.verify(update)
                    guard Plan(productID: transaction.productID) != nil else { continue }
                    await transaction.finish()
                    await self.refreshEntitlementState()
                    await MainActor.run {
                        self.purchaseMessage = "会员状态已自动更新。"
                    }
                } catch {
                    await MainActor.run {
                        self.purchaseMessage = "检测到未验证的交易，当前没有更新会员状态。"
                    }
                }
            }
        }
    }

    private func refreshEntitlementState() async {
        var unlocked = false

        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            guard Plan(productID: transaction.productID) != nil else { continue }
            guard transaction.revocationDate == nil else { continue }

            if let expirationDate = transaction.expirationDate, expirationDate < Date() {
                continue
            }

            unlocked = true
            break
        }

        hasActiveSubscription = unlocked
        syncUnlockState()
    }

    private func syncUnlockState() {
        isProUnlocked = hasActiveSubscription || isPreviewUnlocked
    }

    private func verify<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw StoreError.failedVerification
        }
    }
}

private enum StoreError: LocalizedError {
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "交易没有通过系统验证。"
        }
    }
}
