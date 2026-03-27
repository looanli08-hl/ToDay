import SwiftUI
import UIKit

@MainActor
enum ScrollShareService {
    static func renderScrollAsImage(timeline: DayTimeline) -> UIImage {
        let content = ScrollShareSnapshotView(timeline: timeline)
        let renderer = ImageRenderer(content: content)
        renderer.scale = UIScreen.main.scale

        return renderer.uiImage ?? UIImage()
    }
}

struct ScrollShareSheet: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct ScrollShareSnapshotView: View {
    let timeline: DayTimeline

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("由 ToDay 生成 · \(watermarkDate)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(UIColor.tertiaryLabel).opacity(0.78))
                .frame(maxWidth: .infinity, alignment: .trailing)

            DayVerticalTimelineContent(
                timeline: timeline,
                onEventTap: { _ in },
                onBlankTap: { _ in },
                showsCurrentTimeNeedle: false
            )
        }
        .padding(24)
        .frame(width: 390)
        .background(Color(UIColor.systemGroupedBackground))
    }

    private var watermarkDate: String {
        timeline.date.formatted(.dateTime.year().month().day().locale(Locale(identifier: "zh_CN")))
    }
}
