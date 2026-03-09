import SwiftUI

struct ProScreen: View {
    @ObservedObject var monetizationViewModel: MonetizationViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroCard
                    planSection
                    featureSection
                    footerSection
                }
                .padding(.vertical, 20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("会员")
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(monetizationViewModel.isProUnlocked ? "Pro 预览版已启用" : "把 ToDay 变成长期陪你的产品")
                    .font(.title2.weight(.bold))

                Spacer()

                Text(monetizationViewModel.isProUnlocked ? "已解锁" : "首发价")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.75))
                    .clipShape(Capsule())
            }

            Text(
                monetizationViewModel.isProUnlocked
                    ? "你现在看到的是 Pro 付费路径的本地预览版，用来验证产品结构和转化感。"
                    : "免费版先让用户看到价值，Pro 再卖更高质量的回看、趋势和连续洞察。"
            )
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

                                Text(plan.priceLabel)
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
                monetizationViewModel.unlockPreviewPro()
            } label: {
                Text(monetizationViewModel.isProUnlocked ? "保持当前预览版已解锁" : "解锁 Pro 预览版")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.35, green: 0.63, blue: 0.54))
            .padding(.horizontal, 20)

            if monetizationViewModel.isProUnlocked {
                Button("重置预览版状态") {
                    monetizationViewModel.resetPreviewPro()
                }
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 20)
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

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("说明")
                .font(.headline)

            Text("当前版本先做付费路径验证，正式购买会在接入 App Store Connect 与真实内购后启用。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 20)
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
