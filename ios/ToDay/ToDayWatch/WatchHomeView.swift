import SwiftUI

struct WatchHomeView: View {
    @StateObject private var viewModel = WatchViewModel()
    @State private var isShowingAnnotation = false
    @State private var isShowingMood = false

    var body: some View {
        VStack(spacing: 12) {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                Text(Self.timeFormatter.string(from: context.date))
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(WatchTheme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            currentEventCard

            HStack(spacing: 10) {
                actionButton(title: "标注", systemImage: "pencil") {
                    isShowingAnnotation = true
                }
                .disabled(!viewModel.canAnnotate)
                .opacity(viewModel.canAnnotate ? 1 : 0.45)

                actionButton(title: "心情", systemImage: "face.smiling") {
                    isShowingMood = true
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(WatchTheme.background.ignoresSafeArea())
        .sheet(isPresented: $isShowingAnnotation) {
            QuickAnnotationView { title in
                viewModel.annotateCurrentEvent(title: title)
            }
        }
        .sheet(isPresented: $isShowingMood) {
            pendingSheet(title: "快捷心情", description: "下一步会把极简心情记录放在这里。")
        }
    }

    private var currentEventCard: some View {
        Group {
            if let currentEvent = viewModel.currentEvent {
                eventCard(for: currentEvent)
            } else {
                waitingCard
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 132)
    }

    private func eventCard(for event: CurrentEventSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(event.eventName)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(WatchTheme.text)
                        .lineLimit(2)

                    Text(WatchTheme.badgeText(for: event.eventKind))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(WatchTheme.textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(WatchTheme.badgeFill(for: event.eventKind))
                        .clipShape(Capsule())
                }

                Spacer(minLength: 8)

                Image(systemName: event.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(WatchTheme.text.opacity(0.92))
            }

            TimelineView(.periodic(from: event.startDate, by: 60)) { context in
                Text(durationText(since: event.startDate, now: context.date))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(WatchTheme.text)
            }

            Text("\(Self.timeFormatter.string(from: event.startDate)) 开始")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(WatchTheme.textMuted)

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(WatchTheme.eventCardBackground(for: event.eventKind))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(WatchTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var waitingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("等待数据同步")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(WatchTheme.text)

            Text("抬手后会在这里看到当前正在做的事。")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(WatchTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(WatchTheme.eventCardBackground(for: "quietTime"))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(WatchTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func actionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .bold))

                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .foregroundStyle(WatchTheme.text)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(WatchTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(WatchTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func pendingSheet(title: String, description: String) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(WatchTheme.text)

            Text(description)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(WatchTheme.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WatchTheme.background.ignoresSafeArea())
    }

    private func durationText(since startDate: Date, now: Date) -> String {
        let totalMinutes = max(0, Int(now.timeIntervalSince(startDate)) / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            if minutes > 0 {
                return "已持续 \(hours) 小时 \(minutes) 分钟"
            }
            return "已持续 \(hours) 小时"
        }

        if minutes > 0 {
            return "已持续 \(minutes) 分钟"
        }

        return "刚刚开始"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

#Preview {
    WatchHomeView()
}
