import SwiftData
import SwiftUI
import UIKit

struct DashboardView: View {
    @ObservedObject var todayViewModel: TodayViewModel
    let onOpenTimeline: () -> Void

    private var dashboardVM: DashboardViewModel {
        DashboardViewModel(timeline: todayViewModel.timeline)
    }

    private let cardColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    cardGridSection
                    insightSection
                    timelinePreviewSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(TodayTheme.background)
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await todayViewModel.loadIfNeeded()
            }
            .refreshable {
                await todayViewModel.load(forceReload: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task {
                    await todayViewModel.load(forceReload: true)
                }
            }
        }
    }

    // MARK: - Header

    private var dayOfWeekText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: dashboardVM.timeline?.date ?? Date())
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(dashboardVM.dateText)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(TodayTheme.inkMuted)
                            .tracking(1.4)

                        Text(dayOfWeekText)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(TodayTheme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(TodayTheme.accentSoft)
                            .clipShape(Capsule())
                    }

                    Text("仪表盘")
                        .font(.system(size: 33, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(TodayTheme.ink)
                }

                Spacer()

                Button {
                    Task {
                        await todayViewModel.load(forceReload: true)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(TodayTheme.inkSoft)
                        .frame(width: 42, height: 42)
                        .background(TodayTheme.card)
                        .overlay(
                            Circle()
                                .stroke(TodayTheme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            if todayViewModel.isLoading && todayViewModel.timeline == nil {
                Text("正在整理今天的数据...")
                    .font(.system(size: 14))
                    .foregroundStyle(TodayTheme.inkMuted)
            }

            if let errorMessage = todayViewModel.errorMessage, todayViewModel.timeline == nil {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(TodayTheme.rose)

                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(TodayTheme.inkMuted)
                        .lineLimit(2)
                }
            }
        }
    }

    // MARK: - Card Grid

    private var cardGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("今日概览")

            if todayViewModel.isLoading && todayViewModel.timeline == nil {
                cardGridPlaceholder
            } else {
                LazyVGrid(columns: cardColumns, spacing: 12) {
                    ForEach(dashboardVM.cards) { card in
                        DashboardCardView(card: card)
                    }
                }
            }
        }
    }

    private var cardGridPlaceholder: some View {
        LazyVGrid(columns: cardColumns, spacing: 12) {
            ForEach(0..<6, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(TodayTheme.elevatedCard)
                    .aspectRatio(1.0, contentMode: .fit)
                    .overlay(
                        ProgressView()
                    )
            }
        }
    }

    // MARK: - Insight

    @ViewBuilder
    private var insightSection: some View {
        let vm = dashboardVM
        ContentCard(background: TodayTheme.tealSoft.opacity(0.7)) {
            SectionHeader("今日洞察")

            HStack(spacing: 10) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TodayTheme.teal)
                    .frame(width: 32, height: 32)
                    .background(TodayTheme.teal.opacity(0.12))
                    .clipShape(Circle())

                Text("生活脉搏")
                    .font(.system(size: 23, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(TodayTheme.ink)
            }

            Text(vm.insightText)
                .font(.system(size: 14))
                .foregroundStyle(TodayTheme.inkMuted)
                .lineSpacing(4)
        }
    }

    // MARK: - Timeline Preview

    @ViewBuilder
    private var timelinePreviewSection: some View {
        let preview = dashboardVM.timelinePreview
        if !preview.isEmpty {
            ContentCard {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        SectionHeader("最近动态")

                        Text("时间线")
                            .font(.system(size: 23, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(TodayTheme.ink)
                    }

                    Spacer()

                    Button(action: onOpenTimeline) {
                        Text("查看全部")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(TodayTheme.accent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(TodayTheme.accentSoft)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                VStack(spacing: 0) {
                    ForEach(Array(preview.enumerated()), id: \.element.id) { index, event in
                        TimelinePreviewRow(event: event)

                        if index < preview.count - 1 {
                            Divider()
                                .padding(.leading, 36)
                        }
                    }
                }
            }
        } else if todayViewModel.timeline != nil {
            ContentCard {
                VStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.system(size: 28))
                        .foregroundStyle(TodayTheme.inkFaint)

                    Text("时间线还是空的")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(TodayTheme.inkSoft)

                    Text("戴上 Apple Watch 活动一会儿，或用快门记录生活碎片。")
                        .font(.system(size: 14))
                        .foregroundStyle(TodayTheme.inkMuted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
    }
}

// MARK: - Timeline Preview Row

private struct TimelinePreviewRow: View {
    let event: InferredEvent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32)
                .background(iconBackground)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(event.resolvedName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(TodayTheme.inkSoft)
                    .lineLimit(1)

                Text(timeText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(TodayTheme.inkMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(TodayTheme.elevatedCard)
                    .clipShape(Capsule())
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        let start = formatter.string(from: event.startDate)
        if event.duration < 60 {
            return start
        }
        let end = formatter.string(from: event.endDate)
        return "\(start) - \(end)"
    }

    private var iconName: String {
        switch event.kind {
        case .sleep:         return "moon.fill"
        case .workout:       return "figure.run"
        case .commute:       return "car.fill"
        case .activeWalk:    return "figure.walk"
        case .quietTime:     return "leaf.fill"
        case .userAnnotated: return "pencil"
        case .mood:          return "heart.fill"
        case .shutter:       return "camera.fill"
        case .screenTime:    return "iphone"
        case .spending:      return "yensign.circle.fill"
        }
    }

    private var iconColor: Color {
        switch event.kind {
        case .sleep:         return TodayTheme.sleepIndigo
        case .workout:       return TodayTheme.workoutOrange
        case .commute:       return TodayTheme.blue
        case .activeWalk:    return TodayTheme.walkGreen
        case .quietTime:     return TodayTheme.teal
        case .userAnnotated: return TodayTheme.accent
        case .mood:          return TodayTheme.rose
        case .shutter:       return TodayTheme.accent
        case .screenTime:    return TodayTheme.purple
        case .spending:      return TodayTheme.rose
        }
    }

    private var iconBackground: Color {
        switch event.kind {
        case .sleep:         return TodayTheme.blueSoft
        case .workout:       return TodayTheme.orangeSoft
        case .commute:       return TodayTheme.blueSoft
        case .activeWalk:    return TodayTheme.tealSoft
        case .quietTime:     return TodayTheme.tealSoft
        case .userAnnotated: return TodayTheme.accentSoft
        case .mood:          return TodayTheme.roseSoft
        case .shutter:       return TodayTheme.accentSoft
        case .screenTime:    return TodayTheme.purpleSoft
        case .spending:      return TodayTheme.roseSoft
        }
    }
}

#Preview {
    DashboardView(
        todayViewModel: TodayViewModel(
            provider: MockTimelineDataProvider(),
            recordStore: UserDefaultsMoodRecordStore(
                defaults: UserDefaults(suiteName: "DashboardPreviewStore") ?? .standard,
                key: "preview.manualRecords"
            ),
            modelContainer: previewModelContainer
        ),
        onOpenTimeline: {}
    )
}

@MainActor
private let previewModelContainer: ModelContainer = {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try! ModelContainer(for: MoodRecordEntity.self, DayTimelineEntity.self, configurations: configuration)
}()
