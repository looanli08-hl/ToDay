import SwiftUI

struct RecordPanel: View {
    @ObservedObject var viewModel: TodayViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var mode: RecordPanelMode = .menu

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .menu:
                    menuView
                case .mood:
                    moodView
                case .timePeriod:
                    timePeriodView
                }
            }
            .background(TodayTheme.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        if mode == .menu {
                            dismiss()
                        } else {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                mode = .menu
                            }
                        }
                    } label: {
                        Image(systemName: mode == .menu ? "xmark" : "chevron.left")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(TodayTheme.inkSoft)
                            .frame(width: 32, height: 32)
                            .background(TodayTheme.card)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Menu

    private var menuView: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("记录")
                    .font(.system(size: 28, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(TodayTheme.ink)

                Text("记录当下的心情，或者补上一段时间做了什么。")
                    .font(.system(size: 14))
                    .foregroundStyle(TodayTheme.inkMuted)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            VStack(spacing: 10) {
                recordOption(
                    icon: "heart.fill",
                    title: "记录心情",
                    subtitle: "选一个最接近当下的情绪",
                    tint: TodayTheme.rose
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mode = .mood
                    }
                }

                recordOption(
                    icon: "clock.badge.fill",
                    title: "添加时段",
                    subtitle: "手动补一段时间里做了什么",
                    tint: TodayTheme.teal
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mode = .timePeriod
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    private func recordOption(
        icon: String,
        title: String,
        subtitle: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .background(tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(TodayTheme.ink)

                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(TodayTheme.inkMuted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TodayTheme.inkFaint)
            }
            .padding(14)
            .background(TodayTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(TodayTheme.border, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Mood

    private var moodView: some View {
        QuickRecordSheet(mode: .flexible) { record in
            viewModel.startMoodRecord(record)
            dismiss()
        }
    }

    // MARK: - Time Period

    private var timePeriodView: some View {
        ManualTimeEntrySheet { title, start, end in
            let event = InferredEvent(
                kind: .userAnnotated,
                startDate: start,
                endDate: end,
                confidence: .high,
                displayName: title,
                userAnnotation: title
            )
            viewModel.annotateEvent(event, title: title)
            dismiss()
        }
    }
}

private enum RecordPanelMode {
    case menu
    case mood
    case timePeriod
}
