import SwiftUI

struct TodayScreen: View {
    @StateObject private var viewModel: TodayViewModel

    init(viewModel: TodayViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroCard

                    if viewModel.isLoading && viewModel.timeline == nil {
                        loadingCard
                    } else if let message = viewModel.errorMessage, viewModel.timeline == nil {
                        errorCard(message: message)
                    } else if let timeline = viewModel.timeline {
                        timelineSection(timeline)
                    }
                }
                .padding(.vertical, 20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("ToDay")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reload") {
                        Task {
                            await viewModel.load(forceReload: true)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    viewModel.showQuickRecord = true
                } label: {
                    Label("快速记录", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(Color(red: 0.35, green: 0.63, blue: 0.54))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .sheet(isPresented: $viewModel.showQuickRecord) {
                QuickRecordSheet { record in
                    viewModel.addMoodRecord(record)
                }
            }
            .task {
                await viewModel.loadIfNeeded()
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("A private timeline for the way today actually felt.")
                    .font(.title2.weight(.bold))

                Spacer()

                if let source = viewModel.timeline?.source {
                    Text(source.badgeTitle)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.72))
                        .clipShape(Capsule())
                }
            }

            Text(todayLabel)
                .font(.subheadline.weight(.medium))

            Text(viewModel.timeline?.summary ?? "Build the flow with mock data now. Connect a real device later for HealthKit validation.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let source = viewModel.timeline?.source {
                Text(source.helperText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let timeline = viewModel.timeline {
                HStack(spacing: 12) {
                    ForEach(timeline.stats) { stat in
                        StatPill(title: stat.title, value: stat.value)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    StatPill(title: "Mode", value: "Mock")
                    StatPill(title: "Focus", value: "Build")
                    StatPill(title: "Next", value: "HealthKit")
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.90, blue: 0.82), Color(red: 0.89, green: 0.83, blue: 0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func timelineSection(_ timeline: DayTimeline) -> some View {
        Text("Today Timeline")
            .font(.title3.weight(.semibold))
            .padding(.horizontal, 20)

        VStack(spacing: 12) {
            ForEach(timeline.entries) { entry in
                TimelineCard(entry: entry)
            }
        }
        .padding(.horizontal, 20)
    }

    private var loadingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProgressView()
            Text("Loading today's timeline...")
                .font(.headline)
            Text("This is where ToDay will eventually read either mock data or HealthKit data depending on your current setup.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 20)
    }

    private func errorCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timeline unavailable")
                .font(.title2.weight(.bold))

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Retry") {
                Task {
                    await viewModel.load(forceReload: true)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 20)
    }

    private var todayLabel: String {
        Date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}

private struct TimelineCard: View {
    let entry: TimelineEntry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(entry.title)
                        .font(.headline)
                    Spacer()
                    Text(entry.timeRange)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Text(entry.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var color: Color {
        switch entry.kind {
        case .sleep:
            return Color(red: 0.43, green: 0.54, blue: 0.80)
        case .move:
            return Color(red: 0.84, green: 0.49, blue: 0.43)
        case .focus:
            return Color(red: 0.35, green: 0.63, blue: 0.54)
        case .pause:
            return Color(red: 0.74, green: 0.66, blue: 0.57)
        case .mood:
            return Color(red: 0.85, green: 0.65, blue: 0.40)
        }
    }
}

private struct StatPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    TodayScreen(viewModel: TodayViewModel(provider: MockTimelineDataProvider()))
}
