import SwiftUI
import UIKit

@MainActor
enum ScrollShareService {
    static func renderScrollAsImage(timeline: DayTimeline) -> UIImage {
        let content = ScrollShareSnapshotView(timeline: timeline, contentWidth: 920)
        let renderer = ImageRenderer(content: content)
        renderer.scale = UIScreen.main.scale

        if let image = renderer.uiImage {
            return image
        }

        return UIImage()
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
    let contentWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("由 ToDay 生成 · \(watermarkDate)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(TodayTheme.inkMuted.opacity(0.78))
                .frame(maxWidth: .infinity, alignment: .trailing)

            DayScrollView(
                timeline: timeline,
                onEventTap: { _ in },
                onBlankTap: { _ in },
                showsCurrentTimeNeedle: false
            )
            .frame(width: contentWidth, alignment: .topLeading)
        }
        .padding(24)
        .frame(width: contentWidth + 48, alignment: .topLeading)
        .background(TodayTheme.background)
    }

    private var watermarkDate: String {
        timeline.date.formatted(.dateTime.year().month().day().locale(Locale(identifier: "zh_CN")))
    }
}
