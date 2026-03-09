import SwiftUI

struct HistoryScreen: View {
    @ObservedObject var viewModel: TodayViewModel
    @ObservedObject var monetizationViewModel: MonetizationViewModel

    let onOpenPro: () -> Void

    private let chineseLocale = Locale(identifier: "zh_CN")

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    weeklyInsightSection
                    historySection
                }
                .padding(.vertical, 20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("回看")
        }
    }

    @ViewBuilder
    private var weeklyInsightSection: some View {
        if let insight = viewModel.weeklyInsight {
            if monetizationViewModel.isProUnlocked {
                VStack(alignment: .leading, spacing: 12) {
                    Text("最近 7 天连续洞察")
                        .font(.title3.weight(.semibold))

                    Text(insight.headline)
                        .font(.headline)

                    Text(insight.narrative)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HistoryBadgeRow(items: insight.badges)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.92, green: 0.96, blue: 0.92), Color(red: 0.84, green: 0.92, blue: 0.88)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal, 20)
            } else {
                LockedInsightCard(
                    title: "最近 7 天连续洞察",
                    detail: "免费版先开放今天的自动总结，Pro 解锁更完整的周洞察、趋势和状态变化。",
                    buttonTitle: "前往会员页",
                    action: onOpenPro
                )
            }
        }
    }

    @ViewBuilder
    private var historySection: some View {
        if viewModel.historyDigests.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("还没有可回看的历史")
                    .font(.title3.weight(.semibold))

                Text("先在“今天”页留下几条记录，回看页才会开始长出真正的连续感。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 20)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("历史记录")
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 20)

                VStack(spacing: 12) {
                    ForEach(visibleDigests) { digest in
                        HistoryDayCard(digest: digest, locale: chineseLocale)
                    }
                }
                .padding(.horizontal, 20)

                if lockedCount > 0 && !monetizationViewModel.isProUnlocked {
                    LockedInsightCard(
                        title: "还有 \(lockedCount) 天回看被锁定",
                        detail: "免费版先开放最近 \(monetizationViewModel.freeHistoryLimit) 天。Pro 解锁完整历史、长期回看和未来的多端同步。",
                        buttonTitle: "解锁完整回看",
                        action: onOpenPro
                    )
                }
            }
        }
    }

    private var visibleDigests: [RecentDayDigest] {
        if monetizationViewModel.isProUnlocked {
            return viewModel.historyDigests
        }

        return Array(viewModel.historyDigests.prefix(monetizationViewModel.freeHistoryLimit))
    }

    private var lockedCount: Int {
        max(viewModel.historyDigests.count - visibleDigests.count, 0)
    }
}

private struct HistoryDayCard: View {
    let digest: RecentDayDigest
    let locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 10) {
                    Circle()
                        .fill(color)
                        .frame(width: 12, height: 12)

                    Text(digest.title)
                        .font(.headline)
                }

                Spacer()

                Text(digest.date.formatted(.dateTime.month(.abbreviated).day().weekday(.abbreviated).locale(locale)))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text(digest.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let notePreview = digest.notePreview {
                Text("“\(notePreview)”")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.78))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var color: Color {
        switch digest.mood {
        case .happy:
            return Color(red: 0.96, green: 0.77, blue: 0.39)
        case .calm:
            return Color(red: 0.35, green: 0.63, blue: 0.54)
        case .tired:
            return Color(red: 0.43, green: 0.54, blue: 0.80)
        case .irritated:
            return Color(red: 0.84, green: 0.49, blue: 0.43)
        case .focused:
            return Color(red: 0.28, green: 0.54, blue: 0.47)
        case .zoning:
            return Color(red: 0.74, green: 0.66, blue: 0.57)
        case .none:
            return Color(red: 0.74, green: 0.66, blue: 0.57)
        }
    }
}

private struct LockedInsightCard: View {
    let title: String
    let detail: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("Pro")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.94, green: 0.88, blue: 0.78))
                    .clipShape(Capsule())
            }

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button(buttonTitle, action: action)
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.35, green: 0.63, blue: 0.54))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 20)
    }
}

private struct HistoryBadgeRow: View {
    let items: [String]

    var body: some View {
        ViewThatFits(in: .vertical) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    badge(item)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    badge(item)
                }
            }
        }
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.8))
            .clipShape(Capsule())
    }
}
