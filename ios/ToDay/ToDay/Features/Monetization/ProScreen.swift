import SwiftUI

struct ProScreen: View {
    @ObservedObject var monetizationViewModel: MonetizationViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroCard
                    storeStatusSection
                    planSection
                    featureSection
                    supportSection
                    footerSection
                }
                .padding(.vertical, 20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("会员")
        }
        .task {
            await monetizationViewModel.prepareStore()
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(heroTitle)
                    .font(.title2.weight(.bold))

                Spacer()

                Text(heroBadge)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.75))
                    .clipShape(Capsule())
            }

            Text(heroDetail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.90, blue: 0.82), Color(red: 0.87, green: 0.93, blue: 0.89)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 20)
    }

    private var storeStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("当前状态")
                    .font(.title3.weight(.semibold))

                Spacer()

                if monetizationViewModel.isLoadingStore {
                    ProgressView()
                }
            }

            Text(storeSummaryText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let storeMessage = monetizationViewModel.storeMessage {
                statusPill(text: storeMessage)
            }

            if let purchaseMessage = monetizationViewModel.purchaseMessage {
                statusPill(text: purchaseMessage)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 20)
    }

    private var planSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("订阅方案")
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 20)

            VStack(spacing: 12) {
                ForEach(MonetizationViewModel.Plan.allCases) { plan in
                    Button {
                        monetizationViewModel.selectedPlan = plan
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Text(plan.title)
                                        .font(.headline)

                                    if let badge = plan.badge {
                                        Text(badge)
                                            .font(.caption.weight(.bold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color(red: 0.95, green: 0.90, blue: 0.82))
                                            .clipShape(Capsule())
                                    }
                                }

                                Text(monetizationViewModel.priceLabel(for: plan))
                                    .font(.title3.weight(.bold))

                                Text(plan.helperText)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: monetizationViewModel.selectedPlan == plan ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(
                                    monetizationViewModel.selectedPlan == plan
                                        ? Color(red: 0.35, green: 0.63, blue: 0.54)
                                        : .secondary
                                )
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(
                                    monetizationViewModel.selectedPlan == plan
                                        ? Color(red: 0.35, green: 0.63, blue: 0.54)
                                        : Color.clear,
                                    lineWidth: 2
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            Button {
                Task {
                    await monetizationViewModel.purchaseSelectedPlan()
                }
            } label: {
                Text(monetizationViewModel.purchaseButtonTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.35, green: 0.63, blue: 0.54))
            .disabled(monetizationViewModel.selectedPlanProduct == nil || monetizationViewModel.isPurchasing)
            .padding(.horizontal, 20)

            Button {
                Task {
                    await monetizationViewModel.restorePurchases()
                }
            } label: {
                Text(monetizationViewModel.isRestoring ? "正在恢复购买..." : "恢复购买")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(monetizationViewModel.isRestoring)
            .padding(.horizontal, 20)

            if monetizationViewModel.shouldShowPreviewUnlock {
                Button {
                    monetizationViewModel.unlockPreviewPro()
                } label: {
                    Text(monetizationViewModel.isPreviewUnlocked ? "保持当前预览版已解锁" : "解锁 Pro 预览版")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal, 20)

                if monetizationViewModel.isPreviewUnlocked {
                    Button("关闭预览版解锁") {
                        monetizationViewModel.resetPreviewPro()
                    }
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private var featureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pro 能力")
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 20)

            VStack(spacing: 12) {
                ProFeatureCard(
                    title: "最近 7 天连续洞察",
                    detail: "把零散的记录整理成节奏、状态和趋势，而不只是单日卡片。"
                )
                ProFeatureCard(
                    title: "完整历史回看",
                    detail: "免费版先开放最近 3 天，Pro 才像真正能长期使用的记录工具。"
                )
                ProFeatureCard(
                    title: "未来的同步与网页端",
                    detail: "后续账号、同步、网页端回看会优先落到 Pro 路线里。"
                )
            }
            .padding(.horizontal, 20)
        }
    }

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("上线前配置")
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 20)

            VStack(spacing: 12) {
                LaunchReadinessCard(
                    title: "支持邮箱",
                    value: AppConfiguration.supportEmail ?? "待配置",
                    detail: AppConfiguration.supportEmail == nil ? "建议尽快替换成品牌域名邮箱，例如 support@yourdomain.com。" : "已配置，可用于购买问题和用户反馈。"
                )

                LaunchReadinessCard(
                    title: "隐私政策",
                    value: AppConfiguration.privacyPolicyURL?.absoluteString ?? "待配置",
                    detail: AppConfiguration.privacyPolicyURL == nil ? "Health 数据、记录数据和订阅说明都需要明确写进隐私政策。" : "已配置，可直接用于上架资料。"
                )

                LaunchReadinessCard(
                    title: "服务条款",
                    value: AppConfiguration.termsOfServiceURL?.absoluteString ?? "待配置",
                    detail: AppConfiguration.termsOfServiceURL == nil ? "订阅类产品建议同时准备服务条款，后续网页端也能复用。" : "已配置，可直接用于订阅页或官网。"
                )

                LaunchReadinessCard(
                    title: "官网 / 支持页",
                    value: AppConfiguration.websiteURL?.absoluteString ?? "待配置",
                    detail: AppConfiguration.websiteURL == nil ? "建议先做官网首页、支持页和 FAQ，后续再扩展网页端能力。" : "已配置，可承接品牌和帮助文档。"
                )
            }
            .padding(.horizontal, 20)
        }
    }

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("说明")
                .font(.headline)

            Text("当前版本已经接入真实的 StoreKit 2 购买与恢复骨架，但正式订阅还需要你在 App Store Connect 创建对应商品。商品 ID 已预留为 com.looanli.today.pro.monthly 和 com.looanli.today.pro.yearly。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 20)
    }

    private func statusPill(text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.78))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var heroTitle: String {
        if monetizationViewModel.hasActiveSubscription {
            return "你已经启用了 ToDay Pro"
        }

        if monetizationViewModel.isPreviewUnlocked {
            return "Pro 预览版已启用"
        }

        return "把 ToDay 变成长期陪你的产品"
    }

    private var heroBadge: String {
        if monetizationViewModel.hasActiveSubscription {
            return "已购买"
        }

        if monetizationViewModel.isPreviewUnlocked {
            return "预览版"
        }

        return "首发价"
    }

    private var heroDetail: String {
        if monetizationViewModel.hasActiveSubscription {
            return "当前设备已经检测到有效会员资格，完整回看和连续洞察已经解锁。"
        }

        if monetizationViewModel.isPreviewUnlocked {
            return "你现在看到的是 Pro 的本地预览版，用来验证付费路径、历史解锁和产品结构。"
        }

        return "免费版先让用户看到价值，Pro 再卖更高质量的回看、趋势和连续洞察。"
    }

    private var storeSummaryText: String {
        if monetizationViewModel.hasActiveSubscription {
            return "已检测到真实会员资格。后续只需要补齐 App Store Connect 商品和上架素材。"
        }

        if monetizationViewModel.selectedPlanProduct != nil {
            return "当前环境已经返回真实商品信息，购买和恢复按钮都已接上 StoreKit 2。"
        }

        if monetizationViewModel.isLoadingStore {
            return "正在连接 App Store 商品配置。"
        }

        return "当前仍以本地预览为主，但购买状态机和商品 ID 已经接好。"
    }
}

private struct ProFeatureCard: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct LaunchReadinessCard: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Text(value)
                .font(.subheadline.weight(.medium))

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
