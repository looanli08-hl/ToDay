import SwiftUI

struct EchoScreen: View {
    @ObservedObject var viewModel: EchoViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if viewModel.isLoading {
                        ProgressView()
                            .padding(.top, 40)
                    } else if viewModel.todayEchoes.isEmpty && viewModel.careNudges.isEmpty {
                        emptyState
                    } else {
                        // Today's echoes section
                        if !viewModel.todayEchoes.isEmpty {
                            sectionHeader("今日回响", count: viewModel.todayEchoes.count)

                            ForEach(viewModel.todayEchoes) { echoItem in
                                EchoCardView(
                                    echoItem: echoItem,
                                    shutterRecord: viewModel.shutterRecord(for: echoItem),
                                    onTap: {
                                        viewModel.markAsViewed(echoItem)
                                        viewModel.selectedEchoItem = echoItem
                                    },
                                    onDismiss: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            viewModel.dismiss(echoItem)
                                        }
                                    },
                                    onSnooze: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            viewModel.snooze(echoItem)
                                        }
                                    }
                                )
                            }
                        }

                        // Care nudges section
                        if !viewModel.careNudges.isEmpty {
                            sectionHeader("关怀", count: nil)

                            ForEach(viewModel.careNudges) { nudge in
                                CareNudgeCardView(nudge: nudge)
                            }
                        }

                        // History section
                        if !viewModel.historyEchoes.isEmpty {
                            sectionHeader("历史回响", count: nil)

                            ForEach(viewModel.historyEchoes) { echoItem in
                                historyRow(echoItem)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(TodayTheme.background)
            .navigationTitle("Echo")
            .sheet(item: $viewModel.selectedEchoItem) { echoItem in
                EchoDetailSheet(
                    echoItem: echoItem,
                    shutterRecord: viewModel.shutterRecord(for: echoItem),
                    onDismiss: {
                        viewModel.selectedEchoItem = nil
                    }
                )
            }
            .onAppear {
                viewModel.load()
            }
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 60)

            Image(systemName: "bell.badge")
                .font(.system(size: 48))
                .foregroundStyle(TodayTheme.inkFaint)

            Text("回响")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(TodayTheme.ink)

            Text("你的灵光一现，会在对的时刻回来找你")
                .font(.system(size: 15))
                .foregroundStyle(TodayTheme.inkMuted)
                .multilineTextAlignment(.center)

            Text("使用快门记录生活碎片后，它们会在未来合适的日子重新出现")
                .font(.system(size: 13))
                .foregroundStyle(TodayTheme.inkFaint)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private func sectionHeader(_ title: String, count: Int?) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(TodayTheme.inkMuted)
                .tracking(1.2)

            if let count {
                Text("\(count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TodayTheme.teal)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(TodayTheme.tealSoft)
                    .clipShape(Capsule())
            }

            Spacer()
        }
        .padding(.top, 8)
    }

    private func historyRow(_ echoItem: EchoItem) -> some View {
        let record = viewModel.shutterRecord(for: echoItem)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(record?.displayText ?? "记录已删除")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(TodayTheme.ink)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(echoItem.offsetLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(TodayTheme.inkMuted)

                    Text("\u{00B7}")
                        .foregroundStyle(TodayTheme.inkFaint)

                    Text(Self.shortDateFormatter.string(from: echoItem.scheduledDate))
                        .font(.system(size: 12))
                        .foregroundStyle(TodayTheme.inkFaint)
                }
            }

            Spacer()

            statusBadge(echoItem.status)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(TodayTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(TodayTheme.border, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func statusBadge(_ status: EchoStatus) -> some View {
        let (text, color): (String, Color) = {
            switch status {
            case .pending:   return ("待查看", TodayTheme.teal)
            case .viewed:    return ("已查看", TodayTheme.inkMuted)
            case .dismissed: return ("已跳过", TodayTheme.inkFaint)
            case .snoozed:   return ("已推迟", TodayTheme.accent)
            }
        }()

        return Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(color)
    }

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M/d"
        return f
    }()
}
