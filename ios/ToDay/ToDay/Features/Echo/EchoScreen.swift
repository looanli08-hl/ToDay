import SwiftUI

struct EchoScreen: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "bell.badge")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("回响")
                    .font(.title2)
                Text("你的灵光一现，会在对的时刻回来找你")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Echo")
        }
    }
}
