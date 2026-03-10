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
            .background(TodayTheme.background)
            .navigationTitle("回看")
        }
    }

    @ViewBuilder
    private var weeklyInsightSection: some View {
        if let insight = viewModel.weeklyInsight {
            if monetizationViewModel.isProUnlocked {
                ContentCard(background: TodayTheme.tealSoft.opacity(0.72)) {
                    EyebrowLabel("WEEKLY RHYTHM")

                    Text("最近 7 天连续洞察")
                        .font(.system(size: 23, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(TodayTheme.ink)

                    Text(insight.headline)
                        .font(.headline)
                        .foregroundStyle(TodayTheme.inkSoft)

                    Text(insight.narrative)
                        .font(.subheadline)
                        .foregroundStyle(TodayTheme.inkMuted)
                        .lineSpacing(4)

                    HistoryBadgeRow(items: insight.badges)
                }
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
            ContentCard {
                EyebrowLabel("EMPTY")

                Text("还没有可回看的历史")
                    .font(.system(size: 23, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(TodayTheme.ink)

                Text("先在“今天”页留下几条记录，回看页才会开始长出真正的连续感。")
                    .font(.subheadline)
                    .foregroundStyle(TodayTheme.inkMuted)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 20)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("历史记录")
                    .font(.system(size: 23, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(TodayTheme.ink)
                    .padding(.horizontal, 20)

                VStack(spacing: 12) {
                    ForEach(visibleDigests) { digest in
                        if let detail = viewModel.historyDetail(for: digest.date) {
                            NavigationLink {
                                HistoryDayDetailScreen(detail: detail)
                            } label: {
                                HistoryDayCard(digest: digest, locale: chineseLocale)
                            }
                            .buttonStyle(.plain)
                        } else {
                            HistoryDayCard(digest: digest, locale: chineseLocale)
                        }
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
                    .foregroundStyle(TodayTheme.inkMuted)
            }

            Text(digest.detail)
                .font(.subheadline)
                .foregroundStyle(TodayTheme.inkMuted)

            if let notePreview = digest.notePreview {
                Text("“\(notePreview)”")
                    .font(.subheadline)
                    .foregroundStyle(TodayTheme.inkSoft)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(TodayTheme.elevatedCard.opacity(0.72))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TodayTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(TodayTheme.border, lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(TodayTheme.inkMuted)
                .padding(18)
        }
    }

    private var color: Color {
        switch digest.mood {
        case .happy:
            return TodayTheme.accent
        case .calm:
            return TodayTheme.teal
        case .tired:
            return TodayTheme.blue
        case .irritated:
            return TodayTheme.rose
        case .focused:
            return TodayTheme.teal
        case .zoning:
            return TodayTheme.inkFaint
        case .none:
            return TodayTheme.inkFaint
        }
    }
}

private struct LockedInsightCard: View {
    let title: String
    let detail: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        ContentCard {
            EyebrowLabel("PRO")

            HStack {
                Text(title)
                    .font(.system(size: 23, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(TodayTheme.ink)
                Spacer()
                Text("Pro")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .foregroundStyle(TodayTheme.accent)
                    .background(TodayTheme.accentSoft)
                    .clipShape(Capsule())
            }

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(TodayTheme.inkMuted)

            Button(action: action) {
                Text(buttonTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(TodayTheme.teal)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }
}

struct HistoryBadgeRow: View {
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
            .foregroundStyle(TodayTheme.inkSoft)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(TodayTheme.elevatedCard.opacity(0.8))
            .clipShape(Capsule())
    }
}
