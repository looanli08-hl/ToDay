import SwiftUI

struct EchoScreen: View {
    @ObservedObject var viewModel: EchoViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.todayEchoes.isEmpty && viewModel.careNudges.isEmpty && viewModel.historyEchoes.isEmpty {
                    emptyState
                } else {
                    List {
                        // Today's echoes section
                        if !viewModel.todayEchoes.isEmpty {
                            Section {
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
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                    .listRowSeparator(.hidden)
                                }
                            } header: {
                                HStack {
                                    Text("今日回响")
                                    Spacer()
                                    Text("\(viewModel.todayEchoes.count)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        // Care nudges section
                        if !viewModel.careNudges.isEmpty {
                            Section {
                                ForEach(viewModel.careNudges) { nudge in
                                    CareNudgeCardView(nudge: nudge)
                                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                        .listRowSeparator(.hidden)
                                }
                            } header: {
                                Text("关怀")
                            }
                        }

                        // History section
                        if !viewModel.historyEchoes.isEmpty {
                            Section {
                                ForEach(viewModel.historyEchoes) { echoItem in
                                    historyRow(echoItem)
                                }
                            } header: {
                                Text("历史回响")
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(AppColor.background)
                }
            }
            .background(AppColor.background)
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
            Image(systemName: "bell.badge")
                .font(.system(size: 44))
                .foregroundStyle(AppColor.labelQuaternary)

            Text("回响")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppColor.label)

            Text("你的灵光一现，会在对的时刻回来找你")
                .font(.system(size: 15))
                .foregroundStyle(AppColor.labelSecondary)
                .multilineTextAlignment(.center)

            Text("使用快门记录生活碎片后，它们会在未来合适的日子重新出现")
                .font(.system(size: 13))
                .foregroundStyle(AppColor.labelTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.background)
    }

    private func historyRow(_ echoItem: EchoItem) -> some View {
        let record = viewModel.shutterRecord(for: echoItem)
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(record?.displayText ?? "记录已删除")
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(echoItem.offsetLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\u{00B7}")
                        .foregroundStyle(.tertiary)

                    Text(Self.shortDateFormatter.string(from: echoItem.scheduledDate))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            statusBadge(echoItem.status)
        }
    }

    private func statusBadge(_ status: EchoStatus) -> some View {
        let (text, color): (String, Color) = {
            switch status {
            case .pending:   return ("待查看", TodayTheme.teal)
            case .viewed:    return ("已查看", Color.secondary)
            case .dismissed: return ("已跳过", Color(UIColor.tertiaryLabel))
            case .snoozed:   return ("已推迟", Color.orange)
            }
        }()

        return Text(text)
            .font(.caption2)
            .foregroundStyle(color)
    }

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M/d"
        return f
    }()
}
