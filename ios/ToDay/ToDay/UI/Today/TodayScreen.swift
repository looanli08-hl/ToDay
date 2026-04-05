import SwiftUI

struct TodayScreen: View {
    @ObservedObject var viewModel: TodayViewModel

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ZStack {
                // Ambient time-of-day background — the atmosphere layer
                AppColor.background
                    .ignoresSafeArea()

                TimeGradient.ambientGradient(for: viewModel.currentDate)
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Date Strip
                        dateStrip
                            .padding(.top, AppSpacing.md)

                        // Date Header — atmospheric, large serif
                        dateHeader
                            .padding(.top, AppSpacing.lg)
                            .padding(.horizontal, AppSpacing.lg)

                        // AI insight — whispered, not a card
                        if let summary = viewModel.aiSummary {
                            echoWhisper(summary)
                                .padding(.top, AppSpacing.md)
                                .padding(.horizontal, AppSpacing.lg)
                        }

                        if let insight = viewModel.patternInsight {
                            patternWhisper(insight)
                                .padding(.top, AppSpacing.sm)
                                .padding(.horizontal, AppSpacing.lg)
                        }

                        // Loading / Error / Empty / Timeline
                        Group {
                            if viewModel.isLoading && !viewModel.entries.isEmpty {
                                timelineCanvas
                            } else if viewModel.isLoading {
                                loadingState
                            } else if let error = viewModel.errorMessage {
                                errorState(error)
                            } else if viewModel.entries.isEmpty {
                                emptyState
                            } else {
                                timelineCanvas
                            }
                        }
                        .padding(.top, AppSpacing.lg)

                        Spacer(minLength: viewModel.isToday ? 100 : AppSpacing.xxl)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showCalendar = true
                    } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppColor.accent)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if viewModel.isToday {
                    bottomActionBar
                }
            }
            .sheet(item: $viewModel.selectedEvent) { event in
                eventDetailSheet(event)
            }
            .sheet(isPresented: $viewModel.showQuickRecord) {
                QuickRecordSheet(
                    isPresented: $viewModel.showQuickRecord,
                    onSave: { note in
                        viewModel.saveMemo(note)
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $viewModel.showCalendar) {
                calendarSheet
            }
            .task {
                await viewModel.load()
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
    }

    // MARK: - Date Strip

    private var dateStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.xs) {
                    ForEach(viewModel.recentDateRange, id: \.self) { date in
                        dateCell(date)
                            .id(date)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
            }
            .onAppear {
                proxy.scrollTo(
                    calendar.startOfDay(for: viewModel.selectedDate),
                    anchor: .center
                )
            }
            .onChange(of: viewModel.selectedDate) { _, newDate in
                withAnimation(.spring(duration: 0.3)) {
                    proxy.scrollTo(
                        calendar.startOfDay(for: newDate),
                        anchor: .center
                    )
                }
            }
        }
    }

    private func dateCell(_ date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: viewModel.selectedDate)
        let isTodayDate = calendar.isDateInToday(date)

        return VStack(spacing: AppSpacing.xxs) {
            if isTodayDate {
                Text("today")
                    .font(AppFont.micro())
                    .foregroundStyle(isSelected ? .white : AppColor.accent)
            } else {
                Text("\(calendar.component(.day, from: date))")
                    .font(AppFont.small())
                    .foregroundStyle(isSelected ? .white : AppColor.label)
            }
        }
        .frame(width: 40, height: 40)
        .background(
            isSelected
                ? AppColor.accent
                : AppColor.surface.opacity(0.6)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture {
            viewModel.selectDate(date)
        }
    }

    // MARK: - Date Header

    private var dateHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(headerTitle)
                .font(.system(size: 36, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(AppColor.label)

            Text(formattedDate)
                .font(AppFont.micro())
                .foregroundStyle(AppColor.labelQuaternary)
                .tracking(2.0)
        }
    }

    private var headerTitle: String {
        if viewModel.isToday {
            return "today"
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "MM\u{6708}dd\u{65E5}"
            return formatter.string(from: viewModel.currentDate)
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy \u{00B7} MM \u{00B7} dd   EEEE"
        return formatter.string(from: viewModel.currentDate)
    }

    // MARK: - Echo Whisper (AI Insight)

    private func echoWhisper(_ summary: String) -> some View {
        // No card, no header, no "Echo" label — just the words, whispered
        Text(summary)
            .whisperStyle()
            .lineSpacing(6)
            .padding(.trailing, AppSpacing.xl)
    }

    // MARK: - Pattern Whisper

    private func patternWhisper(_ insight: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.xs) {
            Rectangle()
                .fill(AppColor.echo.opacity(0.3))
                .frame(width: 2)

            Text(insight)
                .font(AppFont.memo())
                .foregroundStyle(AppColor.echo.opacity(0.7))
                .lineSpacing(4)
        }
        .padding(.trailing, AppSpacing.xl)
    }

    // MARK: - Timeline Canvas

    private var timelineCanvas: some View {
        // No section header, no subtitle — the gradient scroll IS the timeline
        DayScrollView(
            entries: viewModel.entries,
            date: viewModel.currentDate,
            isToday: viewModel.isToday,
            onEventTap: { event in
                viewModel.selectedEvent = event
            }
        )
        .padding(.horizontal, AppSpacing.sm)
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: AppSpacing.md) {
            ProgressView()
                .tint(AppColor.accent)
                .scaleEffect(0.8)

            Text("unfolding...")
                .font(AppFont.whisper())
                .foregroundStyle(AppColor.labelTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - Error State

    private func errorState(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("can't unfold right now")
                .font(AppFont.whisper())
                .foregroundStyle(AppColor.label)

            Text(message)
                .font(AppFont.micro())
                .foregroundStyle(AppColor.labelTertiary)

            HStack(spacing: AppSpacing.md) {
                Button("retry") {
                    Task { await viewModel.refresh() }
                }
                .font(AppFont.bodyRegular())
                .foregroundStyle(AppColor.accent)

                Button("settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(AppFont.bodyRegular())
                .foregroundStyle(AppColor.labelTertiary)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
                .frame(height: AppSpacing.xxl)

            Text(viewModel.isToday ? "the day is unfolding..." : "nothing recorded")
                .font(AppFont.whisper())
                .foregroundStyle(AppColor.labelTertiary)

            if viewModel.isToday {
                Text("carry your phone with you and the timeline fills itself.\nor tap below to leave a note.")
                    .font(AppFont.micro())
                    .foregroundStyle(AppColor.labelQuaternary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, AppSpacing.xl)

                Button("refresh") {
                    Task { await viewModel.refresh() }
                }
                .font(AppFont.bodyRegular())
                .foregroundStyle(AppColor.accent)
                .padding(.top, AppSpacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        HStack(spacing: AppSpacing.sm) {
            if viewModel.hasActiveSession {
                Button {
                    viewModel.openQuickRecordComposer()
                } label: {
                    Text("add a note")
                        .font(AppFont.bodyRegular())
                        .foregroundStyle(AppColor.label)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous))
                }

                Button {
                    viewModel.finishActiveRecord()
                } label: {
                    Text("end session")
                        .font(AppFont.body())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(AppColor.accent)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous))
                }
            } else {
                Button {
                    viewModel.openQuickRecordComposer()
                } label: {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 14, weight: .medium))
                        Text("note this moment")
                    }
                    .font(AppFont.bodyRegular())
                    .foregroundStyle(AppColor.accent)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous))
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(.ultraThinMaterial)
    }

    // MARK: - Calendar Sheet

    private var calendarSheet: some View {
        NavigationStack {
            DatePicker(
                "select date",
                selection: $viewModel.selectedDate,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(AppColor.accent)
            .padding()
            .background(AppColor.background)
            .navigationTitle("select date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("today") {
                        viewModel.returnToToday()
                    }
                    .font(AppFont.bodyRegular())
                    .foregroundStyle(AppColor.accent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("done") {
                        viewModel.showCalendar = false
                        Task { await viewModel.loadTimeline(for: viewModel.selectedDate) }
                    }
                    .font(AppFont.body())
                    .foregroundStyle(AppColor.accent)
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Event Detail Sheet

    @ViewBuilder
    private func eventDetailSheet(_ event: InferredEvent) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    // Header — atmospheric, not a card
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        // Accent bar
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(AppColor.color(for: event.kind))
                            .frame(width: 24, height: 3)

                        Text(event.resolvedName)
                            .font(AppFont.heading())
                            .foregroundStyle(AppColor.label)

                        Text(event.scrollDurationText)
                            .font(AppFont.small())
                            .foregroundStyle(AppColor.labelTertiary)
                    }
                    .padding(.bottom, AppSpacing.xs)

                    // Subtitle / detail
                    if let subtitle = event.subtitle {
                        Text(subtitle)
                            .font(AppFont.bodyRegular())
                            .foregroundStyle(AppColor.labelSecondary)
                            .lineSpacing(4)
                    }

                    // Time range — minimal
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text("time")
                            .font(AppFont.micro())
                            .foregroundStyle(AppColor.labelQuaternary)
                            .tracking(1.0)

                        Text(timeRangeText(event))
                            .font(AppFont.small())
                            .foregroundStyle(AppColor.label)
                    }
                    .padding(.top, AppSpacing.sm)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.lg)
            }
            .background(AppColor.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.selectedEvent = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppColor.labelTertiary)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func timeRangeText(_ event: InferredEvent) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: event.startDate)) \u{2013} \(formatter.string(from: event.endDate))"
    }
}
